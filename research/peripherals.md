# Peripheral Inventory

Use this file when reasoning about board peripherals not yet fully modeled in mainline DT, including keys, touchscreen, touchkeys, sensors, MUIC, NFC, haptics, display panel, cameras, audio, WLAN/Bluetooth/FM, charger/BMS, and Express ATT comparisons.

## Expressltexx Downstream Peripheral Inventory

Values currently known:

- Current mainline `qcom-msm8930.dtsi` has clocks, TLMM, RPM, SSBI, SDCC1/eMMC, SDCC3/external SD, GSBI5 UART, USB HS1, TSENS, and CPU/timer plumbing. Most peripherals below are downstream hardware facts, not yet modeled in Linux DT.
- Physical keys are active-low GPIO keys: volume up GPIO 50, volume down GPIO 81, home GPIO 35. Downstream reports volume as `KEY_VOLUMEUP`/`KEY_VOLUMEDOWN` and home as `KEY_HOMEPAGE`; home is wake-capable downstream and all use 5 ms debounce. Downstream gpiomux uses GPIO function, 8 mA drive, and pull-up while active.
- Touchscreen is Atmel maXTouch `MXT224S` on GSBI3 I2C bus ID 3, I2C address `0x4a`, IRQ GPIO 11, logical range X `0..479`, Y `0..799`, firmware/config tag `I8730_AT_1226`. This is specifically Express / GT-I8730 board data, not just an expressatt inference. Newer Express board revs use regulators `8917_lvs6` for 1.8 V and `8917_l31` set to 3.3 V; older revs use GPIO 79 (`GPIO_TSP_D_EN`) and GPIO 80 (`GPIO_TSP_A_EN`).
- Touchkeys are Cypress capacitive Menu/Back touchkeys on a bitbanged I2C bus ID 16, I2C address `0x20`, IRQ GPIO 65, keycodes `KEY_MENU` and `KEY_BACK`. Android declares hardware Home+Back+Menu+Volume keys, and downstream exposes `/sys/class/sec/sec_touchkey`, so the device appears to have capacitive touchkeys even if their legends/backlight are not currently visible. Newer revs use bitbang SDA/SCL GPIO 24/25 plus `8917_lvs5` for 1.8 V, `8917_l30` set to 2.8 V, and LED regulator `8917_l33` set to 3.3 V; older revs use SDA/SCL GPIO 71/72, LDO enable GPIO 99, and LED GPIO 51.
- Haptics use the downstream Immersion/Vibetonz `tspdrv` platform device with `HAPTIC_PWM`, PWM GPIO 70, enable GPIO 63, `is_pmic_vib_en = 0`, `is_pmic_haptic_pwr_en = 0`, and `is_no_haptic_pwr = 1`. This is not the PMIC vibrator path.
- MUIC / micro-USB switch is `TSU6721`, bitbanged I2C bus ID 15, SDA GPIO 73, SCL GPIO 74, I2C address `0x4a >> 1` = `0x25`, IRQ GPIO 14. Downstream cable callbacks report USB, AC, UART/JIG, CDP, OTG, audio dock, car dock, desk dock, and incompatible chargers into OTG and battery state.
- NFC is NXP `PN547` on bitbanged I2C bus ID 17, SDA GPIO 95, SCL GPIO 96, I2C address `0x2b`, IRQ GPIO 106, VEN/enable GPIO 48, firmware GPIO 92, optional clock-request GPIO 90. Expressatt is only a partial reference here: it has an NFC device at `0x2b` with IRQ GPIO 106, but models a PN544-style compatible and different enable wiring.
- ALS/proximity sensor is downstream `taos` / TAOS Triton at I2C address `0x39` on bitbanged bus ID 14, SDA GPIO 12, SCL GPIO 13, proximity IRQ GPIO 49. Sensor rails are `sensor_opt` set to 2.85 V and `sensor_pwr` at 1.8 V; prox LED uses `8917_l16` set to 3.0 V on board rev >= 03 or GPIO 89 on older revs.
- Motion sensors are InvenSense MPU6050 at I2C address `0x68` and MPU6500 downstream dummy address `0x62`, IRQ GPIO 67, with orientation matrix `{ 0, 1, 0, -1, 0, 0, 0, 0, 1 }`. Magnetometer is Yamaha YAS532-compatible downstream name `geomagnetic` at I2C address `0x2e`.
- MHL/HDMI bridge is Silicon Image `SII9234` on bitbanged I2C GPIO 8/9, bus ID `MSM_MHL_I2C_BUS_ID`, with addresses `0x72 >> 1`, `0x7a >> 1`, `0x92 >> 1`, and `0xc8 >> 1`. Control GPIOs are reset GPIO 1, enable GPIO 2, wake GPIO 77, interrupt GPIO 78, select GPIO 82; regulators are `8917_l12` 1.2 V, `8917_l35` 3.3 V, and `8917_lvs7`.
- Display panel is downstream `mipi_magna`, enabled by `CONFIG_FB_MSM_MIPI_MAGNA_OLED_VIDEO_WVGA_PT_PANEL` in the Express defconfig. Panel timing is 480x800, RGB888, 24 bpp, 60 Hz, MIPI DSI video burst mode, 2 data lanes, `dlane_swap = 0x01`, clock rate `343500000`, hsync pulse/back/front `4/16/80`, vsync pulse/back/front `2/4/10`, backlight range `1..255`.
- Camera config enables `MT9M114`, `OV2720`, `ISX012`, and `SR130PC20`. Concrete Express board data describes rear `ISX012` at I2C address `0x3d`, CSI0, 2 lanes (`lane_mask = 0x3`), mount angle 90, reset GPIO 107, standby GPIO 54, flash GPIOs 3 and 64, MCLK GPIO 5. Front `SR130PC20` is at I2C address `0x20`, CSI1, 1 lane (`lane_mask = 0x1`), mount angle 270, and uses main MCLK GPIO 5 on `CONFIG_MACH_EXPRESS`.
- Camera GPIO and rail facts: flash GPIO 3, main MCLK GPIO 5, camera core enable GPIO 6, camera I2C SDA/SCL GPIO 20/21, camera IO enable GPIO 34, camera analog enable GPIO 38, AF enable GPIO 66, VT standby GPIO 18, main standby GPIO 54, front reset GPIO 76, main reset GPIO 107. Power sequencing uses `GPIO_CAM_CORE_EN` for 5M core 1.2 V, `8917_l34` for sensor IO 1.8 V, `8917_l32` for sensor AVDD 2.8 V, and `8917_l11` for rear AF 2.8 V.
- Audio codec is Qualcomm WCD9304/Sitar over SLIMbus bus 1, with downstream `sitar-slim` / `sitar1p1-slim`, IRQ GPIO 62, reset GPIO 42, and supplies including `CDC_VDD_CP` 2.2 V, RX/TX/VDDIO rails at 1.8 V, and digital/analog 1.2-1.25 V rails.
- WLAN is Qualcomm WCNSS/Prima at downstream MMIO `0x03000000` size `0x280000`, 5-wire GPIOs 84-88, and `has_48mhz_xo = 1`. Android exposes Wi-Fi as `wlan0`; Bluetooth transport is Qualcomm SMD.
- FM uses downstream platform device `iris_fm`. Android ships `fm_qsoc_patches` and runs `init.qcom.fm.sh` for FM setup.
- Charger/fuel/battery path uses PM8921 charger/BMS/sec-charger configs with charging current table entries including USB `500/475` mA, AC `1000/1500` mA, CDP `1000/1500` mA, OTG `0/0`; max battery voltage `4350` mV; term current `60` mA; USB max current `1000` mA; sense resistor `10000` uOhm; connector resistance `45` mOhm. Battery data is `Samsung_8930_Express2_2000mAh_data` with FCC `2000` mAh, default rbatt `166` mOhm, capacitive rbatt `60` mOhm.
- TSENS uses the MSM8960-family GCC/syscon register block, but Express downstream treats it as APQ8064-style TSENS with 10 sensors. Downstream slopes are `{1132, 1135, 1137, 1135, 1157, 1142, 1124, 1153, 1175, 1166}`, thermal mitigation polls sensor 9 every 250 ms, limits at 60 C with 10 C hysteresis, and TSENS calibration bytes are read from QFPROM offsets `0x404` and `0x414`. The upper/lower interrupt is `GIC_SPI 178`; APQ8064-style status/control bits live at GCC offset `0x3660`; sensors 5-9 use status registers through offset `0x3674`. MSM8930 setup must enable all 10 sensors before registering thermal zones because the thermal core reads temperature during registration, before per-zone enable callbacks would run. It must also deassert `SW_RST` after the reset pulse; leaving bit 1 set in `CNTL_ADDR` holds conversions in reset and makes sensor status read as zero. Hardware validation shows the oops is gone and sensor 9 reports plausible temperatures that rise under sustained CPU load and steadily fall after the system returns to idle, though absolute calibration remains unproven.
- Mainline `samsung-expressatt` overlap is strongest for maXTouch (`atmel,maxtouch` at `0x4a`, IRQ GPIO 11), partial for GPIO keys (volume GPIOs 50/81 match but home is GPIO 40 on expressatt vs GPIO 35 on expressltexx), partial for NFC (`PN544` upstream expressatt vs downstream `PN547` expressltexx, both at `0x2b` and IRQ GPIO 106, but enable wiring differs), and partial for sensors (YAS532 matches, ALS/prox is same broad AMS/TAOS family, accelerometer/gyro differs). Expressatt currently has no modeled touchkey node and should not be treated as proof that Expressltexx lacks touchkeys.

Sources:

- `linux/arch/arm/boot/dts/qcom/qcom-msm8930.dtsi:87-295` currently contains RPM, SSBI, SDCC1, GSBI5 UART, USB HS1, and supporting minimal SoC nodes.
- `android_kernel_samsung_msm8930-common/arch/arm/mach-msm/include/mach/express-gpio.h:23-129` defines Express GPIO numbers for camera, touchscreen, keys, touchkeys, vibrator, MUIC, NFC, sensors, MHL, audio, and OTG-related lines.
- `android_kernel_samsung_msm8930-common/arch/arm/mach-msm/devices-msm8x60.h:27-60` defines Express-related downstream I2C bus IDs: geomagnetic 11, sensors 12, optical 14, TSU6721 15, and NFC 17.
- `android_kernel_samsung_msm8930-common/arch/arm/configs/samsung_express_defconfig:273-326` enables TSU6721, PN547, GPIO keys, Cypress touchkey, and MXT224S touchscreen.
- `android_device_samsung_expressltexx/BoardConfig.mk:40-42` selects `samsung_express_defconfig` plus the tiny `msm8930_express_eur_lte_defconfig` variant for expressltexx builds.
- `android_device_samsung_expressltexx/overlay/lineage-sdk/lineage/res/res/values/config.xml:19-45` declares hardware Home, Back, Menu, and Volume keys, with Home and Volume wake keys.
- `android_device_samsung_expressltexx/rootdir/init.target.rc:407-413` configures `/sys/class/sec/sec_touchkey` permissions for touchscreen/touchkey controls.
- `android_kernel_samsung_msm8930-common/arch/arm/configs/samsung_express_defconfig:332-336` enables MPU6050 and MPU6500 input drivers.
- `android_kernel_samsung_msm8930-common/arch/arm/configs/samsung_express_defconfig:356-373` enables PM8921 charger/BMS/sec-charger, PM8xxx support, and WCD9304 codec.
- `android_kernel_samsung_msm8930-common/arch/arm/configs/samsung_express_defconfig:387-417` enables MSM camera sensors, Iris FM, MHL, and Magna OLED panel.
- `android_kernel_samsung_msm8930-common/arch/arm/configs/samsung_express_defconfig:491-530` enables USB host/gadget/OTG support.
- `android_kernel_samsung_msm8930-common/arch/arm/configs/samsung_express_defconfig:572-579` enables Vibetonz, YAS532 magnetometer, TAOS optical sensor, and sensor symlink support.
- `android_kernel_samsung_msm8930-common/arch/arm/configs/samsung_express_defconfig:363-366` enables downstream thermal support including `CONFIG_THERMAL_TSENS8960`.
- `android_kernel_samsung_msm8930-common/arch/arm/mach-msm/board-express.c:2898-2917` defines Express TSENS platform data: factor `1000`, `APQ_8064` hardware type, 10 sensors, per-sensor slopes, and thermal mitigation on sensor 9 with 60 C limit and 10 C hysteresis.
- `android_kernel_samsung_msm8930-common/arch/arm/mach-msm/board-express.c:3817-3819` calls `msm_tsens_early_init()` and `msm_thermal_init()` during board initialization.
- `android_kernel_samsung_msm8930-common/drivers/thermal/msm8960_tsens.c:45-46` defines TSENS QFPROM calibration offsets `0x404` and `0x414`; `msm8960_tsens.c:101-134` defines config/status register offsets including APQ8064 status control at GCC offset `0x3660`; `msm8960_tsens.c:895-921` reads per-sensor calibration bytes.
- `android_kernel_samsung_msm8930-common/arch/arm/mach-msm/include/mach/msm_iomap-8930.h:109` defines MSM8930 QFPROM physical base `0x00700000`.
- `android_kernel_samsung_msm8930-common/arch/arm/mach-msm/include/mach/irqs-8930.h:221` defines `TSENS_UPPER_LOWER_INT` as `GIC_SPI_START + 178`.
- `android_kernel_samsung_msm8930-common/arch/arm/mach-msm/board-express.c:277-453` defines TSU6721 bitbang I2C, address, IRQ, and cable callbacks.
- `android_kernel_samsung_msm8930-common/drivers/misc/tsu6721.c:1-45` identifies the downstream driver as TSU6721 and gives device ID constants `0x0a` and rev `0x12`.
- `android_kernel_samsung_msm8930-common/arch/arm/mach-msm/board-express.c:496-665` defines SII9234 MHL GPIOs, regulators, reset sequence, and four I2C client addresses.
- `android_kernel_samsung_msm8930-common/arch/arm/mach-msm/board-express.c:678-715` defines MPU6050/MPU6500 and geomagnetic I2C board info plus the MPU orientation matrix and calibration file paths.
- `android_kernel_samsung_msm8930-common/arch/arm/mach-msm/board-express.c:718-783` defines sensor power regulators `sensor_opt` and `sensor_pwr`.
- `android_kernel_samsung_msm8930-common/arch/arm/mach-msm/board-express.c:786-924` defines TAOS optical sensor bus, address, thresholds, IRQ, and prox LED power path.
- `android_kernel_samsung_msm8930-common/arch/arm/mach-msm/board-express.c:928-983` defines PN547 I2C bus, address, IRQ, VEN, firmware, and optional clock request GPIOs.
- `android_kernel_samsung_msm8930-common/arch/arm/mach-msm/board-express.c:2673-2715` defines active-low volume/home GPIO key data and home wakeup behavior.
- `android_kernel_samsung_msm8930-common/arch/arm/mach-msm/board-express-gpiomux.c:752-786` defines the key pins as GPIO function, 8 mA drive, and active-state pull-up.
- `android_kernel_samsung_msm8930-common/arch/arm/mach-msm/board-express.c:3116-3132` defines the Vibetonz `tspdrv` haptic PWM platform data.
- `android_kernel_samsung_msm8930-common/arch/arm/mach-msm/board-8930-input-mxt.c:448-550` defines Express maXTouch board-revision-dependent power sequencing.
- `android_kernel_samsung_msm8930-common/arch/arm/mach-msm/board-8930-input-mxt.c:552-595` defines maXTouch platform data, address `0x4a`, IRQ GPIO 11, dimensions, and firmware/config tag.
- `android_kernel_samsung_msm8930-common/arch/arm/mach-msm/board-8930-input-tkey.c:408-650` defines Cypress touchkey power, LED, address `0x20`, IRQ GPIO 65, keycodes, and bitbanged I2C GPIO selection by board revision.
- `android_kernel_samsung_msm8930-common/arch/arm/mach-msm/board-8930-display.c:2418-2423` registers downstream panel device `mipi_magna`.
- `android_kernel_samsung_msm8930-common/drivers/video/msm/mipi_magna_oled_video_wvga_pt.c:654-704` defines Magna OLED resolution, timings, lane count, lane swap, clock rate, format, and frame rate.
- `android_kernel_samsung_msm8930-common/arch/arm/mach-msm/board-8930-camera-power.c:45-84` defines Express camera GPIO mux setup.
- `android_kernel_samsung_msm8930-common/arch/arm/mach-msm/board-8930-camera-power.c:116-206` defines Express camera rail sequencing and regulator names.
- `android_kernel_samsung_msm8930-common/arch/arm/mach-msm/board-8930-camera.c:1152-1193` defines rear ISX012 board data.
- `android_kernel_samsung_msm8930-common/arch/arm/mach-msm/board-8930-camera.c:1277-1318` defines front SR130PC20 board data.
- `android_kernel_samsung_msm8930-common/arch/arm/mach-msm/board-8930-camera.c:2037-2066` defines SR130PC20 and ISX012 I2C addresses.
- `android_kernel_samsung_msm8930-common/arch/arm/mach-msm/board-8930.c:646-805` defines WCD9304/Sitar SLIMbus devices, IRQ/reset GPIOs, and codec supply requirements.
- `android_kernel_samsung_msm8930-common/arch/arm/mach-msm/board-8930.c:807-847` defines WCNSS WLAN MMIO, IRQ resources, 5-wire GPIO range, and 48 MHz XO flag.
- `android_kernel_samsung_msm8930-common/arch/arm/mach-msm/board-express.c:153-157` defines the downstream Iris FM platform device.
- `android_device_samsung_expressltexx/system_prop.mk:37-48` records Bluetooth SMD transport and `wifi.interface=wlan0`.
- `android_device_samsung_expressltexx/proprietary-files.txt:1-4` lists FM/Wi-Fi/Bluetooth helper binaries including `fm_qsoc_patches` and `hci_qcomm_init`.
- `android_device_samsung_expressltexx/rootdir/init.qcom.rc:190-224` starts Bluetooth hciattach and Wi-Fi supplicant using `wlan0`/`p2p0`.
- `android_device_samsung_expressltexx/rootdir/init.qcom.rc:234-239` starts the FM setup script.
- `android_kernel_samsung_msm8930-common/arch/arm/mach-msm/board-8930-pmic.c:432-584` defines charger current limits, voltage/current thresholds, sense/connector resistance, and battery pdata.
- `android_kernel_samsung_msm8930-common/arch/arm/mach-msm/board-8930-pmic.c:718-739` defines PM8921 BMS pdata.
- `android_kernel_samsung_msm8930-common/arch/arm/mach-msm/bms-batterydata-express.c:108-116` defines the 2000 mAh Express battery data and rbatt values.
- `linux/arch/arm/boot/dts/qcom/qcom-msm8960-samsung-expressatt.dts:26-54` is the upstream Express ATT GPIO key reference.
- `linux/arch/arm/boot/dts/qcom/qcom-msm8960-samsung-expressatt.dts:63-80` is the upstream Express ATT AMS/TAOS light/prox reference.
- `linux/arch/arm/boot/dts/qcom/qcom-msm8960-samsung-expressatt.dts:123-136` is the upstream Express ATT maXTouch reference.
- `linux/arch/arm/boot/dts/qcom/qcom-msm8960-samsung-expressatt.dts:479-488` is the upstream Express ATT PN544 NFC reference.
- `linux/arch/arm/boot/dts/qcom/qcom-msm8960-samsung-expressatt.dts:500-518` is the upstream Express ATT BMA254/YAS532 sensor reference.
- `linux/drivers/input/touchscreen/atmel_mxt_ts.c:3395-3396` supports `compatible = "atmel,maxtouch"` in mainline.
- `linux/drivers/input/keyboard/tm2-touchkey.c:334-347` has mainline Cypress/Coreriver Samsung touchkey variants, but exact Cypress Express compatibility must be checked before reuse.
- `linux/drivers/nfc/pn544/i2c.c:46-60` has mainline PN544 I2C support, not an explicit PN547 OF match.
- `linux/drivers/iio/light/tsl2772.c:1900-1917` has mainline `tmd2772` / `amstaos,tmd2772` support.
- `linux/drivers/iio/imu/inv_mpu6050/inv_mpu_i2c.c:176-209` supports `mpu6050` and `mpu6500` I2C compatibles in mainline.
- `linux/drivers/iio/magnetometer/yamaha-yas530.c:1581-1595` supports `yas532` / `yamaha,yas532` in mainline.
- `linux/drivers/gpu/drm/bridge/sii9234.c:941-960` supports `compatible = "sil,sii9234"` in mainline.
- `linux/drivers/input/misc/pwm-vibra.c:38-59` shows mainline `pwm-vibrator` can drive a PWM plus optional enable GPIO and supply; this is the likely conceptual match for downstream `HAPTIC_PWM`, subject to PWM-provider availability on GPIO 70.

Current use:

- `linux/arch/arm/boot/dts/qcom/qcom-msm8930-samsung-expressltexx.dts:46-74` models the TLMM-backed home, volume-up, and volume-down keys; `qcom-msm8930-samsung-expressltexx.dts:145-150` adds their GPIO pin state.
- `linux/arch/arm/boot/dts/qcom/pm8917.dtsi:13-20` models the PM8917 power key.
- `linux/arch/arm/boot/dts/qcom/qcom-msm8930.dtsi` now models MSM8930 QFPROM at `0x00700000`, TSENS calibration cells at offsets `0x404` and `0x414`, explicit `qcom,msm8930-tsens` under GCC, and a CPU thermal zone using sensor 9.
- `linux/drivers/thermal/qcom/tsens-8960.c` now carries MSM8930-specific 10-sensor TSENS data using the downstream slopes, APQ8064-style status-control register handling, and early all-sensor enable in `init_8930()`.
- `linux/drivers/clk/qcom/gcc-msm8960.c` extends the MSM8960-family GCC regmap range through `0x3678` so TSENS sensor status registers above `0x3660` are accessible through the syscon.
- `linux/arch/arm/boot/dts/qcom/qcom-msm8930-samsung-expressltexx.dts:9-217` currently models board identity, simple-framebuffer, TLMM GPIO keys, PM8917 power key, minimal PM8917 RPM USB/eMMC supplies, GSBI5 UART, SDCC1/eMMC, and USB peripheral mode only.
- No mainline Expressltexx DT nodes currently model touchscreen, touchkeys, haptics, MUIC, NFC, sensors, MHL, display panel, cameras, audio, WLAN/Bluetooth/FM, charger/BMS, or battery profile.

Notes:

- Do not copy `qcom-msm8960-samsung-expressatt.dts` electrical details blindly. It is useful for upstream style and nearby peripheral categories, but Expressltexx differs in PMIC/regulators, home-key GPIO, NFC enable GPIO, sensor set, MUIC, haptics, display panel, and cameras.
- Good low-risk future DTS candidates after PMIC/regulator plumbing settles are maXTouch, YAS532/MPU sensors, TAOS light/prox, and SDCC3. MUIC/PN547/touchkeys/haptics may need driver or binding checks before they become clean upstream nodes.
