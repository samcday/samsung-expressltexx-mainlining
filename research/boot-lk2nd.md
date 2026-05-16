# lk2nd, Boot Images, And Test Helpers

Use this file when reasoning about Android boot image layout, lk2nd handoff behavior, local image builders, initramfs placement, and direct `fastboot boot` testing.

## lk2nd Linux boot.img Helpers

Values currently used:

- Direct fastboot round trips use an Android boot image at `out/expressltexx/expressltexx-boot.img` with base `0x80200000`, kernel offset `0x00008000`, ramdisk offset `0x02200000`, tags offset `0x00000100`, and page size `2048`.
- The direct boot ramdisk offset intentionally differs from downstream Android's `0x02000000`: `0x80200000 + 0x02200000 = 0x82400000`, matching lk2nd's extlinux-tested initrd placement after the direct `0x82200000` image booted Linux but reached `unknown-block(0,0)` without an initramfs.
- Direct fastboot images pass the dev initramfs as the Android boot image ramdisk. An earlier fastboot boot with external gzip initrd at `0x82400000` reached Linux with the right DTB and initrd size, but Linux rejected the external rootfs image as `invalid magic at start of compressed archive` before falling back to `unknown-block(0,0)`.
- The fastboot-bootable kernel payload is appended `zImage+DTB` so the Android boot path does not depend on a separate DTB handoff.
- The userdata fallback creates an MBR extlinux image with appended `zImage+DTB` as `/vmlinuz` plus a separate `fdt` entry for lk2nd. The kernel consumes the appended DTB, so the Express board DT carries a usable RAM map for this path. The Android `boot.img` side artifact also uses appended `zImage+DTB`; its ramdisk offset remains `0x01500000`, so prefer `build-lk2nd-bootable.sh` for direct `fastboot boot` testing.
- Userdata images do not include an initramfs by default. Use `INITRAMFS=dev` when this fallback path should include the BusyBox bring-up shell as an extlinux initrd.
- The local helpers keep `earlycon` and `ttyMSM0` console output but no longer force `DEBUG_LL`, `DEBUG_QCOM_UARTDM`, or `EARLY_PRINTK`; that low-level mapping produced `BUG: mapping for 0x16440000 at 0xf0040000 out of vmalloc space` once normal earlycon was sufficient.

Sources:

- `android_device_samsung_expressltexx/BoardConfig.mk:34-39` gives downstream boot cmdline, base, image name, ramdisk offset, and page size.
- `lk2nd/app/aboot/aboot.c:3378-3409` shows the fastboot boot path using mkbootimg header kernel/ramdisk/tags addresses and validating their DDR ranges.
- `lk2nd/app/aboot/aboot.c:3438-3457` shows the fastboot boot path falling back to an appended DTB if no separate DTB was copied.
- `lk2nd/lk2nd/boot/extlinux.c:479-504` defines the extlinux fallback layout as `MAX_KERNEL_SIZE = 32 MiB`, `MAX_TAGS_SIZE = 2 MiB`, `tags = base + MAX_KERNEL_SIZE`, and `ramdisk = tags + MAX_TAGS_SIZE`.
- `lk2nd/lk2nd/boot/extlinux.c:577-635` loads the extlinux `fdt` into the tags address, loads an optional initramfs, and passes both to `boot_linux()`.
- `lk2nd/platform/msm_shared/dev_tree.c:2260-2335` updates the passed FDT's `/memory` node and optional `linux,initrd-start` / `linux,initrd-end` properties before Linux entry.
- `linux/arch/arm/boot/compressed/head.S:367-420` shows that an appended DTB makes zImage switch to the appended tree after the ATAG compatibility hook.
- `linux/arch/arm/boot/compressed/atags_to_fdt.c:143-145` treats an `r2` pointer that already contains an FDT as success, so no ATAGS fallback merge is attempted.
- `linux/arch/arm/boot/dts/qcom/qcom-msm8930.dtsi:98-101` keeps the MSM8930 memory placeholder at `0x80200000`, the first RAM address that should be usable by the ARM decompressor.
- `linux/arch/arm/boot/dts/qcom/qcom-msm8930-samsung-expressltexx.dts:107-110` gives appended-DTB boot paths the tested Express usable RAM ranges.
- `boot.log:50-55` captured a successful lk2nd extlinux handoff with `ramdisk @ 0x82400000 (891166)`, which later reached `/init` from the dev initrd.
- `boot.log:1-4` captured the direct fastboot handoff with `ramdisk @ 0x82400000 (891680)` and `tags/device tree @ 0x80200100`.
- `boot.log:128-132` captured Linux detecting the external initrd, trying to unpack it, rejecting it as not initramfs, and freeing 872 KiB of initrd memory.
- `boot.log:186-190` captured `rdinit=/init` failing with `-2` and the resulting `unknown-block(0,0)` root mount failure.
- `boot.log:11-16` captured normal earlycon working followed by the low-level debug mapping warning that the local helper cleanup removes.
- Earlier hardware logs showed separate extlinux `fdt` did not reach ARM Linux (`r2=0`), while appended `zImage+DTB` did. Later testing after `026273fba1ee49e4c3aab8d880f779f08263f600` showed the appended-DTB zImage discarding lk2nd's patched external FDT and keeping the zero-size RAM placeholder; this is why the board DT now carries the tested usable memory ranges.
- A plain extlinux `zImage` attempt did let lk2nd pass the external FDT and initramfs addresses, but it stopped before Linux printed earlycon output. Keep the userdata fallback on appended `zImage+DTB` unless lk2nd's fixed extlinux FDT/initrd placement is changed or the decompressor overlap is otherwise resolved.

Current use:

- `build-lk2nd-bootable.sh:88-95` defines Android boot-image layout defaults for direct `fastboot boot` testing.
- The image helpers configure the kernel with `qcom_defconfig` directly; Express bring-up requirements live in `linux/arch/arm/configs/qcom_defconfig` instead of helper-side `scripts/config` edits.
- `build-lk2nd-bootable.sh:182-201` creates appended `zImage+DTB` and passes it plus the dev initrd to `mkbootimg`.
- `build-lk2nd-bootable.sh:216` prints the intended `fastboot boot out/expressltexx/expressltexx-boot.img` command.
- `build-lk2nd-userdata.sh:101-105` keeps the fallback userdata side-artifact boot-image layout values.
- `build-lk2nd-userdata.sh:215-217` creates appended `zImage+DTB` for both extlinux `/vmlinuz` and the Android `boot.img` side artifact.
- `build-lk2nd-userdata.sh:242-260` writes the extlinux `kernel`, `fdt`, optional external `initrd`, and `append` entries that lk2nd consumes.

Notes:

- `build-lk2nd-userdata.sh` remains the recovery/fallback path when USB gadget or fastboot boot is unavailable.
- `build-dev-initrd.sh` owns the tiny BusyBox/configfs CDC-ACM initrd shared by both local lk2nd image builders.

## lk2nd Android boot.img Wrapper For U-Boot

Values currently used:

- Android boot image base is `0x80200000`.
- ARM32 kernel offset is `0x00008000`, so normal kernel load is `0x80208000`.
- For U-Boot, the wrapper loads at `0x80207f00` with a 256-byte branch stub to U-Boot's linked `0x80208000`.
- Tags offset is `0x00000100`.
- Android ramdisk offset from downstream BoardConfig is `0x02000000`; the wrapper uses a 1-byte ramdisk so lk2nd does not reject a zero ramdisk address.
- Android boot page size is `2048`.
- Boot partition size guard is `10485760` bytes.
- lk2nd's uncompressed kernel path expects a `UNCOMPRESSED_IMG` prefix with a 20-byte header and a DTB offset stored immediately after the magic.
- lk2nd's appended-DTB path may clear the DTB magic it consumes, so the wrapper appends a duplicate DTB after `u-boot-dtb.bin` for lk2nd while leaving U-Boot's internal appended DTB intact.

Sources:

- `android_device_samsung_expressltexx/BoardConfig.mk:34-39` gives downstream boot cmdline, base, image name, ramdisk offset, and page size.
- `android_device_samsung_expressltexx/BoardConfig.mk:60` gives the 10 MiB boot image partition size.
- `lk2nd/target/msm8960/rules.mk:10-14` gives lk2nd MSM8960 base, tags, kernel, and ramdisk addresses.
- `lk2nd/app/aboot/aboot.c:163-169` defines the patched uncompressed-kernel header size and `UNCOMPRESSED_IMG` magic.
- `lk2nd/app/aboot/aboot.c:2050-2069` detects the patched kernel, reads the DTB offset, and skips the 20-byte wrapper header.
- `lk2nd/app/aboot/aboot.c:2087-2099` validates kernel and ramdisk addresses before jumping.
- `lk2nd/platform/msm_shared/dev_tree.c:1281-1298` uses an explicit `dtb_offset`, otherwise reads a DTB offset from `kernel + DTB_OFFSET`.
- `lk2nd/platform/msm_shared/include/dev_tree.h:48-49` defines DTB magic and `DTB_OFFSET = 0x2c`.

Current use:

- `build-test-uboot-bootimg.sh:77-88` sets boot image layout values and lk2nd wrapper constants.
- `build-test-uboot-bootimg.sh:144-158` builds `UNCOMPRESSED_IMG + dtb_offset + branch-stub + u-boot-dtb.bin + duplicate DTB` and creates the non-empty ramdisk.

Notes:

- A plain `mkbootimg --kernel u-boot-dtb.bin --ramdisk empty` failed in lk2nd with `Kernel image not patched..Unable to locate dt offset` and `kernel/ramdisk addresses are not valid`.
- The current wrapper has booted U-Boot to a prompt via `fastboot flash boot out/expressltexx/u-boot-boot.img`.
