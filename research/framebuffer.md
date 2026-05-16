# Framebuffer And Display Bring-Up

Use this file when reasoning about lk2nd continuous splash, simple-framebuffer, framebuffer reservation, or the later real display panel path.

## lk2nd Continuous Splash / Simple Framebuffer

Values currently used:

- Runtime lk2nd log from the device reports MDP DMA_P continuous splash at base `0x88a00000`, stride `1440`, size `480x800`, output origin `(0,0)`, config `0x100213f`, and extracted format `0x0`.
- lk2nd's DMA_P continuous-splash reader extracts format bits `26:25`; format `0x0` maps to RGB888, with `bpp = 24` and logical stride `stride_bytes / 3`.
- Mainline simple-framebuffer uses byte stride, so the DT keeps `stride = <1440>` and maps format `0x0`/RGB888 to `format = "r8g8b8"`.
- Framebuffer memory size is derived as `1440 * 800 = 1152000 = 0x119400` bytes.
- The framebuffer lies inside the current conservative RAM bank `0x80000000..0x9fffffff`, so DT also reserves `0x88a00000..0x88b19400` with `no-map`.

Sources:

- `lk2nd/lk2nd/display/cont-splash/dma.c:12-31` reads `MDP_DMA_P_BUF_ADDR`, `MDP_DMA_P_CONFIG`, `MDP_DMA_P_SIZE`, `MDP_DMA_P_BUF_Y_STRIDE`, `MDP_DMA_P_OUT_XY`, extracts format bits, and prints the continuous-splash log line.
- `lk2nd/lk2nd/display/cont-splash/dma.c:33-55` maps DMA_P format `0x0` to `FB_FORMAT_RGB888`, `bpp = 24`, and `stride = stride / 3`.
- `lk2nd/include/dev/fbcon.h:90-93` defines lk2nd `FB_FORMAT_RGB565`, `FB_FORMAT_RGB666`, `FB_FORMAT_RGB666_LOOSE`, and `FB_FORMAT_RGB888` constants.
- `linux/Documentation/devicetree/bindings/display/simple-framebuffer.yaml:90-119` documents simple-framebuffer byte stride and allowed formats including `r8g8b8`.
- `android_kernel_samsung_msm8930-common/arch/arm/mach-msm/board-8930-display.c:2418-2423` registers downstream panel device `mipi_magna`.
- `android_kernel_samsung_msm8930-common/drivers/video/msm/mipi_magna_oled_video_wvga_pt.c:654-704` defines Magna OLED resolution, timings, lane count, lane swap, clock rate, format, and frame rate.

Current use:

- `linux/arch/arm/boot/dts/qcom/qcom-msm8930-samsung-expressltexx.dts:14-43` adds `display0`, a `/chosen/framebuffer@88a00000` simple-framebuffer node, and a matching `reserved-memory` no-map region.
- `build-lk2nd-userdata.sh:221-231` and `build-lk2nd-bootable.sh:190-199` enable `CONFIG_FB_SIMPLE` for local bring-up images so the simple-framebuffer node creates an fbdev device.

Notes:

- `stdout-path` stays on `serial0` for now; the framebuffer is added for visual status and `/dev/fb0`, not as the primary console during early UART bring-up.
- Real display panel bring-up should use the Magna OLED facts in `research/peripherals.md` and the downstream display source ranges above.
