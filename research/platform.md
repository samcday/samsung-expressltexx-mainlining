# Platform Identity, Clocks, And SoC Basics

Use this file when reasoning about MSM8930 vs MSM8960 naming, board identity, generic SoC bring-up, and the audited GCC/board-clock compatibility path.

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

- `linux/arch/arm/boot/dts/qcom/qcom-msm8930-samsung-expressltexx.dts:1-11` includes `qcom-msm8930.dtsi`, includes `pm8917.dtsi`, and advertises `compatible = "samsung,expressltexx", "qcom,msm8930"`.
- `u-boot/dts/upstream/src/arm/qcom/qcom-msm8960-samsung-expressltexx.dts:1-8` still includes `qcom-msm8960.dtsi` and advertises `qcom,msm8960`; treat this as an early bring-up shortcut that needs auditing against MSM8930-specific facts before adding more peripherals.

Notes:

- Existing U-Boot timer/UART values were individually source-backed and reached a UART prompt, but future U-Boot work should not inherit additional MSM8960 nodes or Express ATT facts without a matching breadcrumb.

## Qualcomm SMEM / SoCinfo

Values currently used:

- Mainline SMEM is modeled at `0x80000000` size `0x200000`, matching the low 2 MiB region omitted from the tested usable RAM map.
- SMEM locking uses the older SFPB mutex block at `0x01200600` size `0x84` and lock index 3, matching the mainline `qcom,smem` binding example for Qualcomm SMEM locking.
- With `CONFIG_QCOM_SMEM=y`, `CONFIG_HWSPINLOCK_QCOM=y`, and `CONFIG_QCOM_SOCINFO=y`, the SMEM driver should register `qcom-socinfo`, which reads `SMEM_HW_SW_BUILD_ID` and exposes `/sys/devices/soc0/soc_id` for on-device SoC identity checks.

Sources:

- `android_kernel_samsung_msm8930-common/arch/arm/mach-msm/remote_spinlock.c:29-32` selects the SFPB remote spinlock path and defines `MSM_SFPB_MUTEX_REG_BASE 0x01200600` and size `(33 * 4)`.
- `linux/Documentation/devicetree/bindings/hwlock/qcom-hwspinlock.yaml:16-44` documents `qcom,sfpb-mutex`, `reg`, and `#hwlock-cells`.
- `linux/Documentation/devicetree/bindings/soc/qcom/qcom,smem.yaml:18-48` requires `compatible = "qcom,smem"` plus `hwlocks` and either inline `reg`/`no-map` or a `memory-region` phandle.
- `linux/drivers/soc/qcom/smem.c:1237-1243` registers the `qcom-socinfo` platform device after SMEM probes.
- `linux/drivers/soc/qcom/socinfo.c:871-918` reads `SMEM_HW_SW_BUILD_ID`, registers `soc0`, and exposes the SMEM SoC ID through the SoC bus attributes.

Current use:

- `linux/arch/arm/boot/dts/qcom/qcom-msm8930.dtsi` marks the SMEM reserved-memory node as `qcom,smem`, wires it to `&sfpb_mutex 3`, and describes `sfpb_mutex: hwlock@1200600`.

Notes:

- Use `/sys/devices/soc0/soc_id` to distinguish firmware-reported MSM8930-family IDs from the board DT compatible string once hardware has booted this node.

## Expressltexx RAM Bank

Values currently used:

- The MSM8930 SoC DTSI keeps the standard Qualcomm zero-size memory placeholder at `memory@80000000`; the bootloader is expected to fill in the usable RAM map.
- On tested hardware, vendor `aboot` passes ATAGS at `r2 = 0x80200100`; lk2nd preserves those ATAGS; Linux `CONFIG_ARM_ATAG_DTB_COMPAT` converts their `ATAG_MEM` entries into the live FDT memory node.
- The live memory node reports usable ranges `0x80200000 0x1fe00000` and `0xa0000000 0x20000000`, so Linux uses 1022 MiB from the 1 GiB board RAM while omitting the first 2 MiB.
- Future modem, multimedia, display, or firmware carveouts should be modeled as specific `reserved-memory` regions only when a consumer needs them.

Sources:

- `android_kernel_samsung_msm8930-common/arch/arm/mach-msm/board-express.c:2301-2303` passes `0x40000000` size and `0x80000000` base to downstream Samsung debug memory reporting.
- `linux/arch/arm64/boot/dts/qcom/sdm670.dtsi:310-313` documents the modern Qualcomm pattern: `/* We expect the bootloader to fill in the size */` on a zero-size memory node.
- `linux/arch/arm/boot/dts/qcom/qcom-msm8960.dtsi:79-81` uses the same zero-size `memory@80000000` placeholder pattern for the upstream MSM8960 family.
- `linux/arch/arm/boot/dts/qcom/qcom-msm8930.dtsi:76-79` follows that placeholder pattern for local MSM8930 bring-up.
- lk2nd hardware log shows `Booted @ 0x80208000, r0=0x0, r1=0xe8f, r2=0x80200100` and `Found valid ATAGS with 800 bytes total`, proving vendor `aboot` supplied ATAGS to lk2nd.
- Tested Linux `/proc/device-tree/memory@80000000/reg` decoded to `0x80200000 0x1fe00000` and `0xa0000000 0x20000000`.
- `out/expressltexx/linux-build/.config:512-513` enables `CONFIG_ARM_ATAG_DTB_COMPAT` and `CONFIG_ARM_ATAG_DTB_COMPAT_CMDLINE_FROM_BOOTLOADER` in the local test build.
- `linux/arch/arm/boot/compressed/atags_to_fdt.c:172-215` converts non-empty `ATAG_MEM` entries into the FDT `/memory` `reg` property.

Current use:

- `linux/arch/arm/boot/dts/qcom/qcom-msm8930-samsung-expressltexx.dts` does not override `/memory@80000000`; it relies on the common MSM8930 placeholder and the bootloader-filled RAM map.

Notes:

- Earlier bring-up used a conservative 512 MiB board override while the boot path and appended-DTB handoff were still being validated. That is no longer tracked as a memory bring-up blocker.
- Do not advertise `0x80000000..0x801fffff` as usable RAM unless a non-ATAG boot path proves it is safe; the vendor boot chain currently omits that first 2 MiB from Linux's usable map.

## MSM8930 GCC / MSM8960 Driver Compatibility

Values currently used:

- MSM8930 bring-up uses the mainline `qcom,gcc-msm8960` driver and binding IDs for the core GCC subset needed by the current boot baseline.
- This is settled for the currently enabled GCC consumers: KPSS/L2 PLL8 vote, GSBI5 UART, SDCC1/eMMC, SDCC1 BAM, and HSUSB1 peripheral mode.
- Downstream also implements MSM8930 clocks in the shared `clock-8960.c` driver, but Express selects MSM8930-specific init data and an MSM8930-specific clock lookup table rather than plain MSM8960 init data.
- Do not infer that future multimedia, GPU, display, camera, or audio clock work is settled by this audit. Downstream has MSM8930-specific branches for PLL15, GFX3D, MM AHB/AXI setup, and PMIC voltage handling that need focused review before adding MMCC/LCC consumers.
- The fixed clock nodes under `/clocks` intentionally use legacy underscore node names `cxo_board`, `pxo_board`, and `sleep_clk`. `qcom_cc_register_board_clk()` looks up exact `/clocks/<path>` child names before deciding whether to register fallback clocks.
- `cxo_board` is `19200000` Hz and `pxo_board` is `27000000` Hz, matching the fallback rates registered by `gcc-msm8960`.
- If these node names are changed to hyphenated names, `gcc-msm8960` attempts to register duplicate `cxo_board`/`pxo_board` clocks and fails before GSBI/USB suppliers can probe.

Sources:

- `linux/drivers/clk/qcom/common.c:147-184` documents and implements the legacy `/clocks/<path>` lookup before fallback board-clock registration.
- `linux/drivers/clk/qcom/gcc-msm8960.c:3716-3729` registers fallback `cxo_board` and `pxo_board` clocks at `19200000` and `27000000` Hz.
- `android_kernel_samsung_msm8930-common/arch/arm/mach-msm/board-express.c:3832-3836` selects `msm8930_pm8917_clock_init_data` on PM8917 hardware and `msm8930_clock_init_data` otherwise.
- `android_kernel_samsung_msm8930-common/arch/arm/mach-msm/clock-8960.c:6038-6541` defines the MSM8930 clock lookup table, including GSBI5 UART/QUP, SDCC1, HSUSB1, PMIC arbiter, RPM message RAM, GFX3D, MDP, and related multimedia clocks.
- `android_kernel_samsung_msm8930-common/arch/arm/mach-msm/clock-8960.c:6970-7110` defines the MSM8930 and MSM8930/PM8917 clock init data and wraps the shared 8960 pre/post/late init paths with MSM8930 voltage setup.
- `android_kernel_samsung_msm8930-common/arch/arm/mach-msm/clock-8960.c:67-72` and `:1290-1352` show the GSBI UART register layout used by GSBI5; `linux/drivers/clk/qcom/gcc-msm8960.c:3248-3271` exposes the matching GSBI UART clocks used by DT.
- `android_kernel_samsung_msm8930-common/arch/arm/mach-msm/clock-8960.c:104-107` and `:1501-1545` show the SDCC register layout and frequency table; `linux/drivers/clk/qcom/gcc-msm8960.c:3305-3314` exposes matching SDCC clocks.
- `android_kernel_samsung_msm8930-common/arch/arm/mach-msm/clock-8960.c:125-129`, `:1663`, `:2420-2430`, and `:7008` show HSUSB1 clock registers and 60 MHz post-init rate; `linux/drivers/clk/qcom/gcc-msm8960.c:3317-3318` and `:3348` expose the matching USB HS1 clocks.
- `linux/arch/arm/boot/dts/qcom/qcom-msm8960.dtsi:15-37` uses the same underscore node names for `cxo_board`, `pxo_board`, and `sleep_clk`.
- `boot.log:224-227` captured the failure mode: `gcc-msm8960` failed to register duplicate `cxo_board`, which left `900000.clock-controller` unavailable.
- `boot.log:398-401` captured the downstream effect: GSBI and USB deferred forever because their `900000.clock-controller` supplier was not ready.

Current use:

- `linux/arch/arm/boot/dts/qcom/qcom-msm8930.dtsi:15-35` defines `cxo_board`, `pxo_board`, and `sleep_clk` with the exact legacy node names expected by the current GCC compatibility path.
- `linux/arch/arm/boot/dts/qcom/qcom-msm8930.dtsi:124-171` wires KPSS, CPU ACC, and GCC through `qcom,gcc-msm8960` PLL8/board clock IDs.
- `linux/arch/arm/boot/dts/qcom/qcom-msm8930.dtsi:205-293` wires the current SDCC1, GSBI5 UART, and HSUSB1 consumers to the audited GCC clock IDs.

Notes:

- Keep using `qcom,gcc-msm8960` for the current core GCC subset unless hardware logs show a mismatch. A dedicated `qcom,gcc-msm8930` compatible should only be added after splitting the descriptor enough to honestly describe MSM8930-specific differences.
- Treat LCC and future MMCC/GPU/display/audio clocks as separate audits. The board DT currently instantiates LCC only as the PLL4 provider expected by GCC, with no enabled audio consumers.
