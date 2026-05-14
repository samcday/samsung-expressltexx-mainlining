# Research Breadcrumbs

Keep this file as a source-trace index for bring-up decisions. Record non-obvious registers, offsets, bit values, derived clocks, boot-image layout values, GPIOs, regulator facts, and similar magic constants here with exact source paths and line ranges.

## Platform Identity / MSM8930 vs MSM8960 Naming

Values currently used:

- Android device makefiles use MSM8960-era platform naming: `TARGET_BOARD_PLATFORM := msm8960` and `TARGET_BOOTLOADER_BOARD_NAME := MSM8960`.
- The downstream kernel tree/configs identify the Express board as MSM8930-family: `TARGET_KERNEL_SOURCE := kernel/samsung/msm8930-common`, `CONFIG_ARCH_MSM8930=y`, and `CONFIG_MACH_EXPRESS=y`.
- The old board file mixes MSM8930 init paths with some MSM8960-named shared platform devices. Treat those names as shared Qualcomm 3.4 code, not proof that GT-I8730 is electrically an MSM8960/Express ATT board.
- New Linux DT work should model this board as `qcom,msm8930` and only import MSM8960-era addresses, clocks, GPIOs, or peripherals when each value is source-backed and/or hardware-tested.

Sources:

- `android_device_samsung_msm8930-common/BoardConfigCommon.mk:24-26` sets `TARGET_BOARD_PLATFORM := msm8960` while living under `msm8930-common`.
- `android_device_samsung_expressltexx/BoardConfig.mk:33-45` selects `kernel/samsung/msm8930-common`, `samsung_express_defconfig`, `msm8930_express_eur_lte_defconfig`, and `TARGET_BOOTLOADER_BOARD_NAME := MSM8960`.
- `android_kernel_samsung_msm8930-common/arch/arm/configs/samsung_express_defconfig:45-49` enables `CONFIG_ARCH_MSM`, `CONFIG_ARCH_MSM8960`, `CONFIG_ARCH_MSM8930`, and `CONFIG_MACH_EXPRESS` together.
- `android_kernel_samsung_msm8930-common/arch/arm/configs/msm8930_express_eur_lte_defconfig:1-3` contains the stray `CONFIG_MACH_EXPRESS_ATT=y` variant overlay; do not treat that alone as an Express ATT hardware match.
- `android_kernel_samsung_msm8930-common/arch/arm/mach-msm/board-express.c:3836-3858` shows MSM8930 clock/gpiomux/I2C/GPU init alongside MSM8960-named OTG/SPI/PMIC shared code.
- `android_kernel_samsung_msm8930-common/arch/arm/mach-msm/board-express.c:3954-3963` uses `MACHINE_START(EXPRESS2, "SAMSUNG EXPRESS2")` with MSM8930 map/reserve/IRQ/init paths; treat this as downstream naming drift.

Current use:

- `linux/arch/arm/boot/dts/qcom/qcom-msm8930-samsung-expressltexx.dts:1-7` now includes `qcom-msm8930.dtsi` and advertises `compatible = "samsung,expressltexx", "qcom,msm8930"`.
- `u-boot/dts/upstream/src/arm/qcom/qcom-msm8960-samsung-expressltexx.dts:1-8` still includes `qcom-msm8960.dtsi` and advertises `qcom,msm8960`; treat this as an early bring-up shortcut that needs auditing against MSM8930-specific facts before adding more peripherals.

Notes:

- Existing U-Boot timer/UART values below were individually source-backed and have reached a UART prompt, but future U-Boot work should not inherit additional MSM8960 nodes or Express ATT facts without a matching breadcrumb.

## MSM8930 HSUSB / UDC

Values currently used:

- HSUSB controller base is `0x12500000`; downstream names it `MSM8960_HSUSB_PHYS` but uses it from the Express/MSM8930 board path.
- Downstream resource size is `SZ_4K`. Mainline currently follows the existing MSM8960 ChipIdea DT shape with two `0x200` register windows at `0x12500000` and `0x12500200`.
- USB1 HS interrupt is `USB1_HS_IRQ = GIC_SPI_START + 100`, represented in DT as `interrupts = <GIC_SPI 100 IRQ_TYPE_LEVEL_HIGH>`.
- Mainline USB clocks/resets currently use the existing MSM8960 GCC IDs: `USB_HS1_XCVR_CLK = 128`, `USB_HS1_H_CLK = 126`, and `USB_HS1_RESET = 64`.
- HSUSB PHY uses the 28 nm integrated ULPI PHY path. Mainline represents this with `qcom,usb-hs-phy-msm8960`, `phy_type = "ulpi"`, and a 60 MHz `USB_HS1_XCVR_CLK` assignment.
- Express downstream PHY init sequence is `0x44 0x80, 0x5f 0x81, 0x3c 0x82, 0x13 0x83`, with downstream comments describing VBUS/disconnect thresholds, DC voltage level, preemphasis/rise/fall, and source impedance adjustment.
- Current Linux test mode is peripheral-only: `dr_mode = "peripheral"`.

Sources:

- `android_kernel_samsung_msm8930-common/arch/arm/mach-msm/devices-8960.c:104-105` defines `MSM8960_HSUSB_PHYS = 0x12500000` and `MSM8960_HSUSB_SIZE = SZ_4K`.
- `android_kernel_samsung_msm8930-common/arch/arm/mach-msm/devices-8960.c:126-195` wires the same HSUSB memory resource and `USB1_HS_IRQ` into downstream OTG, gadget peripheral, and host platform devices.
- `android_kernel_samsung_msm8930-common/arch/arm/mach-msm/include/mach/irqs-8930.h:138-145` defines `USB1_HS_IRQ` as `GIC_SPI_START + 100` for MSM8930.
- `android_kernel_samsung_msm8930-common/arch/arm/mach-msm/board-express.c:2382-2397` defines the Express `hsusb_phy_init_seq`, sets `.mode = USB_OTG`, and selects `SNPS_28NM_INTEGRATED_PHY`.
- `android_kernel_samsung_msm8930-common/arch/arm/mach-msm/board-express.c:3269-3273` registers downstream OTG, gadget, host, and Android USB devices for Express.
- `android_kernel_samsung_msm8930-common/arch/arm/mach-msm/board-express.c:3837-3838` assigns `hsusb_phy_init_seq` to `msm_otg_pdata` and attaches that pdata to the MSM8960-named OTG device.
- `linux/arch/arm/boot/dts/qcom/qcom-msm8960.dtsi:505-533` is the nearest mainline ChipIdea/ULPI DT shape reused for the MSM8930 bring-up node after checking downstream base/IRQ facts.
- `linux/include/dt-bindings/clock/qcom,gcc-msm8960.h:130-139` defines `USB_HS1_H_CLK` and `USB_HS1_XCVR_CLK` IDs currently reused by the MSM8930 GCC-compatible path.
- `linux/include/dt-bindings/reset/qcom,gcc-msm8960.h:69-76` defines `USB_HS1_RESET` ID currently reused by the MSM8930 GCC-compatible path.

Current use:

- `linux/arch/arm/boot/dts/qcom/qcom-msm8930.dtsi:219-249` adds disabled `usb1: usb@12500000` and nested ULPI `usb_hs1_phy` nodes.
- `linux/arch/arm/boot/dts/qcom/qcom-msm8930-samsung-expressltexx.dts:45-57` enables `usb1` in peripheral mode and supplies the Express PHY init sequence.

Notes:

- This is a first UDC bring-up pass. It does not yet model the TSU6721 MUIC, USB extcon/VBUS handling, host mode, or USB PHY regulators.
- Hardware validation is still pending. The minimal BusyBox initramfs should make `/sys/class/udc`, `/sys/kernel/config`, and `dmesg` inspection possible without postmarketOS initrd policy interfering.

## MSM8960 Timer / DGT

Values currently used:

- `MSM8960_TMR_BASE = 0x0200a000`
- `MSM8960_TMR0_BASE = 0x0208a000`
- DGT local regbase is `MSM_TMR_BASE + 0x24`, so CPU0 DGT regbase is `0x0208a024`.
- DGT count register is `DGT_BASE + TIMER_COUNT_VAL`, so U-Boot counter is `0x0208a028`.
- DGT enable register is `DGT_BASE + TIMER_ENABLE`, so U-Boot enables `0x0208a02c`.
- DGT clock control is `MSM8960_TMR_BASE + DGT_CLK_CTL`, so U-Boot writes `0x0200a034`.
- MSM8960 DGT rate is `6750000` Hz, from downstream `dgt->freq = 6750000` after selecting `DGT_CLK_CTL_DIV_4`. Mainline DT also describes a `27000000` Hz timer clock and `cpu-offset = <0x80000>`.

Sources:

- `android_kernel_samsung_msm8930-common/arch/arm/mach-msm/include/mach/msm_iomap-8960.h:35-39` defines `MSM8960_TMR_PHYS` and `MSM8960_TMR0_PHYS`.
- `android_kernel_samsung_msm8930-common/arch/arm/mach-msm/timer.c:61-74` defines `TIMER_COUNT_VAL`, `TIMER_ENABLE`, `DGT_CLK_CTL`, `DGT_CLK_CTL_DIV_4`, and `TIMER_ENABLE_EN`.
- `android_kernel_samsung_msm8930-common/arch/arm/mach-msm/timer.c:173-190` sets DGT `regbase = MSM_TMR_BASE + 0x24`.
- `android_kernel_samsung_msm8930-common/arch/arm/mach-msm/timer.c:210-218` reads timer count from `clock->regbase + TIMER_COUNT_VAL + global * global_timer_offset`.
- `android_kernel_samsung_msm8930-common/arch/arm/mach-msm/timer.c:1065-1069` handles MSM8960/MSM8930, sets `global_timer_offset`, `dgt->freq = 6750000`, and writes `DGT_CLK_CTL_DIV_4`.
- `u-boot/dts/upstream/src/arm/qcom/qcom-msm8960.dtsi:334-345` describes `timer@200a000`, `clock-frequency = <27000000>`, and `cpu-offset = <0x80000>`.

Current use:

- `u-boot/arch/arm/mach-snapdragon/timer.c:9-22` initializes the MSM8960 DGT for ARM32 Snapdragon bring-up.
- `u-boot/include/configs/qcom.h:14-17` exposes `CFG_SYS_TIMER_RATE = 6750000` and `CFG_SYS_TIMER_COUNTER = 0x0208a028`.

Notes:

- This is a minimal early U-Boot timer hook, not a full Qualcomm timer driver.
- The timer base and rate are source-backed, but runtime behavior should still be verified against UART timing and delay behavior on hardware.

## UARTDM v1.3 / GSBI5

Values currently used:

- GSBI5 base is `0x16400000`.
- GSBI5 UARTDM base is `0x16440000`.
- GSBI5 UART uses `qcom,msm-uartdm-v1.3`.
- GSBI mode for I2C plus UART is `GSBI_PROT_I2C_UART = 6`.
- GSBI control register writes mode as `qcom,mode << 4` at GSBI base offset `0x0`, so GSBI5 I2C+UART mode is `0x60` at `0x16400000`.
- UARTDM v1.3 key offsets used by U-Boot: `CSR/SR = 0x08`, `CR = 0x10`, `IPR = 0x18`, `TFWR = 0x1c`, `RFWR = 0x20`, `DMRX = 0x34`, `DMEN = 0x3c`, `NCF_TX = 0x40`, `RXFS = 0x50`, `TF/RF = 0x70`.
- MSM8960 UARTDM CSR value for 115200 baud is `0xff`.

Sources:

- `u-boot/dts/upstream/src/arm/qcom/qcom-msm8960.dtsi:642-666` describes GSBI5 and its UARTDM v1.3 child with both UART and GSBI register ranges.
- `u-boot/dts/upstream/include/dt-bindings/soc/qcom,gsbi.h:7-13` defines `GSBI_PROT_I2C_UART = 6`.
- `linux/drivers/soc/qcom/qcom_gsbi.c:17-19` defines GSBI control offset `0x0` and protocol shift `4`.
- `linux/drivers/soc/qcom/qcom_gsbi.c:171-186` reads `qcom,mode` and writes `(mode << GSBI_PROTOCOL_SHIFT) | crci`.
- `lk2nd/platform/msm_shared/include/uart_dm.h:75-93` gives v1.3 CSR, TF, and CR offsets when not using BLSP.
- `lk2nd/platform/msm_shared/include/uart_dm.h:161-183` gives IPR, TFWR, RFWR, DMRX, and default DMRX value.
- `lk2nd/platform/msm_shared/include/uart_dm.h:191-204` gives DMEN, NCF_TX, and SR offsets.
- `lk2nd/platform/msm_shared/include/uart_dm.h:216-220` gives v1.3 RF offset `0x70`.
- `lk2nd/platform/msm_shared/include/uart_dm.h:230-241` gives ISR and RX_TOTAL_SNAP offsets.
- `lk2nd/platform/msm_shared/include/uart_dm.h:251-256` gives RXFS offset and field extraction helpers.
- `lk2nd/platform/msm8960/include/platform/clock.h:33` defines `UART_DM_CLK_RX_TX_BIT_RATE = 0xFF` for MSM8960.
- `android_kernel_samsung_msm8930-common/drivers/tty/serial/msm_serial_hs_hwreg.h:139-155` defines UARTDM command values including stale/reset/force-stale/TX-ready commands.
- `android_kernel_samsung_msm8930-common/drivers/tty/serial/msm_serial_hs_hwreg.h:190-205` defines stale/RXLEV/RXSTALE/DMEN bit fields.
- `linux/drivers/tty/serial/msm_serial.c:1168-1186` shows Linux UARTDM setup for RX/TX, IMR, stale reset, DMRX, and stale enable.
- `linux/drivers/tty/serial/msm_serial.c:1446-1494` shows Linux poll get-char logic forcing stale and unpacking a word-sized UARTDM RF read.
- `lk2nd/platform/msm_shared/uart_dm.c:159-224` shows lk2nd UARTDM init, watermarks, stale timeout, resets, DMEN, RX/TX enable, and RX transfer setup.

Current use:

- `u-boot/dts/upstream/src/arm/qcom/qcom-msm8960-samsung-expressltexx.dts:25-33` enables GSBI5, sets `GSBI_PROT_I2C_UART`, and supplies `clock-frequency = <7372800>` for the UART.
- `u-boot/drivers/serial/serial_msm.c:78-91` defines the UARTDM v1.3 offset table.
- `u-boot/drivers/serial/serial_msm.c:114-129` resets stale state and flushes partial RX bytes.
- `u-boot/drivers/serial/serial_msm.c:274-294` initializes bitrate, watermarks, stale timeout, DMEN, RX/TX reset, and RX/TX enable.

Notes:

- UART TX was validated by reaching a U-Boot prompt over UART.
- UART RX initially worked but dropped most repeated keystrokes. The current RX handling follows Linux/lk2nd more closely but should still be validated on hardware.

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

## Initial RAM For U-Boot Bring-Up

Values currently used:

- Conservative first RAM bank: `reg = <0x80000000 0x20000000>`.
- This exposes 512 MiB to U-Boot during initial bring-up.

Sources:

- `u-boot/dts/upstream/src/arm/qcom/qcom-msm8960.dtsi:79-82` has the generic MSM8960 `memory@80000000` node with zero size.
- `u-boot/dts/upstream/src/arm/qcom/qcom-msm8960-samsung-expressltexx.dts:20-22` overrides that with the conservative 512 MiB bank.

Current use:

- U-Boot reports `DRAM: 512 MiB` on hardware with this DT.

Notes:

- This is intentionally conservative until a robust previous-bootloader FDT/memory map path is implemented for ARM32 Snapdragon.
