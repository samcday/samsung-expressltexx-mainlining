# Storage

Use this file when reasoning about internal eMMC, external SD, SDCC controllers, BAM/DML, and storage-related supplies.

## MSM8930 SDCC1 / eMMC

Values currently used:

- SDCC1 is the internal non-removable eMMC controller. Android refers to the boot device as `msm_sdcc.1`.
- SDCC1 core base is `0x12400000`; the DML block starts at `0x12400800`; the BAM block starts at `0x12402000`.
- The mainline PL18x node maps `0x12400000..0x12401fff`, matching the existing MSM8960 mainline shape so the Qualcomm DML registers at offset `0x800` are included.
- SDCC1 host IRQ is `GIC_SPI 104`; SDCC1 BAM IRQ is `GIC_SPI 98`.
- SDCC1 uses the existing MSM8960 GCC-compatible IDs `SDC1_CLK`, `SDC1_H_CLK`, and `SDC1_RESET` while MSM8930-specific GCC support is not split out.
- The downstream Express storage table supports SDCC1 clock rates `400000`, `24000000`, `48000000`, and `96000000`; the DT caps `max-frequency` at `96000000` for the first pass.
- Downstream Express enables `CONFIG_MMC_MSM_SDC1_8_BIT_SUPPORT`, so DT sets `bus-width = <8>`.
- SDCC1 eMMC supplies are modeled through RPM regulators: PM8917 L5 for `vmmc = 2950000` uV and PM8917 S4 for `vqmmc = 1800000` uV, matching downstream SDCC1 `sdc_vdd` and `sdc_vdd_io` regulator voltage requests.
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

- `linux/arch/arm/boot/dts/qcom/qcom-msm8930.dtsi:205-230` adds disabled SDCC1 and SDCC1 BAM nodes.
- `linux/arch/arm/boot/dts/qcom/qcom-msm8930-samsung-expressltexx.dts:98-127` defines the PM8917 S4/L5 eMMC supply regulators.
- `linux/arch/arm/boot/dts/qcom/qcom-msm8930-samsung-expressltexx.dts:135-141` enables SDCC1 with pinctrl and PM8917 supply phandles.
- `linux/arch/arm/boot/dts/qcom/qcom-msm8930-samsung-expressltexx.dts:161-199` adds SDCC1 active and sleep pin states.
- `build-lk2nd-bootable.sh:191-195` and `build-lk2nd-userdata.sh:222-227` force the local test kernel to keep MMCI, Qualcomm DML, and BAM DMA support enabled.

Notes:

- This is a first eMMC probe pass. External SDCC3, card detect/write protect, SDCC reset handling, and HS200/DDR tuning are deliberately left for later.
- The previous temporary fixed eMMC supplies have been replaced by the minimal PM8917 RPM regulator model.

## External SD / SDCC3

Values currently known:

- External SD is SDCC3, 4-bit, with card-detect GPIO 39 active-low.
- Downstream SDCC3 supplies are `sdc_vdd = 2950000` uV and `sdc_vdd_io = 2950000/1850000` uV.
- Downstream SDCC3 clock rates are `400000`, `24000000`, `48000000`, `96000000`, and `192000000`.

Sources:

- `android_device_samsung_expressltexx/rootdir/fstab.qcom` and Android init files distinguish eMMC at `msm_sdcc.1` from external SD at `msm_sdcc.3`.
- `android_kernel_samsung_msm8930-common/arch/arm/mach-msm/board-8930-storage.c:41-111` defines SDCC1 eMMC and SDCC3 external-card supplies.
- `android_kernel_samsung_msm8930-common/arch/arm/mach-msm/board-8930-storage.c:139-172` defines SDCC3 active/sleep pad drive and pull settings.
- `android_kernel_samsung_msm8930-common/arch/arm/mach-msm/board-8930-storage.c:227-230` defines SDCC3 supported clock rates.
- `android_kernel_samsung_msm8930-common/arch/arm/mach-msm/board-8930-storage.c:253-291` defines SDCC3 bus width, card-detect GPIO/IRQ, and active-low status.

Current use:

- No mainline Expressltexx DT node models SDCC3 yet.

Notes:

- SDCC3 is a low-risk future DT candidate after the required PM8917 rails are modeled.
