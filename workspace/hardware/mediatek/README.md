# MediaTek WiFi userspace helpers

Vendored snapshot for Biscuit CM12 WiFi bring-up.

Provenance: `lbule/android_hardware_mediatek` commit `a4df15d`.

Included files:

- `wlan/wpa_supplicant_8_lib/Android.mk`
- `wlan/wpa_supplicant_8_lib/mediatek_driver_cmd_nl80211.c`
- `wlan/wpa_supplicant_8_lib/mediatek_driver_nl80211.h`
- `wlan/wifi_hal/Android.mk` and sources

Imported layers in this phase: private supplicant driver-command helper and WiFi HAL.
Do not import MTK firmware/WMT/BT/GPS/audio here; Biscuit keeps the working
Amazon firmware and init path.
