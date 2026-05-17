#!/usr/bin/env bash
# Build/package the local kernel through pmbootstrap's envkernel path.

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
Usage: ./build-pmos-envkernel.sh [KEY=value ...]

Builds ./linux with O=.output, packages that build output via:

  pmbootstrap build --envkernel linux-postmarketos-qcom-msm8227

Then runs the selected pmbootstrap action for fast kernel round trips.

Environment overrides:

  LINUX_DIR       Kernel tree path (default: ./linux)
  PMAPORTS_DIR   pmaports checkout path (default: ./pmaports)
  KERNEL_PKG     Kernel aport (default: linux-postmarketos-qcom-msm8227)
  DEVICE          Required pmbootstrap device (default: samsung-expressltexx)
  OUT_DIR         Kbuild output dir relative to LINUX_DIR (default: .output)
  ARCH            Kernel ARCH (default: arm)
  CROSS_COMPILE   ARM GCC cross prefix; auto-detected when unset
  LLVM            LLVM suffix/prefix for kernel builds; opt-in fallback only
  JOBS            make -j value (default: nproc)
  MAKE_ARGS       Extra arguments appended to kernel make invocations
  PMBOOTSTRAP     pmbootstrap command (default: pmbootstrap)
  ACTION          package, install, boot, flash_kernel, or none (default: boot)
  SKIP_BUILD=1    Reuse existing LINUX_DIR/OUT_DIR artifacts

Examples:

  ./build-pmos-envkernel.sh
  ./build-pmos-envkernel.sh ACTION=package
  ./build-pmos-envkernel.sh ACTION=flash_kernel

ACTION=boot uses pmbootstrap flasher boot, which should fastboot-boot the
generated boot image without flashing it. ACTION=flash_kernel is destructive.
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
PMAPORTS_DIR=${PMAPORTS_DIR:-"$ROOT_DIR/pmaports"}
KERNEL_PKG=${KERNEL_PKG:-linux-postmarketos-qcom-msm8227}
DEVICE=${DEVICE:-samsung-expressltexx}
OUT_DIR=${OUT_DIR:-.output}
ARCH=${ARCH:-arm}
JOBS=${JOBS:-$(nproc)}
PMBOOTSTRAP=${PMBOOTSTRAP:-pmbootstrap}
ACTION=${ACTION:-boot}
SKIP_BUILD=${SKIP_BUILD:-0}

[[ -d "$LINUX_DIR" ]] || die "kernel tree not found: $LINUX_DIR"
[[ -f "$LINUX_DIR/Makefile" ]] || die "kernel Makefile not found in: $LINUX_DIR"
[[ -d "$PMAPORTS_DIR" ]] || die "pmaports checkout not found: $PMAPORTS_DIR"
[[ -f "$PMAPORTS_DIR/device/testing/$KERNEL_PKG/APKBUILD" ]] || \
	die "kernel aport not found: $PMAPORTS_DIR/device/testing/$KERNEL_PKG/APKBUILD"

need make
need "$PMBOOTSTRAP"

configured_device=$("$PMBOOTSTRAP" -p "$PMAPORTS_DIR" config device 2>/dev/null || true)
if [[ "$configured_device" != "$DEVICE" ]]; then
	die "pmbootstrap device is '$configured_device', expected '$DEVICE'; run pmbootstrap -p '$PMAPORTS_DIR' init"
fi

make_args=(ARCH="$ARCH" O="$OUT_DIR")
toolchain_desc=none

if [[ -n "${CROSS_COMPILE:-}" ]]; then
	need "${CROSS_COMPILE}gcc"
	make_args+=(CROSS_COMPILE="$CROSS_COMPILE")
	toolchain_desc="GCC ${CROSS_COMPILE}"
else
	for prefix in arm-linux-gnueabi- arm-linux-gnueabihf- arm-linux-gnu- arm-none-eabi-; do
		if have "${prefix}gcc"; then
			CROSS_COMPILE=$prefix
			make_args+=(CROSS_COMPILE="$CROSS_COMPILE")
			toolchain_desc="GCC ${CROSS_COMPILE}"
			break
		fi
	done
fi

if [[ "$toolchain_desc" == none ]]; then
	if [[ -n "${LLVM:-}" ]]; then
		make_args+=(LLVM="$LLVM" LLVM_IAS="${LLVM_IAS:-1}")
		toolchain_desc="LLVM ${LLVM}"
	elif have clang && have ld.lld; then
		make_args+=(LLVM=1 LLVM_IAS="${LLVM_IAS:-1}")
		toolchain_desc='LLVM'
	else
		die 'no ARM GCC cross compiler found and LLVM toolchain is incomplete; set CROSS_COMPILE= or LLVM='
	fi
fi

if [[ -n "${MAKE_ARGS:-}" ]]; then
	# shellcheck disable=SC2206 # Intentionally allow users to pass make-style words.
	extra_make_args=($MAKE_ARGS)
	make_args+=("${extra_make_args[@]}")
fi

if [[ "$SKIP_BUILD" != 1 ]]; then
	printf '==> Using %s\n' "$toolchain_desc"
	printf '==> Configuring qcom_defconfig in %s/%s\n' "$LINUX_DIR" "$OUT_DIR"
	make -C "$LINUX_DIR" "${make_args[@]}" qcom_defconfig

	printf '==> Building local kernel artifacts\n'
	make -C "$LINUX_DIR" "${make_args[@]}" -j"$JOBS"
else
	printf '==> SKIP_BUILD=1: reusing artifacts from %s/%s\n' "$LINUX_DIR" "$OUT_DIR"
fi

[[ -f "$LINUX_DIR/$OUT_DIR/include/config/kernel.release" ]] || \
	die "missing envkernel build output: $LINUX_DIR/$OUT_DIR/include/config/kernel.release"

printf '==> Packaging %s with pmbootstrap envkernel\n' "$KERNEL_PKG"
(
	cd "$LINUX_DIR"
	"$PMBOOTSTRAP" -p "$PMAPORTS_DIR" build --force --envkernel "$KERNEL_PKG"
)

case "$ACTION" in
	none|package)
		printf '\n==> Packaged %s; not updating an install or booting.\n' "$KERNEL_PKG"
		;;
	install)
		printf '==> Updating pmbootstrap install image/chroot\n'
		"$PMBOOTSTRAP" -p "$PMAPORTS_DIR" install
		;;
	boot)
		printf '==> Booting generated postmarketOS kernel image\n'
		"$PMBOOTSTRAP" -p "$PMAPORTS_DIR" flasher boot
		;;
	flash_kernel)
		printf '==> Flashing generated postmarketOS kernel image\n'
		"$PMBOOTSTRAP" -p "$PMAPORTS_DIR" flasher flash_kernel
		;;
	*)
		die "unknown ACTION: $ACTION"
		;;
esac
