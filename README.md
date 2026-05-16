# Samsung Galaxy Express GT-I8730 Mainlining

Mainline bring-up workspace for Samsung Galaxy Express GT-I8730 / GT-I8730T,
Android codename `expressltexx` / `expresslte`.

The active kernel tree is `linux/` on branch `samsung-expressltexx`.
`RESEARCH.md` indexes detailed source breadcrumbs in `research/*.md`;
implementation details live in `STATUS.md`; this file is only the quick human
status page.

## Current Test Path

Build a bootable lk2nd image:

```sh
./build-lk2nd-bootable.sh
```

Boot it without flashing:

```sh
fastboot boot out/expressltexx/expressltexx-boot.img
```

Fallback userdata/extlinux image:

```sh
./build-lk2nd-userdata.sh
```

Current successful baseline: lk2nd starts Linux, UART works, simple framebuffer
works, PM8917 RPM regulators probe, eMMC probes, CDC-ACM gadget shell works,
the home/volume/power keys emit input events, PM8917 RTC read/write persists
across reboots, and both Krait CPUs come online. Local images now keep
`CONFIG_SMP` enabled by default; use `DISABLE_SMP=1` with the build helpers for
single-core fallback testing.

## Status Legend

| Status | Meaning |
| --- | --- |
| ✅ | Implemented and tested on hardware. |
| ⚠️ | Partially implemented, build-tested only, or intentionally using a temporary shortcut. |
| ❌ | Not implemented in the current mainline tree. |

## Bring-Up Matrix

| Area | Hardware / IP | Status | Notes |
| --- | --- | --- | --- |
| Boot chain | aboot -> lk2nd -> Linux | ✅ | |
| SoC identity | MSM8930-family Qualcomm platform | ⚠️ | Board DT is MSM8930-specific, but some bindings/drivers still lean on MSM8960-era compatibility. |
| Memory | Bootloader-filled RAM map | ✅ | |
| Interrupts | QGIC2 | ✅ | |
| Timers | KPSS / MSM timer | ✅ | |
| Clocks | GCC board clocks | ✅ | Current UART/eMMC/USB/KPSS GCC consumers are audited against downstream MSM8930 clock data; multimedia clocks remain future work. |
| SMP / CPU | Dual Krait | ✅ | |
| UART | GSBI5 UARTDM via USB connector UART cable | ✅ | |
| Framebuffer | lk2nd continuous splash / simple-framebuffer | ✅ | |
| RPM | MSM8930 RPM | ✅ | |
| Regulators | PM8917 RPM S4/L3/L4/L5 | ✅ | |
| Alternate PMIC | PM8038 RPM data | ⚠️ | Build support exists, but board DT stays on PM8917 unless hardware proves PM8038. |
| SSBI PMIC bus | PMIC arbiter at `0x00500000` | ✅ | |
| Power key | PM8917 PM8xxx pwrkey | ✅ | |
| GPIO keys | Home, volume up, volume down | ✅ | |
| USB device | HSUSB1 ChipIdea peripheral | ✅ | |
| USB gadget shell | configfs CDC-ACM | ✅ | |
| eMMC | SDCC1, 8-bit non-removable | ✅ | |
| External SD | SDCC3 | ❌ | |
| RTC | PM8917/PM8xxx RTC | ✅ | Read/write persists across reboots; alarm IRQ delivery confirmed with `/dev/rtc0` ioctl test. |
| Charger / fuel gauge | PM8921 charger, BMS, Samsung sec-charger | ❌ | |
| Thermal | TSENS | ⚠️ | Probe currently oopses, so thermal work is descoped for now. |
| Touchscreen | Atmel maXTouch MXT224S | ❌ | |
| Touchkeys | Cypress touchkey | ❌ | |
| Haptics | PWM vibrator on GPIO 70, enable GPIO 63 | ❌ | |
| MUIC / USB switch | TSU6721 | ❌ | |
| NFC | NXP PN547 | ❌ | |
| ALS / proximity | TAOS / AMS sensor | ❌ | |
| Motion sensors | MPU6050/MPU6500, YAS532 | ❌ | |
| Display panel | Magna OLED WVGA over MIPI DSI | ❌ | |
| MHL / HDMI | Silicon Image SII9234 | ❌ | |
| Cameras | ISX012 rear, SR130PC20 front | ❌ | |
| Audio | WCD9304 / Sitar over SLIMbus | ❌ | |
| WLAN | Qualcomm WCNSS/Prima | ❌ | |
| Bluetooth | Qualcomm SMD transport | ❌ | |
| FM radio | Iris FM | ❌ | |
| U-Boot | Chain-loaded from lk2nd | ❌ | |

## Current Priorities

1. Keep the minimal boot path stable: UART, framebuffer, RPM/PMIC, USB gadget, eMMC, keys.
2. Add low-risk DT peripherals with existing mainline drivers: SDCC3, maXTouch, YAS532/MPU, TAOS light/prox.
3. Expand PM8917 regulators only when a modeled consumer needs a rail.
4. Leave MUIC/OTG, display, audio, cameras, charger/BMS, and TSENS for focused follow-up rounds.

## Useful Files

| File | Purpose |
| --- | --- |
| `RESEARCH.md` | Lightweight index for detailed `research/*.md` breadcrumbs. |
| `STATUS.md` | Detailed implementation state and next-work notes. |
| `AGENTS.md` | Workspace-specific bring-up notes and safety constraints. |
| `build-lk2nd-bootable.sh` | Normal direct `fastboot boot` image builder. |
| `build-lk2nd-userdata.sh` | lk2nd/extlinux userdata fallback image builder. |
| `build-dev-initrd.sh` | Static BusyBox initramfs and CDC-ACM gadget setup. |
| `linux/arch/arm/boot/dts/qcom/qcom-msm8930.dtsi` | Minimal MSM8930 SoC description. |
| `linux/arch/arm/boot/dts/qcom/qcom-msm8930-samsung-expressltexx.dts` | Expressltexx board description. |
| `linux/arch/arm/boot/dts/qcom/pm8917.dtsi` | PM8917 SSBI PMIC description. |
