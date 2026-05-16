# RPM, PMIC, Regulators, And Power Key

Use this file when reasoning about MSM8930 RPM, PM8917/PM8038 regulators, SSBI PMIC wiring, PM8xxx services, or the PMIC power key.

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
- `linux/arch/arm/boot/dts/qcom/qcom-msm8930-samsung-expressltexx.dts:94-129` declares the PM8917 S4/L3/L4/L5 regulators; `qcom-msm8930-samsung-expressltexx.dts:135-141` wires SDCC1 to L5/S4; `qcom-msm8930-samsung-expressltexx.dts:207-209` wires the USB PHY to L4/L3.
- `build-lk2nd-bootable.sh:101` and `build-lk2nd-userdata.sh:113-114` no longer pass `regulator_ignore_unused` by default.

Notes:

- The PMIC variant still should be verified from hardware logs when possible. If a tested GT-I8730 reports PM8038 instead of PM8917, the board DTS should switch the regulator node compatible/phandles to the PM8038 rails above.
- This is intentionally a minimal early bring-up RPM/regulator model. It covers UART-independent RPM access plus the USB/eMMC rails needed to remove `regulator_ignore_unused`, not the complete PM8917/PM8038 regulator set.

## MSM8930 SSBI / PM8917 Power Key

Values currently used:

- The PMIC SSBI command window is at `0x00500000` with size `0x1000`; mainline models it as `ssbi@500000` with `qcom,controller-type = "pmic-arbiter"`.
- Express routes the PM8xxx interrupt line through TLMM GPIO 104, active-low; mainline models this as `interrupts-extended = <&tlmm 104 IRQ_TYPE_LEVEL_LOW>` on the PM8917 node.
- The PMIC power key uses PM8xxx PON control register `0x1c`, release IRQ 50, press IRQ 51, `15625` us debounce, and KPDPWR_N pull-up enabled.
- The board DT uses PM8917-specific compatibles with PM8921 fallbacks because downstream treats PM8917 as the PM8921-core family for SSBI/PM8xxx services while selecting PM8917-specific regulator data separately.
- Mainline `pmic8xxx-pwrkey` reports PM8xxx power-key events as `KEY_POWER`; the driver marks the device wake-capable unconditionally, matching downstream `.wakeup = 1` intent.

Sources:

- `android_kernel_samsung_msm8930-common/arch/arm/mach-msm/devices-8960.c:100-102` defines the PMIC1 SSBI command base `0x00500000` and size `SZ_4K`.
- `android_kernel_samsung_msm8930-common/arch/arm/mach-msm/devices-8960.c:2423-2436` registers downstream `msm8960_device_ssbi_pmic` using that SSBI resource.
- `android_kernel_samsung_msm8930-common/arch/arm/mach-msm/board-8930-pmic.c:353-356` sets the PM8xxx IRQ base, GPIO 104 devirq, and low-trigger flag.
- `android_kernel_samsung_msm8930-common/arch/arm/mach-msm/board-8930-pmic.c:372-376` sets power-key pull-up, `15625` us trigger delay, and wakeup.
- `android_kernel_samsung_msm8930-common/arch/arm/mach-msm/board-8930-pmic.c:834-856` attaches PM8917 platform data, including the shared PM8xxx power-key pdata, to the PM8921-core SSBI slave.
- `android_kernel_samsung_msm8930-common/include/linux/mfd/pm8xxx/pm8921.h:58-61` defines PM8921-compatible pwrkey release IRQ 50 and press IRQ 51; `pm8038.h:58-59` defines the same IRQ numbers for PM8038.
- `linux/drivers/input/misc/pmic8xxx-pwrkey.c:375-427` reports `KEY_POWER`, configures PON debounce/pull-up, registers press/release IRQs, and marks the device wake-capable.

Current use:

- `linux/Documentation/devicetree/bindings/mfd/qcom-pm8xxx.yaml:24-29` allows `qcom,pm8038` and `qcom,pm8917` PM8xxx nodes with `qcom,pm8921` fallback.
- `linux/Documentation/devicetree/bindings/input/qcom,pm8921-pwrkey.yaml:21-26` allows `qcom,pm8038-pwrkey` and `qcom,pm8917-pwrkey` with `qcom,pm8921-pwrkey` fallback.
- `linux/drivers/mfd/qcom-pm8xxx.c:501-506` maps `qcom,pm8038` and `qcom,pm8917` to the PM8xxx IRQ/regmap data.
- `linux/drivers/input/misc/pmic8xxx-pwrkey.c:432-436` maps `qcom,pm8038-pwrkey` and `qcom,pm8917-pwrkey` to the PM8921-compatible shutdown path.
- `linux/arch/arm/boot/dts/qcom/qcom-msm8930.dtsi:98-102` adds the MSM8930 SSBI PMIC arbiter node.
- `linux/arch/arm/boot/dts/qcom/pm8917.dtsi:5-42` adds the PM8917 SSBI PMIC node, power key, MPP controller, and GPIO controller.
- `linux/arch/arm/boot/dts/qcom/qcom-msm8930-samsung-expressltexx.dts:6-7` includes the MSM8930 and PM8917 DTSI files; `qcom-msm8930-samsung-expressltexx.dts:131-133` wires the PM8917 interrupt to TLMM GPIO 104.

Notes:

- The PM8917 DTSI intentionally does not add RTC, ADC, charger, or BMS nodes yet; those need separate validation of PM8917-compatible register layout, IRQs, and bindings before being exposed.
