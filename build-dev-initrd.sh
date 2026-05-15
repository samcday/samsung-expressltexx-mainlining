#!/usr/bin/env bash
# Build a tiny BusyBox initramfs for expressltexx bring-up.

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

download() {
	local url=$1 output=$2

	if have curl; then
		curl -fL --retry 3 -o "$output" "$url"
	elif have wget; then
		wget -O "$output" "$url"
	else
		die "missing required tool: curl or wget (or set BUSYBOX=path)"
	fi
}

verify_busybox() {
	local actual

	[[ -n "$BUSYBOX_SHA256" ]] || return 0
	need sha256sum
	actual=$(sha256sum "$BUSYBOX")
	actual=${actual%% *}
	[[ "$actual" == "$BUSYBOX_SHA256" ]] || \
		die "busybox checksum mismatch for $BUSYBOX: expected $BUSYBOX_SHA256, got $actual"
}

usage() {
	cat <<'EOF'
Usage: ./build-dev-initrd.sh [KEY=value ...]

Builds a tiny ARM BusyBox initramfs that mounts basic virtual filesystems,
configures a CDC-ACM configfs gadget, starts a shell on /dev/ttyGS0, and keeps
the UART shell on /dev/ttyMSM0 for recovery.

Environment overrides:

  LINUX_DIR              Kernel tree path for usr/gen_init_cpio.c (default: ./linux)
  OUT_DIR                Output/work directory (default: ./out/expressltexx)
  OUTPUT                 Output cpio.gz (default: $OUT_DIR/dev-initramfs.cpio.gz)
  BUSYBOX                Static ARM BusyBox binary (default: $OUT_DIR/cache/busybox-armv7l)
  BUSYBOX_URL            Download URL used when BUSYBOX is missing
  BUSYBOX_SHA256         Expected BusyBox SHA256; set empty to skip verification
  HOSTCC                 Host C compiler for gen_init_cpio (default: cc)
  KEEP_WORK=1            Keep the staging directory (default: 1)
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
OUTPUT=${OUTPUT:-"$OUT_DIR/dev-initramfs.cpio.gz"}
CACHE_DIR=${CACHE_DIR:-"$OUT_DIR/cache"}
BUSYBOX=${BUSYBOX:-"$CACHE_DIR/busybox-armv7l"}
BUSYBOX_URL=${BUSYBOX_URL:-https://busybox.net/downloads/binaries/1.31.0-defconfig-multiarch-musl/busybox-armv7l}
BUSYBOX_SHA256=${BUSYBOX_SHA256:-cd04052b8b6885f75f50b2a280bfcbf849d8710c8e61d369c533acf307eda064}
HOSTCC=${HOSTCC:-cc}
KEEP_WORK=${KEEP_WORK:-1}

[[ -f "$LINUX_DIR/usr/gen_init_cpio.c" ]] || die "missing gen_init_cpio source: $LINUX_DIR/usr/gen_init_cpio.c"

need "$HOSTCC"
need gzip

STAGING=${STAGING:-"$OUT_DIR/dev-initrd-work"}
GEN_INIT_CPIO="$STAGING/gen_init_cpio"
SPEC="$STAGING/initramfs.list"
INIT_SCRIPT="$STAGING/init"
CPIO_FILE="$STAGING/initramfs.cpio"

rm -rf "$STAGING"
mkdir -p "$STAGING" "$(dirname "$OUTPUT")"

if [[ ! -f "$BUSYBOX" ]]; then
	[[ -n "$BUSYBOX_URL" ]] || die "busybox not found and BUSYBOX_URL is empty: $BUSYBOX"
	mkdir -p "$(dirname "$BUSYBOX")"
	tmp_busybox="$BUSYBOX.download"
	rm -f "$tmp_busybox"
	printf '==> Downloading static BusyBox from %s\n' "$BUSYBOX_URL"
	download "$BUSYBOX_URL" "$tmp_busybox"
	mv "$tmp_busybox" "$BUSYBOX"
	chmod 0755 "$BUSYBOX"
fi

[[ -f "$BUSYBOX" ]] || die "busybox not found: $BUSYBOX"
verify_busybox

cat > "$INIT_SCRIPT" <<'EOF'
#!/bin/sh

PATH=/bin:/sbin:/usr/bin:/usr/sbin
export PATH

mount_one() {
	mkdir -p "$2"
	mount -t "$1" "$1" "$2" 2>/dev/null || true
}

mount_one devtmpfs /dev
mkdir -p /dev/pts
[ -c /dev/console ] || mknod /dev/console c 5 1
[ -c /dev/null ] || mknod /dev/null c 1 3
[ -c /dev/kmsg ] || mknod /dev/kmsg c 1 11

log() {
	echo "$*" >/dev/kmsg 2>/dev/null || echo "$*" 2>/dev/null || true
}

for i in 1 2 3 4 5; do
	[ -c /dev/ttyMSM0 ] && break
	log "[initrd] waiting for /dev/ttyMSM0 ($i/5)"
	sleep 1
done

if [ -c /dev/ttyMSM0 ]; then
	stty -F /dev/ttyMSM0 115200 2>/dev/null || true
	exec </dev/ttyMSM0 >/dev/ttyMSM0 2>&1
elif [ -c /dev/console ]; then
	exec </dev/console >/dev/console 2>&1
fi

log '[initrd] expressltexx dev BusyBox initramfs'

mount_one proc /proc
mount_one sysfs /sys
mount_one devpts /dev/pts
mount_one tmpfs /run
mount_one tmpfs /tmp
mkdir -p /root /mnt /sys/kernel/config
mount -t configfs configfs /sys/kernel/config 2>/dev/null || \
	log '[initrd] configfs mount failed or is unavailable'

create_ttygs_node() {
	local major minor

	for i in 1 2 3 4 5; do
		[ -c /dev/ttyGS0 ] && return 0
		if [ -r /sys/class/tty/ttyGS0/dev ]; then
			IFS=: read -r major minor < /sys/class/tty/ttyGS0/dev
			if [ -n "$major" ] && [ -n "$minor" ]; then
				mknod /dev/ttyGS0 c "$major" "$minor" 2>/dev/null || true
			fi
		fi
		sleep 1
	done

	[ -c /dev/ttyGS0 ]
}

start_ttygs_getty() {
	if ! create_ttygs_node; then
		log '[initrd] /dev/ttyGS0 did not appear; skipping USB serial shell'
		return
	fi

	(
		log '[initrd] starting USB serial shell on /dev/ttyGS0'
		while true; do
			/sbin/getty -L -n -l /bin/sh 115200 ttyGS0 vt100 || true
			log '[initrd] ttyGS0 shell exited; respawning in 1s'
			sleep 1
		done
	) &
}

setup_acm_gadget() {
	local gadget_dir udc udc_path

	if [ ! -d /sys/kernel/config/usb_gadget ]; then
		log '[initrd] configfs usb_gadget directory missing'
		return
	fi

	for udc_path in /sys/class/udc/*; do
		[ -e "$udc_path" ] || continue
		udc=${udc_path##*/}
		break
	done

	if [ -z "$udc" ]; then
		log '[initrd] no UDC found for CDC-ACM gadget'
		return
	fi

	gadget_dir=/sys/kernel/config/usb_gadget/g1
	mkdir -p "$gadget_dir" || {
		log '[initrd] failed to create gadget directory'
		return
	}
	cd "$gadget_dir" || return

	echo 0x1d6b > idVendor
	echo 0x0104 > idProduct
	echo 0x0200 > bcdUSB
	echo 0x0100 > bcdDevice
	mkdir -p strings/0x409 configs/c.1/strings/0x409 functions || return
	echo expressltexx > strings/0x409/serialnumber
	echo Samsung > strings/0x409/manufacturer
	echo 'Galaxy Express CDC ACM' > strings/0x409/product
	echo 'CDC ACM serial' > configs/c.1/strings/0x409/configuration
	echo 0x80 > configs/c.1/bmAttributes
	echo 100 > configs/c.1/MaxPower

	if ! mkdir -p functions/acm.usb0; then
		log '[initrd] failed to create ACM function; is CONFIG_USB_CONFIGFS_ACM enabled?'
		return
	fi

	[ -e configs/c.1/acm.usb0 ] || ln -s functions/acm.usb0 configs/c.1/ || return

	if echo "$udc" > UDC; then
		log "[initrd] CDC-ACM gadget bound to $udc"
	else
		log "[initrd] failed to bind CDC-ACM gadget to $udc"
		return
	fi

	start_ttygs_getty
}

log '[initrd] kernel command line:'
cat /proc/cmdline >/dev/kmsg 2>/dev/null || true

log '[initrd] USB device controllers:'
ls -l /sys/class/udc >/dev/kmsg 2>/dev/null || log '[initrd] no /sys/class/udc yet'

setup_acm_gadget

log '[initrd] interactive shell on /dev/ttyMSM0'
while true; do
	if [ -c /dev/ttyMSM0 ]; then
		/sbin/getty -L -n -l /bin/sh 115200 ttyMSM0 vt100 </dev/ttyMSM0 >/dev/ttyMSM0 2>&1 || true
		/bin/sh -i </dev/ttyMSM0 >/dev/ttyMSM0 2>&1 || true
	elif [ -c /dev/console ]; then
		/sbin/getty -L -n -l /bin/sh 115200 console vt100 </dev/console >/dev/console 2>&1 || true
		/bin/sh -i </dev/console >/dev/console 2>&1 || true
	else
		/bin/sh -i || true
	fi
	log '[initrd] shell exited; respawning in 1s'
	sleep 1
done
EOF
chmod 0755 "$INIT_SCRIPT"

"$HOSTCC" -O2 -o "$GEN_INIT_CPIO" "$LINUX_DIR/usr/gen_init_cpio.c"

cat > "$SPEC" <<EOF
dir /bin 0755 0 0
dir /sbin 0755 0 0
dir /dev 0755 0 0
dir /proc 0755 0 0
dir /sys 0755 0 0
dir /run 0755 0 0
dir /tmp 01777 0 0
dir /root 0700 0 0
dir /mnt 0755 0 0
dir /etc 0755 0 0
dir /var 0755 0 0
dir /var/run 0755 0 0
file /init $INIT_SCRIPT 0755 0 0
file /bin/busybox $BUSYBOX 0755 0 0
nod /dev/console 0600 0 0 c 5 1
nod /dev/kmsg 0600 0 0 c 1 11
nod /dev/null 0666 0 0 c 1 3
nod /dev/zero 0666 0 0 c 1 5
nod /dev/tty 0666 0 0 c 5 0
slink /bin/[ busybox 0777 0 0
slink /bin/ash busybox 0777 0 0
slink /bin/blkid busybox 0777 0 0
slink /bin/cat busybox 0777 0 0
slink /bin/dd busybox 0777 0 0
slink /bin/dmesg busybox 0777 0 0
slink /bin/echo busybox 0777 0 0
slink /bin/fdisk busybox 0777 0 0
slink /bin/find busybox 0777 0 0
slink /bin/grep busybox 0777 0 0
slink /bin/hexdump busybox 0777 0 0
slink /bin/ln busybox 0777 0 0
slink /bin/ls busybox 0777 0 0
slink /bin/mkdir busybox 0777 0 0
slink /bin/mknod busybox 0777 0 0
slink /bin/mount busybox 0777 0 0
slink /bin/ps busybox 0777 0 0
slink /bin/sh busybox 0777 0 0
slink /bin/sleep busybox 0777 0 0
slink /bin/setsid busybox 0777 0 0
slink /bin/stty busybox 0777 0 0
slink /bin/sync busybox 0777 0 0
slink /bin/true busybox 0777 0 0
slink /bin/umount busybox 0777 0 0
slink /bin/uname busybox 0777 0 0
slink /sbin/blkid ../bin/busybox 0777 0 0
slink /sbin/fdisk ../bin/busybox 0777 0 0
slink /sbin/getty ../bin/busybox 0777 0 0
slink /sbin/poweroff ../bin/busybox 0777 0 0
slink /sbin/reboot ../bin/busybox 0777 0 0
EOF

"$GEN_INIT_CPIO" -o "$CPIO_FILE" "$SPEC"
gzip -n -9 < "$CPIO_FILE" > "$OUTPUT"
printf '==> Wrote dev initramfs %s\n' "$OUTPUT"

if [[ "$KEEP_WORK" != 1 ]]; then
	rm -rf "$STAGING"
fi
