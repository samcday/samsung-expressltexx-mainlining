# Expressltexx GPU Enablement Plan

## Goal

Bring up the MSM8930/Adreno GPU far enough to create a DRM render node on the Samsung Galaxy Express GT-I8730 (`expressltexx`). The first success condition is a useful probe result over UART or USB serial, ideally `/dev/dri/renderD*`, not accelerated display.

## Current State

The local MSM8930 devicetree is still a minimal bring-up tree. It has CPU, timer, TLMM, RPM regulators, UART, eMMC, and USB, but no MMCC multimedia clock controller, GPU, GPU IOMMU, MDSS/MDP, or display pipeline.

The current boot flow uses an initramfs built by `build-dev-initrd.sh`, with eMMC and USB gadget support available. That makes a headless GPU probe practical before display work.

## Source Facts

- Downstream GPU MMIO is `0x04300000..0x0430ffff`, shader memory is `0x04310000..0x0431ffff`, and the GPU IRQ is `GFX3D_IRQ`; see `android_kernel_samsung_msm8930-common/arch/arm/mach-msm/board-8930-gpu.c:87-106`.
- Downstream GPU IOMMU base is `0x07c00000`, size 1 MiB; see `board-8930-gpu.c:108-120` and `android_kernel_samsung_msm8930-common/arch/arm/mach-msm/devices-iommu.c:210-229`.
- Downstream GFX3D IOMMU contexts split MIDs `0..15` for `gfx3d_user` and `16..31` for `gfx3d_priv`; see `devices-iommu.c:650-660`.
- Downstream GPU power levels are `400 MHz`, `320 MHz`, `192 MHz`, and `27 MHz`; AA raises top to `450 MHz`, AB raises top to `500 MHz`; see `board-8930-gpu.c:122-145` and `board-8930-gpu.c:167-190`.
- Downstream chip IDs are `ADRENO_CHIPID(3, 0, 5, 0)`, `ADRENO_CHIPID(3, 0, 5, 2)`, or `ADRENO_CHIPID(3, 0, 5, 3)` depending on SoC revision; see `board-8930-gpu.c:180-188`.
- Downstream GFX3D clock tables include `27 MHz`, `192 MHz`, `320 MHz`, `400 MHz`, `450 MHz`, and AB-only `500 MHz`; see `android_kernel_samsung_msm8930-common/arch/arm/mach-msm/clock-8960.c:3514-3577` and `clock-8960.c:3592-3608`.
- Downstream footswitch data names the GFX3D clocks as `core_clk`, `iface_clk`, and `bus_clk`; see `android_kernel_samsung_msm8930-common/arch/arm/mach-msm/devices-8930.c:707-715`.
- Downstream GFX3D footswitch control is `MMSS_CLK_CTL_BASE + 0x0188`, with clamp, enable, and retention bits, plus an extra GFX3D core reset toggle after first power-on; see `android_kernel_samsung_msm8930-common/arch/arm/mach-msm/footswitch-8x60.c:37-57` and `footswitch-8x60.c:197-205`.
- Android lists `a300_pfp.fw` and `a300_pm4.fw`; see `android_device_samsung_expressltexx/proprietary-files.txt:14-17`.
- On the device, the first-cut firmware source is `/etc/firmware/a300_pfp.fw` and `/etc/firmware/a300_pm4.fw` on `/dev/mmcblk0p14`.
- Mainline APQ8064 has the closest legacy topology example for `gpu@4300000` and `iommu@7c00000`; see `linux/arch/arm/boot/dts/qcom/qcom-apq8064.dtsi:1028-1123` and `qcom-apq8064.dtsi:1303-1317`.
- Mainline MSM8226 has an Adreno 305 binding example with three clocks named `core`, `iface`, and `mem_iface`; see `linux/arch/arm/boot/dts/qcom/qcom-msm8226.dtsi:1307-1344` and `linux/Documentation/devicetree/bindings/display/msm/gpu.yaml:143-163`.
- Mainline `drm/msm` parses `qcom,adreno-XYZ.W` into a chip ID, but the A3xx catalog does not currently list MSM8930's exact IDs; see `linux/drivers/gpu/drm/msm/adreno/adreno_device.c:142-180` and `linux/drivers/gpu/drm/msm/adreno/a3xx_catalog.c:12-34`.
- Mainline Adreno firmware lookup tries `qcom/$file` first, then the legacy root firmware path; see `linux/drivers/gpu/drm/msm/adreno/adreno_gpu.c:520-565`.
- Mainline MSM DRM loads the GPU lazily on DRM open, which lets the initramfs copy firmware before the first render-node open; see `linux/drivers/gpu/drm/msm/msm_drv.c:267-272`.

## First-Cut Strategy

Use a conservative, headless GPU probe. Do not attempt display acceleration yet.

The first DTS pass should describe the hardware blocks needed for GPU probe only:

- Add `#include <dt-bindings/clock/qcom,mmcc-msm8960.h>` to `qcom-msm8930.dtsi`.
- Add `mmcc: clock-controller@4000000` using `compatible = "qcom,mmcc-msm8960"`.
- Add `gfx3d: iommu@7c00000` using `compatible = "qcom,apq8064-iommu"`, `reg = <0x07c00000 0x100000>`, IRQs `GIC_SPI 69` and `GIC_SPI 70`, clocks `SMMU_AHB_CLK` and `GFX3D_AXI_CLK`, and `qcom,ncb = <3>`.
- Add `gpu: gpu@4300000` using `compatible = "qcom,adreno-305.0", "qcom,adreno"`, `reg = <0x04300000 0x10000>`, IRQ `GIC_SPI 80`, clocks `GFX3D_CLK`, `GFX3D_AHB_CLK`, and `GFX3D_AXI_CLK`, and clock names `core`, `iface`, and `mem_iface`.
- Add 32 IOMMU stream IDs, `0..31`, against `&gfx3d`.
- Add conservative OPPs only: `27 MHz`, `320 MHz`, and `400 MHz`. Leave `450 MHz` and `500 MHz` disabled until exact SoC revision is confirmed.
- Keep the GPU disabled in the SoC `.dtsi` and enable it from `qcom-msm8930-samsung-expressltexx.dts`.

The first driver pass should only make the existing A3xx support recognize MSM8930:

- Add A305 catalog entries or chip IDs for `0x03000500`, `0x03000502`, and `0x03000503` in `a3xx_catalog.c`.
- Use `a300_pm4.fw`, `a300_pfp.fw`, GMEM `SZ_256K`, and `revn = 305`, matching the existing A305 entry style.
- Avoid new SoC-specific driver behavior unless the first probe proves it is required.

The first build/initrd pass should make the test self-contained:

- Force `DRM_MSM=y`; the default `qcom_defconfig` has `DRM_MSM=m`, but the current initramfs does not install modules.
- Keep `MSM_IOMMU=y` and `MSM_MMCC_8960=y` enabled.
- Force `EXT4_FS=y` so the initramfs can mount the firmware partition if needed.
- Add `msm.separate_gpu_kms=1` to the debug cmdline for headless GPU testing before MDP/display is described.
- In `build-dev-initrd.sh`, wait for `/dev/mmcblk0p14`, mount it read-only, and copy `/etc/firmware/a300_pfp.fw` and `/etc/firmware/a300_pm4.fw` into `/lib/firmware/qcom/`.
- Add the BusyBox `cp` applet symlink to the initramfs spec.
- Log firmware-copy success or failure to `/dev/kmsg`.

## Test Procedure

Build with the bootable image helper:

```sh
./build-lk2nd-bootable.sh
```

Boot through lk2nd:

```sh
fastboot boot out/expressltexx/expressltexx-boot.img
```

Check UART or USB-serial logs for:

- `mmcc-msm8960` probe success.
- `msm_iommu` probe for `0x07c00000` with 3 context banks.
- initramfs firmware copy messages.
- absence of `Unknown GPU revision` for `305.0`.
- absence of missing firmware errors for `qcom/a300_pm4.fw` and `qcom/a300_pfp.fw` after first DRM open.
- `/dev/dri/renderD*` appearing.

Useful manual checks from the initramfs shell:

```sh
ls -l /lib/firmware/qcom
ls -l /dev/dri
dmesg | grep -i -E 'adreno|drm|gpu|iommu|firmware|mmcc'
```

If `/dev/dri/renderD*` appears but the GPU has not initialized yet, trigger lazy load with a simple open from userspace once a suitable tool exists in the initramfs. Otherwise, inspect the first DRM open failure in `dmesg`.

## Expected Failure Points

- Firmware partition timing: `/dev/mmcblk0p14` may appear after the first initrd copy attempt. The init script should wait and log retries.
- Filesystem type: downstream fstab maps the modem firmware partition to vfat, while the user-observed path is `/etc/firmware` on `/dev/mmcblk0p14`. The init script should try the known working filesystem first, then a narrow fallback if needed.
- Headless component binding: without `msm.separate_gpu_kms=1`, `drm/msm` may wait for missing display components.
- Power domain or footswitch: mainline MMCC exposes clocks but not the downstream GFX3D footswitch behavior. If GPU MMIO reads hang, runtime resume fails, or hardware init times out, this is the first suspect.
- IOMMU stream mapping: APQ8064 style may work, but MSM8930 only has one GFX3D IOMMU instance downstream. Keep the initial mapping to `&gfx3d 0..31`, not APQ8064's two-IOMMU list.
- Clock table mismatch: mainline `qcom,mmcc-msm8960` does not expose AB-only `500 MHz`. Avoid turbo until the base probe is stable.
- SoC revision uncertainty: `qcom,adreno-305.0` is the safest first compatible, but real hardware may report or require `.2` or `.3` semantics.

## Follow-Up Work

- Move firmware handling from the ad hoc initrd copy to droid-juicer extraction and proper firmware packaging.
- Confirm exact SoC revision from boot logs, SMEM/socinfo, or downstream Android.
- Add 450 MHz or 500 MHz OPPs only after revision confirmation and clock support review.
- Investigate mainline representation for the GFX3D footswitch/power domain if probe fails after clocks and IOMMU are described.
- Add display/MMSS/MDP/DSI separately; do not block render-node GPU bring-up on panel enablement.
- Once stable, remove `msm.separate_gpu_kms=1` and integrate GPU with the normal DRM display device.
- Record any new magic values or derived behavior in the relevant `research/*.md` file in the same change that introduces them to DTS, driver code, or build scripts.
