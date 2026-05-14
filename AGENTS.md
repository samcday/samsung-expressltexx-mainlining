# Samsung GT-I8730 / expressltexx Bring-Up Notes

Device: Samsung Galaxy Express GT-I8730 / GT-I8730T, Android codename `expressltexx` / `expresslte`.

Current goal: produce the smallest useful mainline Linux boot image that runs on the device far enough to prove lk2nd loads it and UART logging works. Display, storage, sensors, Wi-Fi, modem, audio, and charging are later milestones.

## Workspace

Mainline work happens in `linux/` on branch `samsung-expressltexx`.

Primary downstream/reference repos are checked out on these branches:

- `android_device_samsung_expressltexx`: `lineage-15.1`
- `android_device_samsung_msm8930-common`: `lineage-15.1`
- `android_device_samsung_qcom-common`: `lineage-15.1`
- `android_kernel_samsung_msm8930-common`: `lineage-15.1`

## Device Facts

Downstream naming is confusing. Android uses `TARGET_BOARD_PLATFORM := msm8960`, `TARGET_BOOTLOADER_BOARD_NAME := MSM8960`, and several blobs named `*.msm8960.so`, but the downstream kernel enables `CONFIG_ARCH_MSM8930=y` and `CONFIG_MACH_EXPRESS=y`. Treat this as MSM8930-family hardware sharing MSM8960-era Qualcomm code.

The downstream kernel is Linux 3.4.113 and this board is not described with devicetree there. Hardware details mostly live in old ARM board files, GPIO headers, defconfigs, and Android makefiles.

Mainline currently has `arch/arm/boot/dts/qcom/qcom-msm8960.dtsi` and `arch/arm/boot/dts/qcom/qcom-msm8960-samsung-expressatt.dts`, but no `qcom-msm8930.dtsi`. Use `expressatt` only as a style/comparison reference. Do not copy its GPIOs, regulators, or peripherals blindly.

## Boot And UART

lk2nd is already flashed to the device boot partitions.

UART access is through the USB connector. The MUIC detects about 619K ohms between GND and ID, then routes UART RX/TX to D+/D-. In this mode normal USB/fastboot over the same connector may not be available, so do not assume `fastboot boot` is usable while UART is connected.

For iterative testing, prefer a workflow that builds a boot image, flashes it to a known test partition or slot, and captures UART logs. Avoid overwriting the known-good lk2nd setup unless the user explicitly asks.

First boot success criterion is simple: lk2nd starts the kernel and the kernel prints something useful on UART, even if it panics later because no full board support or rootfs exists.

## Primary Downstream Oracle

Use these files first when extracting hardware details:

- `android_kernel_samsung_msm8930-common/arch/arm/configs/samsung_express_defconfig`
- `android_kernel_samsung_msm8930-common/arch/arm/configs/msm8930_express_eur_lte_defconfig`
- `android_kernel_samsung_msm8930-common/arch/arm/mach-msm/board-express.c`
- `android_kernel_samsung_msm8930-common/arch/arm/mach-msm/board-express-gpiomux.c`
- `android_kernel_samsung_msm8930-common/arch/arm/mach-msm/include/mach/express-gpio.h`
- `android_kernel_samsung_msm8930-common/arch/arm/mach-msm/board-8930-display.c`
- `android_kernel_samsung_msm8930-common/arch/arm/mach-msm/board-8930-camera.c`
- `android_kernel_samsung_msm8930-common/arch/arm/mach-msm/board-8930-camera-power.c`
- `android_kernel_samsung_msm8930-common/arch/arm/mach-msm/board-8930-pmic.c`
- `android_kernel_samsung_msm8930-common/arch/arm/mach-msm/board-8930-storage.c`
- `android_kernel_samsung_msm8930-common/arch/arm/mach-msm/board-8930-gpu.c`
- `android_kernel_samsung_msm8930-common/arch/arm/mach-msm/board-8930-input-mxt.c`
- `android_kernel_samsung_msm8930-common/arch/arm/mach-msm/board-8930-input-tkey.c`
- `android_kernel_samsung_msm8930-common/arch/arm/mach-msm/board-8930-regulator-pm8038.c`
- `android_kernel_samsung_msm8930-common/arch/arm/mach-msm/board-8930-regulator-pm8917.c`

## Android-Side Clues

Use Android device files for boot image layout, partition names, firmware/blob names, and broad subsystem hints:

- `android_device_samsung_expressltexx/BoardConfig.mk`
- `android_device_samsung_expressltexx/rootdir/fstab.qcom`
- `android_device_samsung_expressltexx/rootdir/ueventd.qcom.rc`
- `android_device_samsung_expressltexx/system_prop.mk`
- `android_device_samsung_expressltexx/proprietary-files.txt`
- `android_device_samsung_msm8930-common/BoardConfigCommon.mk`

Relevant Android facts:

- Kernel cmdline used downstream includes `androidboot.bootdevice=msm_sdcc.1`.
- Boot image base is `0x80200000`, page size is `2048`, ramdisk offset is `0x02000000`.
- Downstream Android expects eMMC at `/dev/block/platform/msm_sdcc.1/by-name/...` and external SD at `msm_sdcc.3`.
- Wi-Fi is Qualcomm WCNSS/Prima, exposed as `qcwcn` / `wlan` downstream.
- Bluetooth transport is Qualcomm SMD.

## Known Hardware Clues

- Buttons: volume up, volume down, and home are in `express-gpio.h` and `board-express.c`.
- Touchscreen: Atmel maXTouch, downstream `CONFIG_TOUCHSCREEN_MXT224S`.
- Touchkeys: Cypress touchkey, downstream `CONFIG_KEYBOARD_CYPRESS_TOUCH`.
- Display panel: downstream `CONFIG_FB_MSM_MIPI_MAGNA_OLED_VIDEO_WVGA_PT_PANEL`, see `drivers/video/msm/mipi_magna_oled*`.
- PMIC/charger/fuel: PM8921/PM8917 paths, `pm8921-sec-charger.c`, `pm8921-bms.c`, and `bms-batterydata-express.c`.
- NFC: PN547 at downstream I2C address `0x2b`.
- USB switch/MUIC: TSU6721.
- Audio codec: WCD9304.
- Cameras enabled in downstream express defconfig include `MT9M114`, `OV2720`, `ISX012`, and `SR130PC20`.

## Config Oddities

Base downstream defconfig is `samsung_express_defconfig`.

Variant downstream defconfig is `msm8930_express_eur_lte_defconfig`.

`msm8930_express_eur_lte_defconfig` contains `CONFIG_MACH_EXPRESS_ATT=y`, but that symbol is not defined in downstream `Kconfig`. Do not over-interpret that name.

`board-express.c` uses some `express2` symbol names and `MACHINE_START(EXPRESS2, "SAMSUNG EXPRESS2")`. Treat this as downstream naming drift, not proof that GT-I8730 is the separate Express 2 product.

## Agent Guidelines

Prefer small, testable mainline changes. For early bring-up, prioritize UART, memory, timer/interrupts, and a panic/log path before adding peripherals.

When extracting hardware data from downstream, cite the exact source file and line range in notes or commit messages. Avoid copying downstream code structure into mainline; translate board-file facts into devicetree and existing mainline bindings.

Do not assume `samsung-expressatt` and `samsung-expressltexx` are electrically identical. Use expressatt only to understand what a nearby Samsung Qualcomm board looks like in mainline.

Do not run destructive flashing commands or overwrite boot/recovery partitions without explicit user approval and a clear recovery path.
