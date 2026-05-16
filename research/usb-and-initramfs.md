# USB And Initramfs Gadget

Use this file when reasoning about HSUSB1, the integrated USB PHY, gadget mode, CDC-ACM shell, or the local dev initramfs.

## MSM8930 HSUSB / UDC

Values currently used:

- HSUSB controller base is `0x12500000`; downstream names it `MSM8960_HSUSB_PHYS` but uses it from the Express/MSM8930 board path.
- Downstream resource size is `SZ_4K`. Mainline currently follows the existing MSM8960 ChipIdea DT shape with two `0x200` register windows at `0x12500000` and `0x12500200`.
- USB1 HS interrupt is `USB1_HS_IRQ = GIC_SPI_START + 100`, represented in DT as `interrupts = <GIC_SPI 100 IRQ_TYPE_LEVEL_HIGH>`.
- Mainline USB clocks/resets currently use the existing MSM8960 GCC IDs: `USB_HS1_XCVR_CLK = 128`, `USB_HS1_H_CLK = 126`, and `USB_HS1_RESET = 64`.
- HSUSB PHY uses the 28 nm integrated ULPI PHY path. Mainline represents this with `qcom,usb-hs-phy-msm8960`, `phy_type = "ulpi"`, and a 60 MHz `USB_HS1_XCVR_CLK` assignment.
- USB PHY supplies are modeled through RPM regulators: PM8917 L4 for `v1p8 = 1800000` uV and PM8917 L3 for `v3p3 = 3075000` uV. Downstream maps HSUSB 1.8 V to PM8917/PM8038 L4 and HSUSB 3.3 V to L3; both downstream regulator files program L4 to 1.8 V and L3 to 3.075 V.
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
- `android_kernel_samsung_msm8930-common/arch/arm/mach-msm/board-8930-regulator-pm8917.c:46-53` maps `HSUSB_3p3` to L3 and `HSUSB_1p8` to L4 for `msm_otg`; `board-8930-regulator-pm8917.c:706-710` programs PM8917 L3 to `3075000` uV and L4 to `1800000` uV.
- `android_kernel_samsung_msm8930-common/arch/arm/mach-msm/board-8930-regulator-pm8038.c:43-50` maps `HSUSB_3p3` to L3 and `HSUSB_1p8` to L4 for `msm_otg`; `board-8930-regulator-pm8038.c:527-531` programs PM8038 L3 to `3075000` uV and L4 to `1800000` uV.
- `linux/drivers/phy/qualcomm/phy-qcom-usb-hs.c:131-132` first asks the `v3p3` regulator for exactly `3300000` uV, then `linux/include/linux/regulator/consumer.h:717-724` falls back to the wider `3050000..3300000` uV range if that target request fails.

Current use:

- `linux/arch/arm/boot/dts/qcom/qcom-msm8930.dtsi:263-293` adds disabled `usb1: usb@12500000` and nested ULPI `usb_hs1_phy` nodes.
- `linux/arch/arm/boot/dts/qcom/qcom-msm8930-samsung-expressltexx.dts:107-119` defines the PM8917 L3/L4 USB PHY supply regulators.
- `linux/arch/arm/boot/dts/qcom/qcom-msm8930-samsung-expressltexx.dts:202-217` enables `usb1` in peripheral mode, attaches the PM8917 PHY supplies, and supplies the Express PHY init sequence.

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
