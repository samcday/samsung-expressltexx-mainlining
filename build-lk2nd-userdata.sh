#!/usr/bin/env bash
# Build a mainline ARM kernel and package it as a lk2nd/extlinux userdata image.

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
Usage: ./build-lk2nd-userdata.sh [KEY=value ...]

Builds ./linux and creates an MBR userdata image suitable for:

  fastboot flash userdata out/expressltexx/expressltexx-userdata.sparse.img

Environment overrides:

  LINUX_DIR          Kernel tree path (default: ./linux)
  OUT_DIR            Output directory (default: ./out/expressltexx)
  BUILD_DIR          Kernel build directory (default: $OUT_DIR/linux-build)
  IMAGE              Output userdata image path (default: $OUT_DIR/expressltexx-userdata.img)
  DTB                DTB basename (default: qcom-msm8930-samsung-expressltexx.dtb)
  INITRAMFS          Optional initramfs path; use "dev"/"minimal" for ./build-dev-initrd.sh
                     or "none" to omit it
  DEV_INITRD_SCRIPT  Dev initrd builder (default: ./build-dev-initrd.sh)
  BUSYBOX            Static ARM BusyBox binary for dev initrd
                     (default: $OUT_DIR/cache/busybox-armv7l)
  BUSYBOX_URL        Download URL used when BUSYBOX is missing
  BUSYBOX_SHA256     Expected BusyBox SHA256; set empty to skip verification
  CMDLINE            Extlinux/boot.img cmdline template
  CROSS_COMPILE      ARM cross prefix, e.g. arm-none-eabi-
  LLVM               LLVM suffix/prefix for kernel builds, if not using CROSS_COMPILE
  HOSTCC             Host C compiler for dev initrd helper (default: cc)
  JOBS               make -j value (default: nproc)
  BOOT_SIZE_MIB      Boot filesystem partition size (default: 48)
  ROOT_SIZE_MIB      Root filesystem partition size (default: 16)
  INCLUDE_BOOTIMG=1  Also copy generated boot.img into the boot filesystem
  SPARSE=1           Also create an Android sparse image for faster fastboot flashing
  SKIP_BUILD=1       Reuse existing kernel artifacts in BUILD_DIR
  KEEP_WORK=1        Keep intermediate partition images and staging files

CMDLINE may contain @BOOT_UUID@ and @ROOT_UUID@ placeholders.

Notes:
  - This uses lk2nd's extlinux path with an MBR layout; it does not flash anything.
  - Prefer ./build-lk2nd-bootable.sh once USB gadget/fastboot boot is working.
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
IMAGE=${IMAGE:-"$OUT_DIR/expressltexx-userdata.img"}
DTB=${DTB:-qcom-msm8930-samsung-expressltexx.dtb}
INITRAMFS=${INITRAMFS:-}
JOBS=${JOBS:-$(nproc)}
BOOT_SIZE_MIB=${BOOT_SIZE_MIB:-48}
ROOT_SIZE_MIB=${ROOT_SIZE_MIB:-16}
INCLUDE_BOOTIMG=${INCLUDE_BOOTIMG:-0}
SPARSE=${SPARSE:-1}
SKIP_BUILD=${SKIP_BUILD:-0}
KEEP_WORK=${KEEP_WORK:-0}
HOSTCC=${HOSTCC:-cc}
CACHE_DIR=${CACHE_DIR:-"$OUT_DIR/cache"}
BUSYBOX=${BUSYBOX:-"$CACHE_DIR/busybox-armv7l"}
BUSYBOX_URL=${BUSYBOX_URL:-https://busybox.net/downloads/binaries/1.31.0-defconfig-multiarch-musl/busybox-armv7l}
BUSYBOX_SHA256=${BUSYBOX_SHA256:-cd04052b8b6885f75f50b2a280bfcbf849d8710c8e61d369c533acf307eda064}
DEV_INITRD_SCRIPT=${DEV_INITRD_SCRIPT:-"$ROOT_DIR/build-dev-initrd.sh"}

BOOT_START_SECTOR=2048
SECTORS_PER_MIB=2048
BOOT_SECTORS=$((BOOT_SIZE_MIB * SECTORS_PER_MIB))
ROOT_START_SECTOR=$((BOOT_START_SECTOR + BOOT_SECTORS))
IMAGE_SIZE_MIB=$((BOOT_SIZE_MIB + ROOT_SIZE_MIB + 2))

KERNEL_OFFSET=${KERNEL_OFFSET:-0x00008000}
RAMDISK_OFFSET=${RAMDISK_OFFSET:-0x01500000}
TAGS_OFFSET=${TAGS_OFFSET:-0x00000100}
BOOT_BASE=${BOOT_BASE:-0x80200000}
BOOT_PAGESIZE=${BOOT_PAGESIZE:-2048}

DEFAULT_CMDLINE='earlycon=msm_serial_dm,0x16440000 console=tty0 console=ttyMSM0,115200n8 ignore_loglevel loglevel=8 clk_ignore_unused pd_ignore_unused root=UUID=@ROOT_UUID@ rw rootwait panic=0'
DEV_CMDLINE='earlycon=msm_serial_dm,0x16440000 console=tty0 console=ttyMSM0,115200n8 ignore_loglevel loglevel=8 clk_ignore_unused pd_ignore_unused rdinit=/init panic=0'

[[ -d "$LINUX_DIR" ]] || die "kernel tree not found: $LINUX_DIR"
[[ -f "$LINUX_DIR/Makefile" ]] || die "kernel Makefile not found in: $LINUX_DIR"

need make
need parted
need mkfs.ext2
need mkfs.ext4
need debugfs
need blkid
need dd
need truncate
need mkbootimg

if [[ "$SPARSE" == 1 ]]; then
	need img2simg
fi

mkdir -p "$OUT_DIR" "$BUILD_DIR"

DEV_INITRAMFS=0
case "$INITRAMFS" in
	dev|minimal)
		DEV_INITRAMFS=1
		INITRAMFS="$OUT_DIR/dev-initramfs.cpio.gz"
		[[ -x "$DEV_INITRD_SCRIPT" ]] || die "dev initrd builder not executable: $DEV_INITRD_SCRIPT"
		"$DEV_INITRD_SCRIPT" \
			OUTPUT="$INITRAMFS" \
			OUT_DIR="$OUT_DIR" \
			LINUX_DIR="$LINUX_DIR" \
			HOSTCC="$HOSTCC" \
			BUSYBOX="$BUSYBOX" \
			BUSYBOX_URL="$BUSYBOX_URL" \
			BUSYBOX_SHA256="$BUSYBOX_SHA256" \
			KEEP_WORK="$KEEP_WORK"
		;;
	auto)
		die 'INITRAMFS=auto was removed; use INITRAMFS=dev or a path'
		;;
	none)
		INITRAMFS=
		;;
esac

if [[ "$DEV_INITRAMFS" == 1 && -z "${CMDLINE+x}" ]]; then
	CMDLINE_TEMPLATE=$DEV_CMDLINE
else
	CMDLINE_TEMPLATE=${CMDLINE:-$DEFAULT_CMDLINE}
fi

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
VMLINUX="$OUT_DIR/vmlinuz"
ZIMAGE_DTB="$OUT_DIR/zImage-dtb"
ANDROID_BOOT_IMG="$OUT_DIR/boot.img"

[[ -f "$ZIMAGE" ]] || die "missing zImage: $ZIMAGE"
[[ -f "$DTB_PATH" ]] || die "missing DTB: $DTB_PATH"

cp "$ZIMAGE" "$ZIMAGE_DTB"
cat "$DTB_PATH" >> "$ZIMAGE_DTB"
install -m 0644 "$ZIMAGE_DTB" "$VMLINUX"

WORK_DIR="$OUT_DIR/work"
if [[ "$KEEP_WORK" != 1 ]]; then
	rm -rf "$WORK_DIR"
fi
mkdir -p "$WORK_DIR"

BOOT_FS="$WORK_DIR/express-boot.ext2"
ROOT_FS="$WORK_DIR/express-root.ext4"
EXTLINUX_CONF="$WORK_DIR/extlinux.conf"
EMPTY_RAMDISK="$WORK_DIR/empty-ramdisk"

truncate -s "${BOOT_SIZE_MIB}M" "$BOOT_FS"
truncate -s "${ROOT_SIZE_MIB}M" "$ROOT_FS"

printf '==> Creating filesystems\n'
mkfs.ext2 -F -L express_boot "$BOOT_FS" >/dev/null
mkfs.ext4 -F -L express_root "$ROOT_FS" >/dev/null

BOOT_UUID=$(blkid -s UUID -o value "$BOOT_FS")
ROOT_UUID=$(blkid -s UUID -o value "$ROOT_FS")
CMDLINE=${CMDLINE_TEMPLATE//@BOOT_UUID@/$BOOT_UUID}
CMDLINE=${CMDLINE//@ROOT_UUID@/$ROOT_UUID}

cat > "$EXTLINUX_CONF" <<EOF
timeout 1
default mainline
menu title expressltexx mainline test

label mainline
	kernel /vmlinuz
	fdt /$DTB
EOF

if [[ -n "$INITRAMFS" ]]; then
	cat >> "$EXTLINUX_CONF" <<EOF
	initrd /initramfs
EOF
fi

cat >> "$EXTLINUX_CONF" <<EOF
	append $CMDLINE
EOF

: > "$EMPTY_RAMDISK"

printf '==> Creating Android boot.img side artifact\n'
MKBOOTIMG_ARGS=(
	--kernel "$ZIMAGE_DTB"
	--base "$BOOT_BASE"
	--kernel_offset "$KERNEL_OFFSET"
	--ramdisk_offset "$RAMDISK_OFFSET"
	--tags_offset "$TAGS_OFFSET"
	--pagesize "$BOOT_PAGESIZE"
	--header_version 0
	--cmdline "$CMDLINE"
	--output "$ANDROID_BOOT_IMG"
)

if [[ -n "$INITRAMFS" ]]; then
	MKBOOTIMG_ARGS+=(--ramdisk "$INITRAMFS")
else
	MKBOOTIMG_ARGS+=(--ramdisk "$EMPTY_RAMDISK")
fi

mkbootimg "${MKBOOTIMG_ARGS[@]}"

printf '==> Populating extlinux boot filesystem\n'
debugfs -w -R 'mkdir /extlinux' "$BOOT_FS" >/dev/null 2>&1
debugfs -w -R 'mkdir /dtbs' "$BOOT_FS" >/dev/null 2>&1
debugfs -w -R "write $VMLINUX /vmlinuz" "$BOOT_FS" >/dev/null
debugfs -w -R "write $DTB_PATH /$DTB" "$BOOT_FS" >/dev/null
debugfs -w -R "write $DTB_PATH /dtbs/$DTB" "$BOOT_FS" >/dev/null
debugfs -w -R "write $EXTLINUX_CONF /extlinux/extlinux.conf" "$BOOT_FS" >/dev/null

if [[ "$INCLUDE_BOOTIMG" == 1 ]]; then
	debugfs -w -R "write $ANDROID_BOOT_IMG /boot.img" "$BOOT_FS" >/dev/null
fi

if [[ -n "$INITRAMFS" ]]; then
	debugfs -w -R "write $INITRAMFS /initramfs" "$BOOT_FS" >/dev/null
fi

printf '==> Creating MBR userdata image\n'
rm -f "$IMAGE"
truncate -s "${IMAGE_SIZE_MIB}M" "$IMAGE"
BOOT_END_MIB=$((1 + BOOT_SIZE_MIB))
ROOT_END_MIB=$((BOOT_END_MIB + ROOT_SIZE_MIB))
parted -s "$IMAGE" \
	mklabel msdos \
	mkpart primary ext2 1MiB "${BOOT_END_MIB}MiB" \
	set 1 boot on \
	mkpart primary ext4 "${BOOT_END_MIB}MiB" "${ROOT_END_MIB}MiB" >/dev/null

dd if="$BOOT_FS" of="$IMAGE" bs=512 seek="$BOOT_START_SECTOR" conv=notrunc,sparse status=none
dd if="$ROOT_FS" of="$IMAGE" bs=512 seek="$ROOT_START_SECTOR" conv=notrunc,sparse status=none
parted -s "$IMAGE" unit s print >/dev/null

SPARSE_IMAGE=${SPARSE_IMAGE:-"${IMAGE%.img}.sparse.img"}
if [[ "$SPARSE" == 1 ]]; then
	rm -f "$SPARSE_IMAGE"
	img2simg "$IMAGE" "$SPARSE_IMAGE"
fi

printf '\n==> Wrote %s\n' "$IMAGE"
printf '    boot UUID: %s\n' "$BOOT_UUID"
printf '    root UUID: %s\n' "$ROOT_UUID"
printf '    DTB:       %s\n' "$DTB"
printf '    extlinux:  %s\n' "$CMDLINE"
printf '\nFlash with:\n'
if [[ "$SPARSE" == 1 ]]; then
	printf '  fastboot flash userdata %q\n' "$SPARSE_IMAGE"
	printf '\nRaw image, if needed:\n'
	printf '  fastboot flash userdata %q\n' "$IMAGE"
else
	printf '  fastboot flash userdata %q\n' "$IMAGE"
fi
printf '\nThen reboot with the UART cable attached and capture logs.\n'

if [[ "$KEEP_WORK" != 1 ]]; then
	printf '\nIntermediate files are under %s and will be replaced on the next run.\n' "$WORK_DIR"
fi
