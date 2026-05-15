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
  MINIMAL_BUSYBOX_SOURCE Compressed cpio containing usr/bin/busybox and musl
                         (default: /tmp/postmarketOS-export/initramfs,
                         falling back to prior local initramfs artifacts)
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
MINIMAL_BUSYBOX_SOURCE=${MINIMAL_BUSYBOX_SOURCE:-/tmp/postmarketOS-export/initramfs}
HOSTCC=${HOSTCC:-cc}
KEEP_WORK=${KEEP_WORK:-1}

[[ -f "$LINUX_DIR/usr/gen_init_cpio.c" ]] || die "missing gen_init_cpio source: $LINUX_DIR/usr/gen_init_cpio.c"

if [[ ! -f "$MINIMAL_BUSYBOX_SOURCE" && "$MINIMAL_BUSYBOX_SOURCE" == /tmp/postmarketOS-export/initramfs ]]; then
	for candidate in "$OUT_DIR/minimal-initramfs.cpio.gz" "$OUT_DIR/dev-initramfs.cpio.gz"; do
		if [[ -f "$candidate" ]]; then
			MINIMAL_BUSYBOX_SOURCE=$candidate
			break
		fi
	done
fi

[[ -f "$MINIMAL_BUSYBOX_SOURCE" ]] || die "minimal initramfs source not found: $MINIMAL_BUSYBOX_SOURCE"

need "$HOSTCC"
need cpio
need gzip

STAGING=${STAGING:-"$OUT_DIR/dev-initrd-work"}
EXTRACT_DIR="$STAGING/extract"
GEN_INIT_CPIO="$STAGING/gen_init_cpio"
SPEC="$STAGING/initramfs.list"
INIT_SCRIPT="$STAGING/init"
CPIO_FILE="$STAGING/initramfs.cpio"

rm -rf "$STAGING"
mkdir -p "$EXTRACT_DIR" "$(dirname "$OUTPUT")"

gzip -dc "$MINIMAL_BUSYBOX_SOURCE" | \
	(cd "$EXTRACT_DIR" && cpio -id --quiet \
		"usr/bin/busybox" \
		"usr/lib/ld-musl-armhf.so.1" \
		"bin/busybox" \
		"lib/ld-musl-armhf.so.1")

BUSYBOX_PATH=
MUSL_PATH=

for candidate in "$EXTRACT_DIR/usr/bin/busybox" "$EXTRACT_DIR/bin/busybox"; do
	if [[ -f "$candidate" ]]; then
		BUSYBOX_PATH=$candidate
		break
	fi
done

for candidate in "$EXTRACT_DIR/usr/lib/ld-musl-armhf.so.1" "$EXTRACT_DIR/lib/ld-musl-armhf.so.1"; do
	if [[ -f "$candidate" ]]; then
		MUSL_PATH=$candidate
		break
	fi
done

[[ -n "$BUSYBOX_PATH" ]] || \
	die "minimal initramfs source lacks busybox: $MINIMAL_BUSYBOX_SOURCE"
[[ -n "$MUSL_PATH" ]] || \
	die "minimal initramfs source lacks ld-musl-armhf.so.1: $MINIMAL_BUSYBOX_SOURCE"

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
dir /lib 0755 0 0
dir /usr 0755 0 0
dir /usr/lib 0755 0 0
file /init $INIT_SCRIPT 0755 0 0
file /bin/busybox $BUSYBOX_PATH 0755 0 0
file /lib/ld-musl-armhf.so.1 $MUSL_PATH 0755 0 0
slink /lib/libc.musl-armv7.so.1 ld-musl-armhf.so.1 0777 0 0
slink /usr/lib/ld-musl-armhf.so.1 ../../lib/ld-musl-armhf.so.1 0777 0 0
slink /usr/lib/libc.musl-armv7.so.1 ld-musl-armhf.so.1 0777 0 0
nod /dev/console 0600 0 0 c 5 1
nod /dev/null 0666 0 0 c 1 3
nod /dev/zero 0666 0 0 c 1 5
nod /dev/tty 0666 0 0 c 5 0
slink /bin/ash busybox 0777 0 0
slink /bin/cat busybox 0777 0 0
slink /bin/dd busybox 0777 0 0
slink /bin/dmesg busybox 0777 0 0
slink /bin/echo busybox 0777 0 0
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
