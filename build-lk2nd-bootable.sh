#!/usr/bin/env bash
# Build a lk2nd/fastboot-bootable Android boot image for mainline Linux.

set -euo pipefail

die() {
	printf 'error: %s\n' "$*" >&2
	exit 1
}

have() {
	command -v "$1" >/dev/null 2>&1
}

need() {
	have "$1" || die "missing required tool: $1"
}

usage() {
	cat <<'EOF'
Usage: ./build-lk2nd-bootable.sh [KEY=value ...]

Builds ./linux and creates an Android boot.img intended for:

  fastboot boot out/expressltexx/expressltexx-boot.img

The kernel payload is appended zImage+DTB so lk2nd's Android boot path can pass
the device tree to the ARM kernel without extlinux/userdata packaging.

Environment overrides:

  LINUX_DIR          Kernel tree path (default: ./linux)
  OUT_DIR            Output directory (default: ./out/expressltexx)
  BUILD_DIR          Kernel build directory (default: $OUT_DIR/linux-build)
  IMAGE              Output boot image path (default: $OUT_DIR/expressltexx-boot.img)
  DTB                DTB basename (default: qcom-msm8930-samsung-expressltexx.dtb)
  INITRAMFS          Initramfs path, "dev"/"minimal", "minitrd", or "none" (default: dev)
  DEV_INITRD_SCRIPT  Dev initrd builder (default: ./build-dev-initrd.sh)
  MINITRD_SCRIPT     mkosi/APK minitrd builder (default: ./build-minitrd.sh)
  BUSYBOX            Static ARM BusyBox binary for dev initrd
                     (default: $OUT_DIR/cache/busybox-armv7l)
  BUSYBOX_URL        Download URL used when BUSYBOX is missing
  BUSYBOX_SHA256     Expected BusyBox SHA256; set empty to skip verification
  CMDLINE            Android boot.img/kernel cmdline
  CROSS_COMPILE      ARM cross prefix, e.g. arm-none-eabi-
  LLVM               LLVM suffix/prefix for kernel builds, if not using CROSS_COMPILE
  HOSTCC             Host C compiler for dev initrd helper (default: cc)
  JOBS               make -j value (default: nproc)
  SKIP_BUILD=1       Reuse existing kernel artifacts in BUILD_DIR

Boot image layout defaults mostly match the downstream expressltexx Android config.
The ramdisk is placed at lk2nd's extlinux-tested address instead of the
downstream Android address because the latter reached Linux without initramfs.

  base=0x80200000 kernel_offset=0x00008000 ramdisk_offset=0x02200000
  tags_offset=0x00000100 pagesize=2048 header_version=0
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
	usage
	exit 0
fi

for arg in "$@"; do
	if [[ "$arg" =~ ^[A-Za-z_][A-Za-z0-9_]*= ]]; then
		declare -gx "$arg"
	else
		die "unknown argument: $arg"
	fi
done

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
LINUX_DIR=${LINUX_DIR:-"$ROOT_DIR/linux"}
OUT_DIR=${OUT_DIR:-"$ROOT_DIR/out/expressltexx"}
BUILD_DIR=${BUILD_DIR:-"$OUT_DIR/linux-build"}
IMAGE=${IMAGE:-"$OUT_DIR/expressltexx-boot.img"}
DTB=${DTB:-qcom-msm8930-samsung-expressltexx.dtb}
INITRAMFS=${INITRAMFS:-dev}
JOBS=${JOBS:-$(nproc)}
SKIP_BUILD=${SKIP_BUILD:-0}
HOSTCC=${HOSTCC:-cc}
CACHE_DIR=${CACHE_DIR:-"$OUT_DIR/cache"}
BUSYBOX=${BUSYBOX:-"$CACHE_DIR/busybox-armv7l"}
BUSYBOX_URL=${BUSYBOX_URL:-https://busybox.net/downloads/binaries/1.31.0-defconfig-multiarch-musl/busybox-armv7l}
BUSYBOX_SHA256=${BUSYBOX_SHA256:-cd04052b8b6885f75f50b2a280bfcbf849d8710c8e61d369c533acf307eda064}
DEV_INITRD_SCRIPT=${DEV_INITRD_SCRIPT:-"$ROOT_DIR/build-dev-initrd.sh"}
MINITRD_SCRIPT=${MINITRD_SCRIPT:-"$ROOT_DIR/build-minitrd.sh"}

KERNEL_OFFSET=${KERNEL_OFFSET:-0x00008000}
RAMDISK_OFFSET=${RAMDISK_OFFSET:-0x02200000}
TAGS_OFFSET=${TAGS_OFFSET:-0x00000100}
BOOT_BASE=${BOOT_BASE:-0x80200000}
BOOT_PAGESIZE=${BOOT_PAGESIZE:-2048}

DEFAULT_CMDLINE='earlycon=msm_serial_dm,0x16440000 console=tty0 console=ttyMSM0,115200n8 ignore_loglevel loglevel=8 clk_ignore_unused pd_ignore_unused rdinit=/init panic=0'
CMDLINE=${CMDLINE:-$DEFAULT_CMDLINE}

[[ -d "$LINUX_DIR" ]] || die "kernel tree not found: $LINUX_DIR"
[[ -f "$LINUX_DIR/Makefile" ]] || die "kernel Makefile not found in: $LINUX_DIR"

need make
need mkbootimg
need stat

mkdir -p "$OUT_DIR" "$BUILD_DIR"

case "$INITRAMFS" in
	dev|minimal)
		INITRAMFS="$OUT_DIR/dev-initramfs.cpio.gz"
		[[ -x "$DEV_INITRD_SCRIPT" ]] || die "dev initrd builder not executable: $DEV_INITRD_SCRIPT"
		"$DEV_INITRD_SCRIPT" \
			OUTPUT="$INITRAMFS" \
			OUT_DIR="$OUT_DIR" \
			LINUX_DIR="$LINUX_DIR" \
			HOSTCC="$HOSTCC" \
			BUSYBOX="$BUSYBOX" \
			BUSYBOX_URL="$BUSYBOX_URL" \
			BUSYBOX_SHA256="$BUSYBOX_SHA256"
		;;
	minitrd)
		INITRAMFS="$OUT_DIR/minitrd.cpio.gz"
		[[ -x "$MINITRD_SCRIPT" ]] || die "minitrd builder not executable: $MINITRD_SCRIPT"
		"$MINITRD_SCRIPT" \
			OUTPUT="$INITRAMFS" \
			OUT_DIR="$OUT_DIR"
		;;
	auto)
		die 'INITRAMFS=auto was removed; use INITRAMFS=dev or a path'
		;;
	none)
		INITRAMFS=
		;;
esac

if [[ -n "$INITRAMFS" && ! -f "$INITRAMFS" ]]; then
	die "initramfs not found: $INITRAMFS"
fi

MAKE_ARGS=(ARCH=arm)
TOOLCHAIN_DESC='none'

if [[ "$SKIP_BUILD" != 1 ]]; then
	if [[ -n "${CROSS_COMPILE:-}" ]]; then
		need "${CROSS_COMPILE}gcc"
		MAKE_ARGS+=(CROSS_COMPILE="$CROSS_COMPILE")
		TOOLCHAIN_DESC="GCC ${CROSS_COMPILE}"
	else
		for prefix in arm-linux-gnueabi- arm-linux-gnueabihf- arm-linux-gnu- arm-none-eabi-; do
			if have "${prefix}gcc"; then
				CROSS_COMPILE=$prefix
				MAKE_ARGS+=(CROSS_COMPILE="$CROSS_COMPILE")
				TOOLCHAIN_DESC="GCC ${CROSS_COMPILE}"
				break
			fi
		done
	fi

	if [[ "$TOOLCHAIN_DESC" == none ]]; then
		if [[ -n "${LLVM:-}" ]]; then
			MAKE_ARGS+=(LLVM="$LLVM" LLVM_IAS="${LLVM_IAS:-1}")
			TOOLCHAIN_DESC="LLVM ${LLVM}"
		elif have clang && have ld.lld; then
			MAKE_ARGS+=(LLVM=1 LLVM_IAS="${LLVM_IAS:-1}")
			TOOLCHAIN_DESC='LLVM'
		else
			die 'no ARM GCC cross compiler found and LLVM toolchain is incomplete; set CROSS_COMPILE= or LLVM='
		fi
	fi
fi

if [[ "$SKIP_BUILD" != 1 ]]; then
	printf '==> Using %s\n' "$TOOLCHAIN_DESC"
	printf '==> Configuring qcom_defconfig\n'
	make -C "$LINUX_DIR" O="$BUILD_DIR" "${MAKE_ARGS[@]}" qcom_defconfig

	printf '==> Building zImage and dtbs\n'
	make -C "$LINUX_DIR" O="$BUILD_DIR" "${MAKE_ARGS[@]}" -j"$JOBS" zImage dtbs
else
	printf '==> SKIP_BUILD=1: reusing artifacts from %s\n' "$BUILD_DIR"
fi

ZIMAGE="$BUILD_DIR/arch/arm/boot/zImage"
DTB_PATH="$BUILD_DIR/arch/arm/boot/dts/qcom/$DTB"
ZIMAGE_DTB="$OUT_DIR/zImage-dtb"
EMPTY_RAMDISK="$OUT_DIR/empty-ramdisk"

[[ -f "$ZIMAGE" ]] || die "missing zImage: $ZIMAGE"
[[ -f "$DTB_PATH" ]] || die "missing DTB: $DTB_PATH"

cp "$ZIMAGE" "$ZIMAGE_DTB"
cat "$DTB_PATH" >> "$ZIMAGE_DTB"

if [[ -z "$INITRAMFS" ]]; then
	printf '\0' > "$EMPTY_RAMDISK"
	INITRAMFS="$EMPTY_RAMDISK"
fi

printf '==> Creating Android boot image\n'
mkbootimg \
	--kernel "$ZIMAGE_DTB" \
	--ramdisk "$INITRAMFS" \
	--base "$BOOT_BASE" \
	--kernel_offset "$KERNEL_OFFSET" \
	--ramdisk_offset "$RAMDISK_OFFSET" \
	--tags_offset "$TAGS_OFFSET" \
	--pagesize "$BOOT_PAGESIZE" \
	--header_version 0 \
	--cmdline "$CMDLINE" \
	--output "$IMAGE"

image_size=$(stat -c%s "$IMAGE")
kernel_size=$(stat -c%s "$ZIMAGE_DTB")
ramdisk_size=$(stat -c%s "$INITRAMFS")

printf '\n==> Wrote %s\n' "$IMAGE"
printf '    kernel:    %s (%s bytes)\n' "$ZIMAGE_DTB" "$kernel_size"
printf '    ramdisk:   %s (%s bytes)\n' "$INITRAMFS" "$ramdisk_size"
printf '    image:     %s bytes\n' "$image_size"
printf '    DTB:       %s\n' "$DTB"
printf '    cmdline:   %s\n' "$CMDLINE"
printf '    layout:    base=%s kernel_offset=%s ramdisk_offset=%s tags_offset=%s pagesize=%s\n' \
	"$BOOT_BASE" "$KERNEL_OFFSET" "$RAMDISK_OFFSET" "$TAGS_OFFSET" "$BOOT_PAGESIZE"
printf '\nBoot with:\n'
printf '  fastboot boot %q\n' "$IMAGE"
printf '\nIf this fails, fall back to ./build-lk2nd-userdata.sh and flash userdata.\n'
