# Bring-Up Status Details

Detailed implementation state for Samsung Galaxy Express GT-I8730 / GT-I8730T mainline bring-up. `README.md` keeps the short status matrix; `RESEARCH.md` indexes source breadcrumbs in `research/*.md`.

| Area | Hardware / IP | Status | Current Tree State | Next Work |
| --- | --- | --- | --- | --- |
| Boot chain | aboot -> lk2nd -> Linux | Working | lk2nd is the active chainloader; helpers generate Android boot images and userdata/extlinux fallback images. | Keep avoiding bootloader partition flashes unless recovery path is explicit. |
| SoC identity | MSM8930-family Qualcomm platform | Partial | `qcom-msm8930.dtsi` exists and board DT uses `compatible = "samsung,expressltexx", "qcom,msm8930"`. | Split more MSM8930-specific bindings/drivers instead of leaning on MSM8960 compatibility. |
| Memory | First RAM bank | Partial | Conservative `0x80000000..0x9fffffff` bank is used until lk2nd-patched memory reaches Linux reliably. | Validate full RAM layout. |
| Interrupts | QGIC2 | Working | Minimal GIC node works for UART, RPM, eMMC, USB, and keys. | Add remaining interrupt consumers as peripherals land. |
| Timers | KPSS / MSM timer | Working | Kernel boots with timer support from the minimal SoC DTSI. | None urgent. |
| Clocks | GCC/LCC board clocks | Partial | Uses mainline `qcom,gcc-msm8960` IDs and legacy `cxo_board`/`pxo_board` names. | Add or audit MSM8930-specific GCC support. |
| SMP / CPU | Dual Krait | Working | CPUs use the mainline `qcom,kpss-acc-v1` enable method with ACC/SAW phandles; CPU0 and CPU1 both come online. | Keep `DISABLE_SMP=1` as fallback if SMP regressions appear. |
| UART | GSBI5 UARTDM via USB connector UART cable | Working | `serial0` / `ttyMSM0` console works at `115200n8`. | None urgent. |
| Framebuffer | lk2nd continuous splash / simple-framebuffer | Working | Simple framebuffer at `0x88a00000`, 480x800 RGB888, gives `/dev/fb0`. | Replace with real MDP/DSI panel later. |
| RPM | MSM8930 RPM | Working | `qcom,rpm-msm8930` and minimal MSM8930 RPM resource table are present. | Extend resource table only as consumers require it. |
| Regulators | PM8917 RPM S4/L3/L4/L5 | Working | USB/eMMC supplies are modeled; `regulator_ignore_unused` is no longer needed. | Add more PM8917 rails for sensors, display, audio, camera, etc. |
| Alternate PMIC | PM8038 RPM data | Builds | Minimal PM8038 regulator data exists because downstream has a PM8038 path. | Switch board DT only if hardware proves PM8038. |
| SSBI PMIC bus | PMIC arbiter at `0x00500000` | Working | MSM8930 SSBI node exists and PM8917 probes over it. | Add more PM8917 child devices deliberately. |
| Power key | PM8917 PM8xxx pwrkey | Working | PM8917/PM8038 bindings and driver compatibles added; power key emits `KEY_POWER`. | Upstream review of PM8917/PM8038 compatible additions. |
| GPIO keys | Home, volume up, volume down | Working | TLMM `gpio-keys` for GPIOs 35, 50, 81 emit expected input events. | None urgent. |
| USB device | HSUSB1 ChipIdea peripheral | Working | `usb1` runs in peripheral mode with PM8917 PHY supplies and Express PHY init sequence. | Model MUIC/extcon/VBUS before serious OTG/host work. |
| USB gadget shell | configfs CDC-ACM | Working | Static BusyBox initramfs creates ACM gadget and shell on `ttyGS0`. | Test with normal USB cable path; UART cable may route D+/D- away from USB. |
| eMMC | SDCC1, 8-bit non-removable | Working | `mmcblk0` and GPT partitions probe; Android partitions mount manually. | Add reset/tuning/HS200 details if needed. |
| External SD | SDCC3 | Known | Downstream GPIO, clocks, bus width, CD, and supplies are recorded. | Add SDCC3 node and PM8917 rails. |
| RTC | PM8917/PM8xxx RTC | Known | PM8917 DTSI intentionally omits RTC for now. | Validate register/IRQ compatibility before exposing. |
| Charger / fuel gauge | PM8921 charger, BMS, Samsung sec-charger | Known | Downstream current limits and 2000 mAh battery profile are recorded. | Identify clean mainline charger/BMS path and bindings. |
| Thermal | TSENS | Blocked | TSENS probe/oops was seen and thermal work is currently descoped. | Return later with focused TSENS driver/debug work. |
| Touchscreen | Atmel maXTouch MXT224S | Known | Downstream I2C address, IRQ, dimensions, and rails are recorded; mainline driver exists. | Add GSBI3 I2C and touchscreen/regulator nodes. |
| Touchkeys | Cypress touchkey | Known | Downstream bitbang I2C, IRQ, keycodes, and rails are recorded. | Check mainline driver/binding match or add support. |
| Haptics | PWM vibrator on GPIO 70, enable GPIO 63 | Known | Downstream facts recorded; likely conceptual match is `pwm-vibrator`. | Confirm PWM provider feasibility for GPIO 70. |
| MUIC / USB switch | TSU6721 | Known | Downstream bitbang I2C address, IRQ, and cable callbacks are recorded. | Check or add mainline driver, then wire extcon/VBUS. |
| NFC | NXP PN547 | Known | Downstream I2C address, IRQ, VEN, firmware GPIOs are recorded. | Check PN544/PN547 driver compatibility and binding. |
| ALS / proximity | TAOS / AMS sensor | Known | Downstream address, IRQ, thresholds, LED power path, and rails are recorded. | Add I2C/regulator nodes after PM8917 rail expansion. |
| Motion sensors | MPU6050/MPU6500, YAS532 | Known | Downstream addresses, IRQ, and orientation matrix are recorded; mainline drivers likely exist. | Add sensor I2C bus and regulator nodes. |
| Display panel | Magna OLED WVGA over MIPI DSI | Known | Downstream timings, lanes, format, clock, and backlight range are recorded. | Bring up real MDP/DSI/panel after framebuffer baseline. |
| MHL / HDMI | Silicon Image SII9234 | Known | Downstream I2C addresses, GPIOs, and rails are recorded; mainline bridge driver exists. | Add bitbang I2C/GPIO/regulator nodes after display power is clearer. |
| Cameras | ISX012 rear, SR130PC20 front | Known | Downstream sensor addresses, CSI lanes, GPIOs, and power sequencing are recorded. | Low priority; depends on camera stack and regulators. |
| Audio | WCD9304 / Sitar over SLIMbus | Known | Downstream SLIMbus devices, IRQ/reset GPIOs, and supplies are recorded. | Add SLIMbus/audio only after PMIC/regulator coverage grows. |
| WLAN | Qualcomm WCNSS/Prima | Known | Downstream MMIO range, 5-wire GPIOs, and 48 MHz XO flag are recorded. | Add WCNSS nodes and firmware/userland expectations later. |
| Bluetooth | Qualcomm SMD transport | Known | Android init/property clues are recorded. | Requires SMD/RPMSG-side plumbing and firmware/userland. |
| FM radio | Iris FM | Known | Downstream platform device and Android setup script are recorded. | Low priority. |
| U-Boot | Chain-loaded from lk2nd | Out of scope | Current active path is Linux via lk2nd; U-Boot replacement is not the current goal. | Do not overwrite `aboot` without explicit approval and recovery path. |
