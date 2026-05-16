# Expressltexx Display/KMS Enablement Plan

## Goal

Bring up the MSM8930 display pipeline far enough for mainline DRM/KMS to create a usable scanout path on the Samsung Galaxy Express GT-I8730 (`expressltexx`). The first success condition is a useful DRM/KMS probe result over UART or USB serial, ideally `/dev/dri/card0` with the Magna OLED panel attached, not full graphics acceleration.

## Current State

The local MSM8930 devicetree is still a minimal bring-up tree. It has CPU, timer, TLMM, RPM regulators, UART, eMMC, USB, a simple-framebuffer splash handoff, and temporary supplies, but it has no MMCC multimedia clock controller, MDP4, MDP IOMMUs, DSI host, DSI PHY, panel node, or panel driver.

GPU/render-node work is separable from KMS/display. The GPU plan should keep using `msm.separate_gpu_kms=1` until this display path can bind reliably.

## Source Facts

- Downstream express defconfig enables Qualcomm framebuffer, MDP4.0, Magna OLED WVGA panel support, and `MIPI_DSI_RESET_LP11`; see `android_kernel_samsung_msm8930-common/arch/arm/configs/samsung_express_defconfig:407-420`.
- Downstream framebuffer reserve sizing treats the Magna OLED panel as `800 * 480 * 4` pages, matching a 480x800 WVGA panel in portrait orientation; see `android_kernel_samsung_msm8930-common/arch/arm/mach-msm/board-8930-display.c:63-69` and `board-8930-display.c:115-121`.
- Downstream names the panel `SMD_AMS452GP32` and wires the Magna panel platform device as `mipi_magna`; see `android_kernel_samsung_msm8930-common/drivers/video/msm/mipi_magna_oled_video_wvga_pt.c:598-629` and `android_kernel_samsung_msm8930-common/arch/arm/mach-msm/board-8930-display.c:2418-2423`.
- Downstream panel mode is `480x800`, `24 bpp`, `MIPI_VIDEO_PANEL`, RGB888, burst video mode, 60 Hz, and `clk_rate = 343500000`; see `mipi_magna_oled_video_wvga_pt.c:654-701`.
- Downstream LCDC timing is hsync `4`, hbp `16`, hfp `80`, vsync `2`, vbp `4`, and vfp `10`; see `mipi_magna_oled_video_wvga_pt.c:663-668`.
- Downstream DSI lane setup enables lane 0 and lane 1 only, with `dlane_swap = 0x01`, `t_clk_post = 0x19`, and `t_clk_pre = 0x2d`; see `mipi_magna_oled_video_wvga_pt.c:687-694`.
- Downstream DSI PHY table contains regulator, timing, phy ctrl, strength, and PLL control values for this panel; see `mipi_magna_oled_video_wvga_pt.c:631-644`. These should be treated as debugging breadcrumbs, not copied into DT unless mainline exposes a matching binding or driver hook.
- Downstream panel init sequence sends DCS/vendor commands beginning with level 2 key unlock, sleep out, key commands, display control, LTPS timing, gamma, ELVSS, power control, NVM refresh off, EOT check disable, and display on; see `mipi_magna_oled_video_wvga_pt.c:160-206`.
- Downstream off sequence sends display off and sleep in/all pixels off variants; see `mipi_magna_oled_video_wvga_pt.c:207-235`.
- Downstream reset GPIO defaults to GPIO `58` for this panel selection; see `android_kernel_samsung_msm8930-common/arch/arm/mach-msm/board-8930-display.c:251-270`.
- Downstream Magna reset sequence waits 50 ms, drives reset low, waits 5 ms, drives reset high, then waits 50 ms; see `board-8930-display.c:295-306`.
- Downstream DSI power gets `dsi_vdda` from the DSI device and optionally gets `vlcd_1.8v` and `vlcd_2.8v`; it sets the optional rails to 1.8 V and 3.0 V; see `board-8930-display.c:1421-1466`.
- Downstream DSI power enables `dsi_vdda`, then optional `vlcd_1.8v`, then optional `vlcd_2.8v`, with 5 ms delays; see `board-8930-display.c:1495-1527`.
- Downstream DSI power disables `dsi_vdda`, optional `vlcd_1.8v`, then optional `vlcd_2.8v`; see `board-8930-display.c:1529-1558`.
- Downstream MIPI DSI controller MMIO base is `0x04700000`, size `0x000f0000`, and downstream MDP MMIO base is `0x05100000`, size `0x000f0000`; see `android_kernel_samsung_msm8930-common/arch/arm/mach-msm/devices-msm8x60.c:1496-1540`.
- Downstream `DSI_IRQ` and `INT_MDP` are raw `GIC_SPI_START + 82` and `GIC_SPI_START + 75`, which map to DT interrupts `GIC_SPI 82` and `GIC_SPI 75`; see `android_kernel_samsung_msm8930-common/arch/arm/mach-msm/include/mach/irqs-8x60.h:117-124`.
- Downstream MDP IOMMU bases are `0x07500000` and `0x07600000`, size 1 MiB, with raw IRQs `96/95` and `94/93`, which map to DT `GIC_SPI 64/63` and `GIC_SPI 62/61`; see `android_kernel_samsung_msm8930-common/arch/arm/mach-msm/devices-iommu.c:63-103`.
- Downstream MDP IOMMU context MIDs are `{0, 2}` for CB0 and `{1, 3, 4, 5, 6, 7, 8, 9, 10}` for CB1 on both MDP ports; see `devices-iommu.c:572-594`.
- Mainline APQ8064 has the closest legacy topology for `dsi@4700000`, `phy@4700200`, MDP IOMMUs, and `display-controller@5100000`; see `linux/arch/arm/boot/dts/qcom/qcom-apq8064.dtsi:1130-1194`, `qcom-apq8064.dtsi:1271-1301`, and `qcom-apq8064.dtsi:1432-1488`.
- Mainline MDP4 binding describes ports `0..3` as LCDC/LVDS, DSI1, DSI2, and DTV, and requires `compatible`, `reg`, `clocks`, and `ports`; see `linux/Documentation/devicetree/bindings/display/msm/mdp4.yaml:15-78`.
- Mainline APQ8064 DSI binding path requires SoC-specific `qcom,apq8064-dsi-ctrl`, fallback `qcom,mdss-dsi-ctrl`, `reg-names = "dsi_ctrl"`, one PHY, graph ports, and seven APQ8064 clock names; see `linux/Documentation/devicetree/bindings/display/msm/dsi-controller-main.yaml:13-63`, `dsi-controller-main.yaml:227-260`, and `dsi-controller-main.yaml:261-288`.
- Mainline 28 nm DSI PHY binding supports `qcom,dsi-phy-28nm-8960` and requires `dsi_pll`, `dsi_phy`, `dsi_phy_regulator`, and `vddio-supply`; see `linux/Documentation/devicetree/bindings/phy/qcom,dsi-phy-28nm.yaml:15-49`.
- Mainline MDP4 currently initializes only DSI ID `0` for the DSI encoder path; see `linux/drivers/gpu/drm/msm/disp/mdp4/mdp4_kms.c:263-286`.
- Mainline DSI host reads `data-lanes` from the DSI output endpoint and maps lane swaps through the supported physical/logical table; see `linux/drivers/gpu/drm/msm/dsi/dsi_host.c:1788-1866`.
- `msm8227-mainline/msm8227-6.19` currently does not provide reusable MSM8930 KMS enablement for this board class: `qcom-msm8930-samsung-loganrelte.dts` still has a TODO to enable the screen, and `qcom-msm8930-samsung-serranolte.dts` uses simple-framebuffer only.

## First-Cut Strategy

Use a staged KMS bring-up. Do not remove the simple-framebuffer path until the real MDP4/DSI/panel graph probes cleanly and produces useful logs.

The first DTS pass should add display blocks disabled by default in `qcom-msm8930.dtsi`:

- Add `#include <dt-bindings/clock/qcom,mmcc-msm8960.h>` if not already added by GPU work.
- Add `mmcc: clock-controller@4000000` using `compatible = "qcom,mmcc-msm8960"`; share this with GPU work if that lands first.
- Add `mmss_sfpb: syscon@5700000` using the APQ8064-style MMSS SFPB node if DSIv2 access requires it.
- Add `mdp_port0: iommu@7500000` and `mdp_port1: iommu@7600000` using `compatible = "qcom,apq8064-iommu"`, `qcom,ncb = <2>`, clocks `SMMU_AHB_CLK` and `MDP_AXI_CLK`, and the downstream-derived interrupt pairs.
- Add `mdp: display-controller@5100000` using `compatible = "qcom,mdp4"`, reg `0x05100000 0xf0000`, IRQ `GIC_SPI 75`, MMCC clocks matching APQ8064, and `iommus = <&mdp_port0 0>, <&mdp_port0 2>, <&mdp_port1 0>, <&mdp_port1 2>` as the conservative APQ8064/mainline subset.
- Add MDP4 ports and wire only `port@1` for DSI1 in the first active graph.
- Add `dsi0: dsi@4700000` using `compatible = "qcom,apq8064-dsi-ctrl", "qcom,mdss-dsi-ctrl"`, reg `0x04700000 0x200`, IRQ `GIC_SPI 82`, APQ8064 clock names, `syscon-sfpb`, `phys = <&dsi0_phy>`, and graph ports `port@0` and `port@1`.
- Add `dsi0_phy: phy@4700200` using `compatible = "qcom,dsi-phy-28nm-8960"`, APQ8064-style register windows, clock names `iface` and `ref`, `#clock-cells = <1>`, and `#phy-cells = <0>`.
- Keep all new SoC display blocks `status = "disabled"` in the SoC `.dtsi`, then enable only the required nodes in the board DTS.

The first board DTS pass should describe the panel graph and conservative panel power/reset:

- Add a TLMM pinctrl state for GPIO `58` as output, no pull, low drive strength, for panel reset.
- Enable `&mdp`, `&dsi0`, and `&dsi0_phy`.
- Wire `&mdp_dsi1_out` to `&dsi0_in`, and `&dsi0_out` to the panel input endpoint.
- Add a DSI child panel node under `&dsi0` with a new compatible such as `samsung,ams452gp32-magna` or a more precise name once confirmed.
- Use `reset-gpios = <&tlmm 58 GPIO_ACTIVE_LOW>` or driver-specific polarity that reproduces downstream low-then-high reset timing.
- Use two DSI lanes. Translate downstream `dlane_swap = 0x01` carefully into mainline `data-lanes`; first try the lane mapping that makes mainline choose swap index `1`, then fall back to unswapped `<0 1>` if the host rejects or the panel stays dark.
- Add supplies only when the PMIC/regulator nodes are ready. Do not fake panel rails as always-on unless needed for a probe experiment and documented as temporary.
- Preserve `framebuffer0` until the KMS path proves it can take over.

The first panel driver pass should be minimal:

- Add a new DRM MIPI DSI panel driver under `linux/drivers/gpu/drm/panel/`.
- Set `dsi->lanes = 2`, `dsi->format = MIPI_DSI_FMT_RGB888`, and mode flags matching video burst mode and no EOT packet if needed by downstream `tx_eot_append = FALSE`.
- Define one fixed `drm_display_mode` for 480x800 at 60 Hz using downstream porch and sync values.
- Implement `prepare()` with regulator enable, reset sequence, and the downstream `samsung_display_on_cmds` subset.
- Implement `unprepare()` with display off, sleep in, reset low, and regulator disable.
- Start without smart dimming, MTP reads, dynamic gamma tables, ACL, ELVSS recalculation, ESD refresh, or LCD class devices. Add only what is required to get pixels.
- Keep gamma and ELVSS command bytes as static downstream-derived init bytes for first light; do not port downstream smart-dimming logic initially.
- Add `Kconfig` and `Makefile` entries for the panel, built-in for the initramfs test path.

The panel generator is useful as a formatting reference, but not as a direct source conversion path. It expects Qualcomm MDSS DSI panel devicetree data or a compiled DTB, while expressltexx downstream panel data is old board-file C arrays.

## Config And Build Requirements

- Build `DRM_MSM=y`; modules are not installed into the current initramfs.
- Enable MDP4/DSI dependencies that `DRM_MSM` needs for MDP4 and MSM DSI.
- Enable `MSM_IOMMU=y` and `MSM_MMCC_8960=y` if not already enabled by GPU work.
- Enable the new panel driver built-in.
- Keep simple-framebuffer support enabled during early KMS experiments.
- Build with `./build-lk2nd-bootable.sh` and boot with `fastboot boot out/expressltexx/expressltexx-boot.img` once USB gadget/fastboot workflow is available.

## Test Procedure

Initial boot should use UART and USB serial logs. Do not rely on the panel visually lighting up as the only success signal.

Check logs for:

- `mmcc-msm8960` probe success.
- `msm_iommu` probe for `0x07500000` and `0x07600000` with two context banks each.
- `mdp4` probe success at `0x05100000`.
- DSI host probe at `0x04700000` and DSI PHY probe at `0x04700200`.
- Panel driver probe and `mipi_dsi_attach()` success.
- Absence of graph errors from missing MDP/DSI/panel endpoints.
- Absence of deferred probe loops for regulators that are not yet modeled.
- `/dev/dri/card0` appearing.

Useful manual checks from the initramfs shell:

```sh
ls -l /dev/dri
dmesg | grep -i -E 'drm|mdp|dsi|panel|kms|iommu|mmcc|probe|defer'
```

If `/dev/dri/card0` appears but the panel is dark, keep collecting logs before changing power sequencing. The first likely suspects are panel supplies, reset polarity/timing, DSI lane mapping, and DSI clock/PHY programming.

## Expected Failure Points

- Regulator dependencies: the panel may need LP8720-derived `vlcd_1.8v` and `vlcd_2.8v`, which are not currently modeled in the board DTS.
- Reset polarity and timing: downstream uses raw GPIO writes rather than a declarative reset line, so the panel driver must reproduce the low/high sequence exactly enough.
- Lane swap: downstream `dlane_swap = 0x01` must be translated into mainline `data-lanes`, and the intuitive two-lane mapping may not be the working one.
- DSI PLL/PHY programming: downstream carries explicit PHY database bytes, while mainline derives 28 nm PHY timings. If the panel never receives commands, this is a prime suspect.
- MMCC display clocks: `qcom,mmcc-msm8960` may need MSM8930-specific fixes, especially around DSI pixel, MDP, and LUT clocks. The MSM8227 branch has WIP register writes that are clues only, not upstreamable code to copy blindly.
- Power domains/footswitches: downstream has MMSS footswitch behavior for display/GPU blocks. If MMIO accesses hang or clocks enable but hardware does not respond, this needs investigation.
- Component binding: MDP4/DSI/panel graph endpoints must be complete or `drm/msm` can defer indefinitely.
- Simple-framebuffer handoff: keep the simple framebuffer until KMS is reliable; removing it too early loses visual fallback.

## Follow-Up Work

- Confirm actual panel ID from downstream Android or DSI reads once DSI commands work.
- Decide whether the upstream-compatible panel name should be `samsung,ams452gp32`, `samsung,ea8868`, or a more precise module name.
- Add proper LP8720/regulator modeling if the panel rails are confirmed necessary.
- Add backlight/brightness support after first light, likely starting with DCS brightness or static gamma levels rather than downstream smart dimming.
- Add optional ACL/ELVSS/gamma/MTP support only after basic scanout is stable.
- Remove `msm.separate_gpu_kms=1` once GPU and KMS can coexist in normal DRM component binding.
- Record any new magic values or derived behavior in the relevant `research/*.md` file in the same change that introduces them to DTS, driver code, or build scripts.
