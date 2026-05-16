# Research Index

This file is intentionally small so it can stay in global agent context. Detailed source breadcrumbs live in `research/*.md`.

When adding or changing a non-obvious register address, register offset, bit value, derived clock, boot-image layout value, GPIO number, regulator fact, power rail, source-backed hardware fact, or similar magic value, update the most relevant `research/*.md` file in the same change.

## Topic Files

| Topic | File |
| --- | --- |
| MSM8930 vs MSM8960 identity, SoC naming, temporary GCC board-clock compatibility | `research/platform.md` |
| RPM, PM8917/PM8038 regulators, SSBI PMIC, PM8xxx power key | `research/pmic-rpm-regulators.md` |
| HSUSB1, integrated PHY, CDC-ACM gadget shell, static BusyBox initramfs | `research/usb-and-initramfs.md` |
| SDCC1/eMMC, SDCC3/external SD, storage supplies and DML/BAM facts | `research/storage.md` |
| Downstream peripheral inventory and mainline driver/binding clues | `research/peripherals.md` |
| lk2nd continuous splash, simple-framebuffer, display reservation | `research/framebuffer.md` |
| lk2nd boot image layout, direct `fastboot boot`, userdata/extlinux fallback, U-Boot boot.img wrapper | `research/boot-lk2nd.md` |
| UARTDM, GSBI5, MSM timer/DGT, U-Boot RAM assumptions | `research/uart-timer-uboot.md` |

## Status Files

| File | Purpose |
| --- | --- |
| `README.md` | Quick human status page and common build/boot commands. |
| `STATUS.md` | Detailed implementation state and next-work notes. |
| `AGENTS.md` | Workspace rules, source lookup guidance, and safety constraints. |
