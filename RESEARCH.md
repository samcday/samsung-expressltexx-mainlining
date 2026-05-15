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

- `linux/arch/arm/boot/dts/qcom/qcom-msm8930-samsung-expressltexx.dts:1-10` now includes `qcom-msm8930.dtsi` and advertises `compatible = "samsung,expressltexx", "qcom,msm8930"`.
- `u-boot/dts/upstream/src/arm/qcom/qcom-msm8960-samsung-expressltexx.dts:1-8` still includes `qcom-msm8960.dtsi` and advertises `qcom,msm8960`; treat this as an early bring-up shortcut that needs auditing against MSM8930-specific facts before adding more peripherals.

Notes:

- Existing U-Boot timer/UART values below were individually source-backed and have reached a UART prompt, but future U-Boot work should not inherit additional MSM8960 nodes or Express ATT facts without a matching breadcrumb.

## MSM8960 GCC Board Clock Compatibility

Values currently used:

- MSM8930 bring-up currently uses the mainline `qcom,gcc-msm8960` driver and binding IDs while MSM8930-specific GCC support is not split out.
- The fixed clock nodes under `/clocks` intentionally use legacy underscore node names `cxo_board`, `pxo_board`, and `sleep_clk`. This is not style drift: `qcom_cc_register_board_clk()` looks up exact `/clocks/<path>` child names before deciding whether to register fallback clocks.
- `cxo_board` is `19200000` Hz and `pxo_board` is `27000000` Hz, matching the fallback rates registered by `gcc-msm8960`.
- If these node names are changed to hyphenated names, `gcc-msm8960` attempts to register duplicate `cxo_board`/`pxo_board` clocks and fails before GSBI/USB suppliers can probe.

Sources:

- `linux/drivers/clk/qcom/common.c:147-184` documents and implements the legacy `/clocks/<path>` lookup before fallback board-clock registration.
- `linux/drivers/clk/qcom/gcc-msm8960.c:3716-3729` registers fallback `cxo_board` and `pxo_board` clocks at `19200000` and `27000000` Hz.
- `linux/arch/arm/boot/dts/qcom/qcom-msm8960.dtsi:15-37` uses the same underscore node names for `cxo_board`, `pxo_board`, and `sleep_clk`.
- `boot.log:224-227` captured the failure mode: `gcc-msm8960` failed to register duplicate `cxo_board`, which left `900000.clock-controller` unavailable.
- `boot.log:398-401` captured the downstream effect: GSBI and USB deferred forever because their `900000.clock-controller` supplier was not ready.

Current use:

- `linux/arch/arm/boot/dts/qcom/qcom-msm8930.dtsi:15-35` defines `cxo_board`, `pxo_board`, and `sleep_clk` with the exact legacy node names expected by the current GCC compatibility path.

Notes:

- This is a temporary compatibility detail of the current MSM8930 bring-up. Revisit it if a dedicated MSM8930 GCC driver/binding is added.

## MSM8930 RPM / PM8917 Regulators

Values currently used:

- The MSM8930 RPM message RAM base is `0x00108000`, exposed in DT as `rpm@108000` with a `0x1000` register range. The RPM driver uses status at base, control at base `+ 0x400`, and request memory at base `+ 0x600`; downstream also lists ACK memory at base `+ 0xa00`.
- RPM interrupts use GIC SPI 19 for ACK, SPI 21 for ERR, and SPI 22 for wakeup. The outgoing IPC vote uses the APCS/L2CC syscon register offset `0x8` and bit 2, matching downstream `ipc_rpm_val = 4`.
- Mainline uses `qcom,rpm-msm8930` with a minimal resource table for the regulator rails needed by current bring-up. Do not reuse the MSM8960 PM8921 table for these rails: downstream MSM8930 PM8917/PM8038 target/status IDs differ from mainline MSM8960 PM8921 IDs.
- The Express DT currently models PM8917 rails. Downstream Express code switches to PM8917 RPM data when `socinfo_get_pmic_model() == PMIC_MODEL_PM8917`, and the downstream peripheral inventory overwhelmingly uses `8917_*` regulator names for later board revisions.
- PM8917 rails currently modeled are S4, L3, L4, and L5. L3 supplies HSUSB 3.3 V at `3075000` uV, L4 supplies HSUSB 1.8 V at `1800000` uV, L5 supplies SDCC1 `sdc_vdd` at `2950000` uV, and S4 supplies SDCC1 `sdc_vdd_io` at `1800000` uV.
- Minimal PM8038 S4/L3/L4/L5/L11 regulator data is also present in the driver because downstream supports the PM8038 alternate path and maps SDCC1 `sdc_vdd_io` to PM8038 L11, not S4.
- MSM8930 PM8917/PM8038 regulator request formats and voltage ranges match the existing mainline RPM 8960 SMPS/PLDO templates used by PM8921.

Sources:

- `android_kernel_samsung_msm8930-common/arch/arm/mach-msm/include/mach/msm_iomap-8930.h:41-42` defines `MSM8930_RPM_PHYS = 0x00108000` and `MSM8930_RPM_SIZE = SZ_4K`.
- `android_kernel_samsung_msm8930-common/arch/arm/mach-msm/devices-8930.c:79-90` defines the PM8038 RPM page offsets, interrupts, and IPC register/value; `devices-8930.c:293-304` defines the same base/interrupt/IPC facts for the PM8917 path.
- `android_kernel_samsung_msm8930-common/arch/arm/mach-msm/board-express.c:3739-3763` switches Express platform data to PM8917 RPM regulators when PM8917 is detected; `board-express.c:3808-3825` selects PM8038 or PM8917 RPM init by `socinfo_get_pmic_model()`.
- `android_kernel_samsung_msm8930-common/arch/arm/mach-msm/include/mach/rpm-8930.h:63-75` defines PM8038 S4/L3/L4/L5/L11 selector IDs; `rpm-8930.h:228-255` defines their request target IDs; `rpm-8930.h:443-472` defines their status IDs.
- `android_kernel_samsung_msm8930-common/arch/arm/mach-msm/include/mach/rpm-8930.h:102-115` defines PM8917 S4/L3/L4/L5 selector IDs; `rpm-8930.h:310-329` defines their request target IDs; `rpm-8930.h:523-548` defines their status IDs.
- `android_kernel_samsung_msm8930-common/arch/arm/mach-msm/rpm-regulator-8930.c:19-42` defines MSM8930 RPM LDO/SMPS request bit layouts; `rpm-regulator-8930.c:58-83` defines PLDO and SMPS voltage ranges matching the mainline RPM 8960 templates.
- `android_kernel_samsung_msm8930-common/arch/arm/mach-msm/board-8930-regulator-pm8917.c:46-58` maps PM8917 L3/L4/L5 to `HSUSB_3p3`, `HSUSB_1p8`, and SDCC1 `sdc_vdd`; `board-8930-regulator-pm8917.c:205-218` maps S4 to SDCC1 `sdc_vdd_io`; `board-8930-regulator-pm8917.c:696-711` gives S4/L3/L4/L5 voltages and always-on flags.
- `android_kernel_samsung_msm8930-common/arch/arm/mach-msm/board-8930-regulator-pm8038.c:43-55` maps PM8038 L3/L4/L5 to `HSUSB_3p3`, `HSUSB_1p8`, and SDCC1 `sdc_vdd`; `board-8930-regulator-pm8038.c:101-107` maps L11 to SDCC1 `sdc_vdd_io`; `board-8930-regulator-pm8038.c:519-538` gives S4/L3/L4/L5/L11 voltages and always-on flags.
- `android_kernel_samsung_msm8930-common/arch/arm/mach-msm/board-8930-storage.c:42-82` independently records SDCC1 `sdc_vdd = 2950000` uV and `sdc_vdd_io = 1800000` uV as always-on eMMC supplies.

Current use:

- `linux/include/dt-bindings/mfd/qcom-rpm.h:173-181` assigns mainline resource IDs for the minimal PM8038/PM8917 MSM8930 RPM rails.
- `linux/drivers/mfd/qcom_rpm.c:341-365` adds the MSM8930 RPM resource table and template; `qcom_rpm.c:465` matches `qcom,rpm-msm8930`.
- `linux/drivers/regulator/qcom_rpm-regulator.c:918-950` adds minimal `qcom,rpm-pm8038-regulators` and `qcom,rpm-pm8917-regulators` support.
- `linux/arch/arm/boot/dts/qcom/qcom-msm8930.dtsi:87-96` adds the MSM8930 RPM node.
- `linux/arch/arm/boot/dts/qcom/qcom-msm8930-samsung-expressltexx.dts:93-128` declares the PM8917 S4/L3/L4/L5 regulators; `qcom-msm8930-samsung-expressltexx.dts:130-136` wires SDCC1 to L5/S4; `qcom-msm8930-samsung-expressltexx.dts:202-204` wires the USB PHY to L4/L3.
- `build-lk2nd-bootable.sh:101` and `build-lk2nd-userdata.sh:113-114` no longer pass `regulator_ignore_unused` by default.

Notes:

- The PMIC variant still should be verified from hardware logs when possible. If a tested GT-I8730 reports PM8038 instead of PM8917, the board DTS should switch the regulator node compatible/phandles to the PM8038 rails above.
- This is intentionally a minimal early bring-up RPM/regulator model. It covers UART-independent RPM access plus the USB/eMMC rails needed to remove `regulator_ignore_unused`, not the complete PM8917/PM8038 regulator set.

## MSM8930 HSUSB / UDC

Values currently used:

- HSUSB controller base is `0x12500000`; downstream names it `MSM8960_HSUSB_PHYS` but uses it from the Express/MSM8930 board path.
- Downstream resource size is `SZ_4K`. Mainline currently follows the existing MSM8960 ChipIdea DT shape with two `0x200` register windows at `0x12500000` and `0x12500200`.
- USB1 HS interrupt is `USB1_HS_IRQ = GIC_SPI_START + 100`, represented in DT as `interrupts = <GIC_SPI 100 IRQ_TYPE_LEVEL_HIGH>`.
- Mainline USB clocks/resets currently use the existing MSM8960 GCC IDs: `USB_HS1_XCVR_CLK = 128`, `USB_HS1_H_CLK = 126`, and `USB_HS1_RESET = 64`.
- HSUSB PHY uses the 28 nm integrated ULPI PHY path. Mainline represents this with `qcom,usb-hs-phy-msm8960`, `phy_type = "ulpi"`, and a 60 MHz `USB_HS1_XCVR_CLK` assignment.
- USB PHY supplies are now modeled through RPM regulators: PM8917 L4 for `v1p8 = 1800000` uV and PM8917 L3 for `v3p3 = 3075000` uV. Downstream maps HSUSB 1.8 V to PM8917/PM8038 L4 and HSUSB 3.3 V to L3; both downstream regulator files program L4 to 1.8 V and L3 to 3.075 V.
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
- `android_kernel_samsung_msm8930-common/arch/arm/mach-msm/board-8930-regulator-pm8917.c:46-53` maps `HSUSB_3p3` to L3 and `HSUSB_1p8` to L4 for `msm_otg`.
- `android_kernel_samsung_msm8930-common/arch/arm/mach-msm/board-8930-regulator-pm8917.c:706-710` programs PM8917 L3 to `3075000` uV and L4 to `1800000` uV.
- `android_kernel_samsung_msm8930-common/arch/arm/mach-msm/board-8930-regulator-pm8038.c:43-50` maps `HSUSB_3p3` to L3 and `HSUSB_1p8` to L4 for `msm_otg`.
- `android_kernel_samsung_msm8930-common/arch/arm/mach-msm/board-8930-regulator-pm8038.c:527-531` programs PM8038 L3 to `3075000` uV and L4 to `1800000` uV.
- `linux/drivers/phy/qualcomm/phy-qcom-usb-hs.c:131-132` first asks the `v3p3` regulator for exactly `3300000` uV, then `linux/include/linux/regulator/consumer.h:717-724` falls back to the wider `3050000..3300000` uV range if that target request fails.

Current use:

- `linux/arch/arm/boot/dts/qcom/qcom-msm8930.dtsi:257-287` adds disabled `usb1: usb@12500000` and nested ULPI `usb_hs1_phy` nodes.
- `linux/arch/arm/boot/dts/qcom/qcom-msm8930-samsung-expressltexx.dts:106-118` defines the PM8917 L3/L4 USB PHY supply regulators.
- `linux/arch/arm/boot/dts/qcom/qcom-msm8930-samsung-expressltexx.dts:197-212` enables `usb1` in peripheral mode, attaches the PM8917 PHY supplies, and supplies the Express PHY init sequence.

Notes:

- This is a first UDC bring-up pass. It does not yet model the TSU6721 MUIC, USB extcon/VBUS handling, or host mode.
- The previous fixed USB PHY supplies were a temporary bring-up workaround for a `phy poweron failed --> -22` error seen when the gadget bound and the PHY driver tried to set voltage on dummy regulators.
- A boot-time `l3: voltage operation not allowed` warning can come from the PHY driver's first exact-`3300000` uV request. Do not widen the Express PM8917 L3 DT constraint just to suppress that warning unless hardware evidence supports 3.3 V operation; downstream fixes L3 at `3075000` uV and the generic PHY helper has a wider fallback range.

## Minimal Initramfs CDC-ACM Gadget

Values currently used:

- The local test initramfs creates a configfs gadget at `/sys/kernel/config/usb_gadget/g1` with one `functions/acm.usb0` CDC-ACM function and binds it to the first UDC found under `/sys/class/udc`.
- Test USB IDs are `idVendor = 0x1d6b` and `idProduct = 0x0104`, identifying Linux Foundation's Multifunction Composite Gadget rather than pretending to be a Samsung production USB ID.
- USB descriptor versions are `bcdUSB = 0x0200` and `bcdDevice = 0x0100` for a simple USB 2.0 test gadget.
- The configuration is bus-powered with `bmAttributes = 0x80` and `MaxPower = 100`.
- The initramfs starts `getty -L -n -l /bin/sh 115200 ttyGS0 vt100` after `/dev/ttyGS0` appears, while keeping the UART shell on `/dev/ttyMSM0` for recovery.
- The initramfs is built from one static ARMv7 BusyBox binary. The default source is `https://busybox.net/downloads/binaries/1.31.0-defconfig-multiarch-musl/busybox-armv7l`, pinned by SHA256 `cd04052b8b6885f75f50b2a280bfcbf849d8710c8e61d369c533acf307eda064`.

Sources:

- `linux/Documentation/usb/gadget_configfs.rst:60-81` documents creating a gadget directory and writing `idVendor`/`idProduct` plus strings.
- `linux/Documentation/usb/gadget_configfs.rst:103-131` documents creating configs, config strings, and `MaxPower`.
- `linux/Documentation/usb/gadget_configfs.rst:133-168` documents creating functions and linking them into configs.
- `linux/Documentation/usb/gadget_configfs.rst:213-223` documents binding the gadget by writing a UDC name from `/sys/class/udc` into `UDC`.
- `linux/Documentation/usb/gadget-testing.rst:33-48` documents the ACM configfs function name `acm` and resulting serial function.
- `linux/Documentation/usb/gadget_serial.rst:131-145` documents the resulting `/dev/ttyGS0` node and running getty on it.
- `linux/drivers/usb/gadget/Kconfig:249-257` defines `CONFIG_USB_CONFIGFS_ACM` and selects `USB_U_SERIAL` plus `USB_F_ACM`.
- `/usr/share/hwdata/usb.ids:20954-20962` maps `1d6b:0104` to Linux Foundation Multifunction Composite Gadget.
- `https://busybox.net/downloads/binaries/1.31.0-defconfig-multiarch-musl/busybox-armv7l.log` records the default BusyBox binary as a static `armv7l-linux-musleabihf` build with the required shell, mount, mknod, stty, getty, and symlink applets enabled.

Current use:

- `build-dev-initrd.sh:80-113` sets the default BusyBox URL/checksum, downloads the binary if needed, and verifies it before packaging.
- `build-dev-initrd.sh:177-245` creates `/dev/ttyGS0` if needed, configures the CDC-ACM gadget, binds the first UDC, and starts the USB serial shell.
- `build-dev-initrd.sh:295-324` includes BusyBox applet links required by the gadget setup and storage-debug shell.
- `build-lk2nd-userdata.sh:216-237` and `build-lk2nd-bootable.sh:185-202` enable the kernel config options needed by local bring-up images, including `CONFIG_USB_CONFIGFS_ACM`.

Notes:

- This is intentionally test-initramfs policy, not board DT. It should not be carried into an upstream DTS submission.
- If the UART resistor cable is attached, the connector may be routed to UART instead of USB data; CDC-ACM enumeration should be tested with the normal USB path when possible.

## MSM8930 SDCC1 / eMMC

Values currently used:

- SDCC1 is the internal non-removable eMMC controller. Android refers to the boot device as `msm_sdcc.1`.
- SDCC1 core base is `0x12400000`; the DML block starts at `0x12400800`; the BAM block starts at `0x12402000`.
- The mainline PL18x node maps `0x12400000..0x12401fff`, matching the existing MSM8960 mainline shape so the Qualcomm DML registers at offset `0x800` are included.
- SDCC1 host IRQ is `GIC_SPI 104`; SDCC1 BAM IRQ is `GIC_SPI 98`.
- SDCC1 uses the existing MSM8960 GCC-compatible IDs `SDC1_CLK`, `SDC1_H_CLK`, and `SDC1_RESET` while MSM8930-specific GCC support is not split out.
- The downstream Express storage table supports SDCC1 clock rates `400000`, `24000000`, `48000000`, and `96000000`; the DT caps `max-frequency` at `96000000` for the first pass.
- Downstream Express enables `CONFIG_MMC_MSM_SDC1_8_BIT_SUPPORT`, so DT sets `bus-width = <8>`.
- SDCC1 eMMC supplies are now modeled through RPM regulators: PM8917 L5 for `vmmc = 2950000` uV and PM8917 S4 for `vqmmc = 1800000` uV, matching downstream SDCC1 `sdc_vdd` and `sdc_vdd_io` regulator voltage requests.
- SDCC1 pad drive matches downstream active/sleep values: active CLK 16 mA, CMD/DATA 10 mA; sleep CLK/CMD/DATA 2 mA. CLK is no-pull; CMD/DATA are pull-up.

Sources:

- `android_device_samsung_expressltexx/rootdir/fstab.qcom:6-16` uses `/dev/block/platform/msm_sdcc.1/by-name/...` for internal eMMC partitions.
- `android_kernel_samsung_msm8930-common/arch/arm/mach-msm/devices-8960.c:1107-1115` defines SDCC1 base, DML base, BAM base, and nearby SDCC base addresses.
- `android_kernel_samsung_msm8930-common/arch/arm/mach-msm/devices-8960.c:1123-1155` wires SDCC1 core memory, core IRQ, DML memory, BAM memory, and BAM IRQ resources.
- `android_kernel_samsung_msm8930-common/arch/arm/mach-msm/include/mach/irqs-8930.h:141-147` defines `SDC1_BAM_IRQ = GIC_SPI_START + 98` and `SDC1_IRQ_0 = GIC_SPI_START + 104`.
- `android_kernel_samsung_msm8930-common/arch/arm/mach-msm/board-8930-storage.c:42-52` defines SDCC1 `sdc_vdd` as fixed 2.95 V and always-on.
- `android_kernel_samsung_msm8930-common/arch/arm/mach-msm/board-8930-storage.c:73-82` defines SDCC1 `sdc_vdd_io` as fixed 1.8 V and always-on.
- `android_kernel_samsung_msm8930-common/arch/arm/mach-msm/board-8930-regulator-pm8917.c:55-58` maps PM8917 L5 to SDCC1 `sdc_vdd`; `board-8930-regulator-pm8917.c:214-218` maps PM8917 S4 to SDCC1 `sdc_vdd_io`.
- `android_kernel_samsung_msm8930-common/arch/arm/mach-msm/board-8930-storage.c:114-137` defines SDCC1 active/sleep pad drive and pull settings.
- `android_kernel_samsung_msm8930-common/arch/arm/mach-msm/board-8930-storage.c:223-250` defines SDCC1 clock rates, non-removable eMMC, 8-bit conditional support, bus voting, and HS200/DDR capabilities.
- `android_kernel_samsung_msm8930-common/arch/arm/mach-msm/board-8930-storage.c:294-309` registers SDCC1 for Express/MSM8930.
- `android_kernel_samsung_msm8930-common/arch/arm/configs/samsung_express_defconfig:539` enables downstream 8-bit SDCC1 support.
- `linux/arch/arm/boot/dts/qcom/qcom-msm8960.dtsi:446-472` is the nearest mainline PL18x/DML/BAM DT shape reused for SDCC1 after checking downstream base and IRQ facts.
- `linux/include/dt-bindings/clock/qcom,gcc-msm8960.h:118-128` defines the SDC1 clock IDs currently reused by the MSM8930 GCC-compatible path.
- `linux/include/dt-bindings/reset/qcom,gcc-msm8960.h:67-71` defines the SDCC reset IDs currently reused by the MSM8930 GCC-compatible path.
- `linux/drivers/mmc/host/mmci_qcom_dml.c:48-51` uses DML at host base offset `0x800`, explaining why the PL18x `reg` window includes both the core and DML ranges.

Current use:

- `linux/arch/arm/boot/dts/qcom/qcom-msm8930.dtsi:199-224` adds disabled SDCC1 and SDCC1 BAM nodes.
- `linux/arch/arm/boot/dts/qcom/qcom-msm8930-samsung-expressltexx.dts:97-126` defines the PM8917 S4/L5 eMMC supply regulators.
- `linux/arch/arm/boot/dts/qcom/qcom-msm8930-samsung-expressltexx.dts:130-136` enables SDCC1 with pinctrl and PM8917 supply phandles.
- `linux/arch/arm/boot/dts/qcom/qcom-msm8930-samsung-expressltexx.dts:156-194` adds SDCC1 active and sleep pin states.
- `build-lk2nd-bootable.sh:191-195` and `build-lk2nd-userdata.sh:222-227` force the local test kernel to keep MMCI, Qualcomm DML, and BAM DMA support enabled.

Notes:

- This is a first eMMC probe pass. External SDCC3, card detect/write protect, SDCC reset handling, and HS200/DDR tuning are deliberately left for later.
- The previous temporary fixed eMMC supplies have been replaced by the minimal PM8917 RPM regulator model.

## Expressltexx Downstream Peripheral Inventory

Values currently known:

- Current mainline `qcom-msm8930.dtsi` is still a minimal bring-up file: clocks, TLMM, SDCC1/eMMC, GSBI5 UART, USB HS1, and CPU/timer plumbing only. Most peripherals below are downstream hardware facts, not yet modeled in Linux DT.
- Physical keys are active-low GPIO keys: volume up GPIO 50, volume down GPIO 81, home GPIO 35. Downstream reports volume as `KEY_VOLUMEUP`/`KEY_VOLUMEDOWN` and home as `KEY_HOMEPAGE`; home is wake-capable downstream and all use 5 ms debounce. Downstream gpiomux uses GPIO function, 8 mA drive, and pull-up while active.
- Touchscreen is Atmel maXTouch `MXT224S` on GSBI3 I2C bus ID 3, I2C address `0x4a`, IRQ GPIO 11, logical range X `0..479`, Y `0..799`, firmware/config tag `I8730_AT_1226`. Newer Express board revs use regulators `8917_lvs6` for 1.8 V and `8917_l31` set to 3.3 V; older revs use GPIO 79 (`GPIO_TSP_D_EN`) and GPIO 80 (`GPIO_TSP_A_EN`).
- Touchkeys are Cypress touchkeys on a bitbanged I2C bus ID 16, I2C address `0x20`, IRQ GPIO 65, keycodes `KEY_MENU` and `KEY_BACK`. Newer revs use bitbang SDA/SCL GPIO 24/25 plus `8917_lvs5` for 1.8 V, `8917_l30` set to 2.8 V, and LED regulator `8917_l33` set to 3.3 V; older revs use SDA/SCL GPIO 71/72, LDO enable GPIO 99, and LED GPIO 51.
- Haptics use the downstream Immersion/Vibetonz `tspdrv` platform device with `HAPTIC_PWM`, PWM GPIO 70, enable GPIO 63, `is_pmic_vib_en = 0`, `is_pmic_haptic_pwr_en = 0`, and `is_no_haptic_pwr = 1`. This is not the PMIC vibrator path.
- MUIC / micro-USB switch is `TSU6721`, bitbanged I2C bus ID 15, SDA GPIO 73, SCL GPIO 74, I2C address `0x4a >> 1` = `0x25`, IRQ GPIO 14. Downstream cable callbacks report USB, AC, UART/JIG, CDP, OTG, audio dock, car dock, desk dock, and incompatible chargers into OTG and battery state.
- NFC is NXP `PN547` on bitbanged I2C bus ID 17, SDA GPIO 95, SCL GPIO 96, I2C address `0x2b`, IRQ GPIO 106, VEN/enable GPIO 48, firmware GPIO 92, optional clock-request GPIO 90.
- ALS/proximity sensor is downstream `taos` / TAOS Triton at I2C address `0x39` on bitbanged bus ID 14, SDA GPIO 12, SCL GPIO 13, proximity IRQ GPIO 49. Sensor rails are `sensor_opt` set to 2.85 V and `sensor_pwr` at 1.8 V; prox LED uses `8917_l16` set to 3.0 V on board rev >= 03 or GPIO 89 on older revs.
- Motion sensors are InvenSense MPU6050 at I2C address `0x68` and MPU6500 downstream dummy address `0x62`, IRQ GPIO 67, with orientation matrix `{ 0, 1, 0, -1, 0, 0, 0, 0, 1 }`. Magnetometer is Yamaha YAS532-compatible downstream name `geomagnetic` at I2C address `0x2e`.
- MHL/HDMI bridge is Silicon Image `SII9234` on bitbanged I2C GPIO 8/9, bus ID `MSM_MHL_I2C_BUS_ID`, with addresses `0x72 >> 1`, `0x7a >> 1`, `0x92 >> 1`, and `0xc8 >> 1`. Control GPIOs are reset GPIO 1, enable GPIO 2, wake GPIO 77, interrupt GPIO 78, select GPIO 82; regulators are `8917_l12` 1.2 V, `8917_l35` 3.3 V, and `8917_lvs7`.
- Display panel is downstream `mipi_magna`, enabled by `CONFIG_FB_MSM_MIPI_MAGNA_OLED_VIDEO_WVGA_PT_PANEL`. Panel timing is 480x800, RGB888, 24 bpp, 60 Hz, MIPI DSI video burst mode, 2 data lanes, `dlane_swap = 0x01`, clock rate `343500000`, hsync pulse/back/front `4/16/80`, vsync pulse/back/front `2/4/10`, backlight range `1..255`.
- Camera config enables `MT9M114`, `OV2720`, `ISX012`, and `SR130PC20`. Concrete Express board data describes rear `ISX012` at I2C address `0x3d`, CSI0, 2 lanes (`lane_mask = 0x3`), mount angle 90, reset GPIO 107, standby GPIO 54, flash GPIOs 3 and 64, MCLK GPIO 5. Front `SR130PC20` is at I2C address `0x20`, CSI1, 1 lane (`lane_mask = 0x1`), mount angle 270, and uses main MCLK GPIO 5 on `CONFIG_MACH_EXPRESS`.
- Camera GPIO and rail facts: flash GPIO 3, main MCLK GPIO 5, camera core enable GPIO 6, camera I2C SDA/SCL GPIO 20/21, camera IO enable GPIO 34, camera analog enable GPIO 38, AF enable GPIO 66, VT standby GPIO 18, main standby GPIO 54, front reset GPIO 76, main reset GPIO 107. Power sequencing uses `GPIO_CAM_CORE_EN` for 5M core 1.2 V, `8917_l34` for sensor IO 1.8 V, `8917_l32` for sensor AVDD 2.8 V, and `8917_l11` for rear AF 2.8 V.
- Audio codec is Qualcomm WCD9304/Sitar over SLIMbus bus 1, with downstream `sitar-slim` / `sitar1p1-slim`, IRQ GPIO 62, reset GPIO 42, and supplies including `CDC_VDD_CP` 2.2 V, RX/TX/VDDIO rails at 1.8 V, and digital/analog 1.2-1.25 V rails.
- WLAN is Qualcomm WCNSS/Prima at downstream MMIO `0x03000000` size `0x280000`, 5-wire GPIOs 84-88, and `has_48mhz_xo = 1`. Android exposes Wi-Fi as `wlan0`; Bluetooth transport is Qualcomm SMD.
- FM uses downstream platform device `iris_fm`. Android ships `fm_qsoc_patches` and runs `init.qcom.fm.sh` for FM setup.
- Charger/fuel/battery path uses PM8921 charger/BMS/sec-charger configs with charging current table entries including USB `500/475` mA, AC `1000/1500` mA, CDP `1000/1500` mA, OTG `0/0`; max battery voltage `4350` mV; term current `60` mA; USB max current `1000` mA; sense resistor `10000` uOhm; connector resistance `45` mOhm. Battery data is `Samsung_8930_Express2_2000mAh_data` with FCC `2000` mAh, default rbatt `166` mOhm, capacitive rbatt `60` mOhm.
- External SD is SDCC3, 4-bit, with card-detect GPIO 39 active-low. Downstream SDCC3 supplies are `sdc_vdd = 2950000` uV and `sdc_vdd_io = 2950000/1850000` uV, with clock rates `400000`, `24000000`, `48000000`, `96000000`, and `192000000`.
- Mainline `samsung-expressatt` overlap is strongest for maXTouch (`atmel,maxtouch` at `0x4a`, IRQ GPIO 11), partial for GPIO keys (volume GPIOs 50/81 match but home is GPIO 40 on expressatt vs GPIO 35 on expressltexx), partial for NFC (`PN544` upstream expressatt vs downstream `PN547` expressltexx, both at `0x2b` and IRQ GPIO 106), and partial for sensors (YAS532 matches, ALS/prox is same broad AMS/TAOS family, accelerometer/gyro differs).

Sources:

- `linux/arch/arm/boot/dts/qcom/qcom-msm8930.dtsi:199-289` currently contains SDCC1, GSBI5 UART, USB HS1, and supporting minimal SoC nodes only.
- `android_kernel_samsung_msm8930-common/arch/arm/mach-msm/include/mach/express-gpio.h:23-129` defines Express GPIO numbers for camera, touchscreen, keys, touchkeys, vibrator, MUIC, NFC, sensors, MHL, audio, and OTG-related lines.
- `android_kernel_samsung_msm8930-common/arch/arm/mach-msm/devices-msm8x60.h:27-60` defines Express-related downstream I2C bus IDs: geomagnetic 11, sensors 12, optical 14, TSU6721 15, and NFC 17.
- `android_kernel_samsung_msm8930-common/arch/arm/configs/samsung_express_defconfig:273-326` enables TSU6721, PN547, GPIO keys, Cypress touchkey, and MXT224S touchscreen.
- `android_kernel_samsung_msm8930-common/arch/arm/configs/samsung_express_defconfig:332-336` enables MPU6050 and MPU6500 input drivers.
- `android_kernel_samsung_msm8930-common/arch/arm/configs/samsung_express_defconfig:356-373` enables PM8921 charger/BMS/sec-charger, PM8xxx support, and WCD9304 codec.
- `android_kernel_samsung_msm8930-common/arch/arm/configs/samsung_express_defconfig:387-417` enables MSM camera sensors, Iris FM, MHL, and Magna OLED panel.
- `android_kernel_samsung_msm8930-common/arch/arm/configs/samsung_express_defconfig:491-530` enables USB host/gadget/OTG support.
- `android_kernel_samsung_msm8930-common/arch/arm/configs/samsung_express_defconfig:572-579` enables Vibetonz, YAS532 magnetometer, TAOS optical sensor, and sensor symlink support.
- `android_kernel_samsung_msm8930-common/arch/arm/mach-msm/board-express.c:277-453` defines TSU6721 bitbang I2C, address, IRQ, and cable callbacks.
- `android_kernel_samsung_msm8930-common/drivers/misc/tsu6721.c:1-45` identifies the downstream driver as TSU6721 and gives device ID constants `0x0a` and rev `0x12`.
- `android_kernel_samsung_msm8930-common/arch/arm/mach-msm/board-express.c:496-665` defines SII9234 MHL GPIOs, regulators, reset sequence, and four I2C client addresses.
- `android_kernel_samsung_msm8930-common/arch/arm/mach-msm/board-express.c:678-715` defines MPU6050/MPU6500 and geomagnetic I2C board info plus the MPU orientation matrix and calibration file paths.
- `android_kernel_samsung_msm8930-common/arch/arm/mach-msm/board-express.c:718-783` defines sensor power regulators `sensor_opt` and `sensor_pwr`.
- `android_kernel_samsung_msm8930-common/arch/arm/mach-msm/board-express.c:786-924` defines TAOS optical sensor bus, address, thresholds, IRQ, and prox LED power path.
- `android_kernel_samsung_msm8930-common/arch/arm/mach-msm/board-express.c:928-983` defines PN547 I2C bus, address, IRQ, VEN, firmware, and optional clock request GPIOs.
- `android_kernel_samsung_msm8930-common/arch/arm/mach-msm/board-express.c:2673-2715` defines active-low volume/home GPIO key data and home wakeup behavior.
- `android_kernel_samsung_msm8930-common/arch/arm/mach-msm/board-express-gpiomux.c:752-786` defines the key pins as GPIO function, 8 mA drive, and active-state pull-up.
- `android_kernel_samsung_msm8930-common/arch/arm/mach-msm/board-express.c:3116-3132` defines the Vibetonz `tspdrv` haptic PWM platform data.
- `android_kernel_samsung_msm8930-common/arch/arm/mach-msm/board-8930-input-mxt.c:448-550` defines Express maXTouch board-revision-dependent power sequencing.
- `android_kernel_samsung_msm8930-common/arch/arm/mach-msm/board-8930-input-mxt.c:552-595` defines maXTouch platform data, address `0x4a`, IRQ GPIO 11, dimensions, and firmware/config tag.
- `android_kernel_samsung_msm8930-common/arch/arm/mach-msm/board-8930-input-tkey.c:408-650` defines Cypress touchkey power, LED, address `0x20`, IRQ GPIO 65, keycodes, and bitbanged I2C GPIO selection by board revision.
- `android_kernel_samsung_msm8930-common/arch/arm/mach-msm/board-8930-display.c:2418-2423` registers downstream panel device `mipi_magna`.
- `android_kernel_samsung_msm8930-common/drivers/video/msm/mipi_magna_oled_video_wvga_pt.c:654-704` defines Magna OLED resolution, timings, lane count, lane swap, clock rate, format, and frame rate.
- `android_kernel_samsung_msm8930-common/arch/arm/mach-msm/board-8930-camera-power.c:45-84` defines Express camera GPIO mux setup.
- `android_kernel_samsung_msm8930-common/arch/arm/mach-msm/board-8930-camera-power.c:116-206` defines Express camera rail sequencing and regulator names.
- `android_kernel_samsung_msm8930-common/arch/arm/mach-msm/board-8930-camera.c:1152-1193` defines rear ISX012 board data.
- `android_kernel_samsung_msm8930-common/arch/arm/mach-msm/board-8930-camera.c:1277-1318` defines front SR130PC20 board data.
- `android_kernel_samsung_msm8930-common/arch/arm/mach-msm/board-8930-camera.c:2037-2066` defines SR130PC20 and ISX012 I2C addresses.
- `android_kernel_samsung_msm8930-common/arch/arm/mach-msm/board-8930.c:646-805` defines WCD9304/Sitar SLIMbus devices, IRQ/reset GPIOs, and codec supply requirements.
- `android_kernel_samsung_msm8930-common/arch/arm/mach-msm/board-8930.c:807-847` defines WCNSS WLAN MMIO, IRQ resources, 5-wire GPIO range, and 48 MHz XO flag.
- `android_kernel_samsung_msm8930-common/arch/arm/mach-msm/board-express.c:153-157` defines the downstream Iris FM platform device.
- `android_device_samsung_expressltexx/system_prop.mk:37-48` records Bluetooth SMD transport and `wifi.interface=wlan0`.
- `android_device_samsung_expressltexx/proprietary-files.txt:1-4` lists FM/Wi-Fi/Bluetooth helper binaries including `fm_qsoc_patches` and `hci_qcomm_init`.
- `android_device_samsung_expressltexx/rootdir/init.qcom.rc:190-224` starts Bluetooth hciattach and Wi-Fi supplicant using `wlan0`/`p2p0`.
- `android_device_samsung_expressltexx/rootdir/init.qcom.rc:234-239` starts the FM setup script.
- `android_kernel_samsung_msm8930-common/arch/arm/mach-msm/board-8930-pmic.c:432-584` defines charger current limits, voltage/current thresholds, sense/connector resistance, and battery pdata.
- `android_kernel_samsung_msm8930-common/arch/arm/mach-msm/board-8930-pmic.c:718-739` defines PM8921 BMS pdata.
- `android_kernel_samsung_msm8930-common/arch/arm/mach-msm/bms-batterydata-express.c:108-116` defines the 2000 mAh Express battery data and rbatt values.
- `android_kernel_samsung_msm8930-common/arch/arm/mach-msm/board-8930-storage.c:41-111` defines SDCC1 eMMC and SDCC3 external-card supplies.
- `android_kernel_samsung_msm8930-common/arch/arm/mach-msm/board-8930-storage.c:139-172` defines SDCC3 active/sleep pad drive and pull settings.
- `android_kernel_samsung_msm8930-common/arch/arm/mach-msm/board-8930-storage.c:227-230` defines SDCC3 supported clock rates.
- `android_kernel_samsung_msm8930-common/arch/arm/mach-msm/board-8930-storage.c:253-291` defines SDCC3 bus width, card-detect GPIO/IRQ, and active-low status.
- `linux/arch/arm/boot/dts/qcom/qcom-msm8960-samsung-expressatt.dts:26-54` is the upstream Express ATT GPIO key reference.
- `linux/arch/arm/boot/dts/qcom/qcom-msm8960-samsung-expressatt.dts:63-80` is the upstream Express ATT AMS/TAOS light/prox reference.
- `linux/arch/arm/boot/dts/qcom/qcom-msm8960-samsung-expressatt.dts:123-136` is the upstream Express ATT maXTouch reference.
- `linux/arch/arm/boot/dts/qcom/qcom-msm8960-samsung-expressatt.dts:479-488` is the upstream Express ATT PN544 NFC reference.
- `linux/arch/arm/boot/dts/qcom/qcom-msm8960-samsung-expressatt.dts:500-518` is the upstream Express ATT BMA254/YAS532 sensor reference.
- `linux/drivers/input/touchscreen/atmel_mxt_ts.c:3395-3396` supports `compatible = "atmel,maxtouch"` in mainline.
- `linux/drivers/input/keyboard/tm2-touchkey.c:334-347` has mainline Cypress/Coreriver Samsung touchkey variants, but exact Cypress Express compatibility must be checked before reuse.
- `linux/drivers/nfc/pn544/i2c.c:46-60` has mainline PN544 I2C support, not an explicit PN547 OF match.
- `linux/drivers/iio/light/tsl2772.c:1900-1917` has mainline `tmd2772` / `amstaos,tmd2772` support.
- `linux/drivers/iio/imu/inv_mpu6050/inv_mpu_i2c.c:176-209` supports `mpu6050` and `mpu6500` I2C compatibles in mainline.
- `linux/drivers/iio/magnetometer/yamaha-yas530.c:1581-1595` supports `yas532` / `yamaha,yas532` in mainline.
- `linux/drivers/gpu/drm/bridge/sii9234.c:941-960` supports `compatible = "sil,sii9234"` in mainline.
- `linux/drivers/input/misc/pwm-vibra.c:38-59` shows mainline `pwm-vibrator` can drive a PWM plus optional enable GPIO and supply; this is the likely conceptual match for downstream `HAPTIC_PWM`, subject to PWM-provider availability on GPIO 70.

Current use:

- `linux/arch/arm/boot/dts/qcom/qcom-msm8930-samsung-expressltexx.dts:45-73` models the TLMM-backed home, volume-up, and volume-down keys; `qcom-msm8930-samsung-expressltexx.dts:140-145` adds their GPIO pin state.
- `linux/arch/arm/boot/dts/qcom/qcom-msm8930-samsung-expressltexx.dts:8-212` currently models board identity, simple-framebuffer, TLMM GPIO keys, minimal PM8917 RPM USB/eMMC supplies, GSBI5 UART, SDCC1/eMMC, and USB peripheral mode only.
- No mainline Expressltexx DT nodes currently model touchscreen, touchkeys, haptics, MUIC, NFC, sensors, MHL, display panel, cameras, audio, WLAN/Bluetooth/FM, charger/BMS, battery profile, PMIC power key, or SDCC3.

Notes:

- Do not copy `qcom-msm8960-samsung-expressatt.dts` electrical details blindly. It is useful for upstream style and nearby peripheral categories, but Expressltexx differs in PMIC/regulators, home-key GPIO, NFC enable GPIO, sensor set, MUIC, haptics, display panel, and cameras.
- Good low-risk future DTS candidates after PMIC/regulator plumbing settles are maXTouch, YAS532/MPU sensors, TAOS light/prox, and SDCC3. MUIC/PN547/touchkeys/haptics may need driver or binding checks before they become clean upstream nodes.

## lk2nd Continuous Splash / Simple Framebuffer

Values currently used:

- Runtime lk2nd log from the device reports MDP DMA_P continuous splash at base `0x88a00000`, stride `1440`, size `480x800`, output origin `(0,0)`, config `0x100213f`, and extracted format `0x0`.
- lk2nd's DMA_P continuous-splash reader extracts format bits `26:25`; format `0x0` maps to RGB888, with `bpp = 24` and logical stride `stride_bytes / 3`.
- Mainline simple-framebuffer uses byte stride, so the DT keeps `stride = <1440>` and maps format `0x0`/RGB888 to `format = "r8g8b8"`.
- Framebuffer memory size is derived as `1440 * 800 = 1152000 = 0x119400` bytes.
- The framebuffer lies inside the current conservative RAM bank `0x80000000..0x9fffffff`, so DT also reserves `0x88a00000..0x88b19400` with `no-map`.

Sources:

- `lk2nd/lk2nd/display/cont-splash/dma.c:12-31` reads `MDP_DMA_P_BUF_ADDR`, `MDP_DMA_P_CONFIG`, `MDP_DMA_P_SIZE`, `MDP_DMA_P_BUF_Y_STRIDE`, `MDP_DMA_P_OUT_XY`, extracts format bits, and prints the continuous-splash log line.
- `lk2nd/lk2nd/display/cont-splash/dma.c:33-55` maps DMA_P format `0x0` to `FB_FORMAT_RGB888`, `bpp = 24`, and `stride = stride / 3`.
- `lk2nd/include/dev/fbcon.h:90-93` defines lk2nd `FB_FORMAT_RGB565`, `FB_FORMAT_RGB666`, `FB_FORMAT_RGB666_LOOSE`, and `FB_FORMAT_RGB888` constants.
- `linux/Documentation/devicetree/bindings/display/simple-framebuffer.yaml:90-119` documents simple-framebuffer byte stride and allowed formats including `r8g8b8`.

Current use:

- `linux/arch/arm/boot/dts/qcom/qcom-msm8930-samsung-expressltexx.dts:13-43` adds `display0`, a `/chosen/framebuffer@88a00000` simple-framebuffer node, and a matching `reserved-memory` no-map region.
- `build-lk2nd-userdata.sh:221-231` and `build-lk2nd-bootable.sh:190-199` enable `CONFIG_FB_SIMPLE` for local bring-up images so the simple-framebuffer node creates an fbdev device.

Notes:

- `stdout-path` stays on `serial0` for now; the framebuffer is added for visual status and `/dev/fb0`, not as the primary console during early UART bring-up.

## lk2nd Linux boot.img Helpers

Values currently used:

- Direct fastboot round trips use an Android boot image at `out/expressltexx/expressltexx-boot.img` with base `0x80200000`, kernel offset `0x00008000`, ramdisk offset `0x02200000`, tags offset `0x00000100`, and page size `2048`.
- The direct boot ramdisk offset intentionally differs from downstream Android's `0x02000000`: `0x80200000 + 0x02200000 = 0x82400000`, matching lk2nd's extlinux-tested initrd placement after the direct `0x82200000` image booted Linux but reached `unknown-block(0,0)` without an initramfs.
- Direct fastboot images embed the dev initramfs in the kernel by default and set `CONFIG_INITRAMFS_FORCE=y`. A fastboot boot with external gzip initrd at `0x82400000` reached Linux with the right DTB and initrd size, but Linux rejected the external rootfs image as `invalid magic at start of compressed archive` before falling back to `unknown-block(0,0)`.
- The fastboot-bootable kernel payload is appended `zImage+DTB`, matching the userdata/extlinux fallback that was needed when the separate extlinux `fdt` path reached Linux with `r2=0`.
- The userdata fallback still creates an MBR extlinux image and also emits an Android `boot.img` side artifact. Its side-artifact ramdisk offset remains `0x01500000`; prefer `build-lk2nd-bootable.sh` for direct `fastboot boot` testing.
- The local helpers keep `earlycon` and `ttyMSM0` console output but no longer force `DEBUG_LL`, `DEBUG_QCOM_UARTDM`, or `EARLY_PRINTK`; that low-level mapping produced `BUG: mapping for 0x16440000 at 0xf0040000 out of vmalloc space` once normal earlycon was sufficient.

Sources:

- `android_device_samsung_expressltexx/BoardConfig.mk:34-39` gives downstream boot cmdline, base, image name, ramdisk offset, and page size.
- `lk2nd/app/aboot/aboot.c:3378-3409` shows the fastboot boot path using mkbootimg header kernel/ramdisk/tags addresses and validating their DDR ranges.
- `lk2nd/app/aboot/aboot.c:3438-3457` shows the fastboot boot path falling back to an appended DTB if no separate DTB was copied.
- `lk2nd/lk2nd/boot/extlinux.c:479-504` defines the extlinux fallback layout as `MAX_KERNEL_SIZE = 32 MiB`, `MAX_TAGS_SIZE = 2 MiB`, `tags = base + MAX_KERNEL_SIZE`, and `ramdisk = tags + MAX_TAGS_SIZE`.
- `boot.log:50-55` captured a successful lk2nd extlinux handoff with `ramdisk @ 0x82400000 (891166)`, which later reached `/init` from the dev initrd.
- `boot.log:1-4` captured the direct fastboot handoff with `ramdisk @ 0x82400000 (891680)` and `tags/device tree @ 0x80200100`.
- `boot.log:128-132` captured Linux detecting the external initrd, trying to unpack it, rejecting it as not initramfs, and freeing 872 KiB of initrd memory.
- `boot.log:186-190` captured `rdinit=/init` failing with `-2` and the resulting `unknown-block(0,0)` root mount failure.
- `boot.log:11-16` captured normal earlycon working followed by the low-level debug mapping warning that the local helper cleanup removes.
- Earlier hardware logs showed separate extlinux `fdt` did not reach ARM Linux (`r2=0`), while appended `zImage+DTB` did.

Current use:

- `build-lk2nd-bootable.sh:85-94` defines the built-in initramfs default and Android boot-image layout defaults for direct `fastboot boot` testing.
- `build-lk2nd-bootable.sh:202-207` and `build-lk2nd-userdata.sh:234-239` now keep only the forced bring-up cmdline, `DEBUG_KERNEL`, and `SMP=n` behavior from `DEBUG_BRINGUP=1`.
- `build-lk2nd-bootable.sh:226-246` creates appended `zImage+DTB` and passes it plus the dev initrd to `mkbootimg`.
- `build-lk2nd-bootable.sh:265` prints the intended `fastboot boot out/expressltexx/expressltexx-boot.img` command.
- `build-lk2nd-userdata.sh:103-107` keeps the fallback userdata side-artifact boot-image layout values.
- `build-lk2nd-userdata.sh:259-333` creates appended `zImage+DTB`, the extlinux image payload, and an Android `boot.img` side artifact.

Notes:

- `build-lk2nd-userdata.sh` remains the recovery/fallback path when USB gadget or fastboot boot is unavailable.
- `build-dev-initrd.sh` owns the tiny BusyBox/configfs CDC-ACM initrd shared by both local lk2nd image builders.

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
