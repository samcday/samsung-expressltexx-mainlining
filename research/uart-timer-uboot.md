# UART, Timer, And U-Boot Bring-Up

Use this file when reasoning about UARTDM, GSBI5, MSM timers, early U-Boot support, or U-Boot memory assumptions.

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
