# MediaTek WiFi userspace helpers

Source: `workspace/tools/android_hardware_mediatek-lbule` commit `a4df15d`.

Vendored for Biscuit CM12 WiFi bring-up:

- `wlan/wpa_supplicant_8_lib/Android.mk`
- `wlan/wpa_supplicant_8_lib/mediatek_driver_cmd_nl80211.c`
- `wlan/wpa_supplicant_8_lib/mediatek_driver_nl80211.h`
- `wlan/wifi_hal/Android.mk` and sources

Imported layers in this phase: private supplicant driver-command helper and WiFi HAL.
Do not import MTK firmware/WMT/BT/GPS/audio here; Biscuit keeps the working
Amazon firmware and init path.
