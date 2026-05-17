#!/usr/bin/env bash
# Build the local mkosi/APK mini initrd for expressltexx bring-up.

set -euo pipefail

die() {
	printf 'error: %s\n' "$*" >&2
	exit 1
}

have() {
	command -v "$1" >/dev/null 2>&1
}

usage() {
	cat <<'EOF'
Usage: ./build-minitrd.sh [KEY=value ...]

Builds ./minitrd with mkosi as an Alpine/postmarketOS-derived ARMv7 cpio.gz initramfs.

Environment overrides:

  MKOSI       mkosi executable (default: $HOME/src/mkosi/bin/mkosi)
  OUT_DIR     Output directory (default: ./out/expressltexx)
  OUTPUT      Output cpio.gz (default: $OUT_DIR/minitrd.cpio.gz)
  KEEP_WORK=1 Keep mkosi output directory (default: 0)
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
MKOSI=${MKOSI:-"$HOME/src/mkosi/bin/mkosi"}
OUT_DIR=${OUT_DIR:-"$ROOT_DIR/out/expressltexx"}
OUTPUT=${OUTPUT:-"$OUT_DIR/minitrd.cpio.gz"}
KEEP_WORK=${KEEP_WORK:-0}

[[ -x "$MKOSI" ]] || die "mkosi not executable: $MKOSI"
have stat || die 'missing required tool: stat'

MINITRD_DIR="$ROOT_DIR/minitrd"
WORK_DIR="$OUT_DIR/minitrd-mkosi"
MKOSI_OUTPUT="$WORK_DIR/output/minitrd.cpio.gz"

[[ -f "$MINITRD_DIR/mkosi.conf" ]] || die "missing mkosi config: $MINITRD_DIR/mkosi.conf"
mkdir -p "$OUT_DIR" "$WORK_DIR"

if [[ "$KEEP_WORK" != 1 ]]; then
	rm -rf "$WORK_DIR"
	mkdir -p "$WORK_DIR"
fi

printf '==> Building minitrd with %s\n' "$MKOSI"
"$MKOSI" \
	-C "$MINITRD_DIR" \
	--force \
	--output-directory "$WORK_DIR/output" \
	--workspace-directory "$WORK_DIR/workspace" \
	--cache-directory "$WORK_DIR/cache" \
	--package-cache-directory "$WORK_DIR/pkgcache" \
	build

[[ -f "$MKOSI_OUTPUT" ]] || die "mkosi output not found: $MKOSI_OUTPUT"
install -m 0644 "$MKOSI_OUTPUT" "$OUTPUT"

size=$(stat -c%s "$OUTPUT")
printf '==> Wrote minitrd %s (%s bytes)\n' "$OUTPUT" "$size"
