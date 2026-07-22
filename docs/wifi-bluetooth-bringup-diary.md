# WiFi/Bluetooth bring-up diary

Repo branch: `wifi-bluetooth-bringup`

Scope now: WiFi client + P2P/AP where feasible, Bluetooth base bring-up. Avoid speaker/audio runtime tests at night.

## 2026-07-20

### Decisions

- Prefer source-built components over stock `.so` blobs.
  - Use stock OTA blobs for firmware/config/closed launcher binaries when no source is available or practical: e.g. `WIFI_RAM_CODE_8163`, `WMT_SOC.cfg`, `wmt_loader`, `6620_launcher`.
  - Do not add stock `.so` libraries casually. Add a `.so` blob only when it is required for hardware bring-up and no source exists in CM12, Amazon OSS, or the Echo Dot source tar.

- Keep `android_hardware_amazon` integrated.
  - Reason: it provides the MTK `wpa_supplicant` private driver command helper (`lib_driver_cmd_mt66xx`) required by CM12 `wpa_supplicant` with `BOARD_WPA_SUPPLICANT_PRIVATE_LIB`.
  - Source: official Amazon OSS `android_hardware_amazon`, not copied from sibling repo.

- Keep WiFi P2P/AP support as a goal.
  - Earlier assumption “client only” was wrong; user wants P2P/AP if practical.
  - The Amazon helper’s duplicate P2P/AP functions only returned `-1`/ignored commands and conflict with CM12 native `driver_nl80211.c` definitions.
  - Current fix direction: avoid duplicate symbols while preserving CM12 native P2P/AP hooks.

- Build and runtime autonomy granted overnight.
  - Allowed: detached Docker builds, TWRP-based flashing/testing.
  - Still forbidden by repo safety rules: `dd` writes from Android/ADB, stock fastboot flashing for ROMs, GPT/preloader/LK/TZ/recovery/userdata/cache/persist/misc changes unless explicitly requested.
  - Runtime tests must avoid making speaker sound.

### Findings

- Last build failure was linker duplicate symbols in `wpa_supplicant`:
  - `wpa_driver_set_p2p_noa`
  - `wpa_driver_get_p2p_noa`
  - `wpa_driver_set_p2p_ps`
  - `wpa_driver_set_ap_wps_p2p_ie`

- Duplicate source locations:
  - Amazon helper: `workspace/hardware/amazon/wpa_supplicant/mediatek_driver_cmd_nl80211.c`
  - CM12 native: `workspace/cm12/external/wpa_supplicant_8/src/drivers/driver_nl80211.c`

- Echo Dot source tar structure:
  - outer tar contains `platform.tar`, `fireos.tar`, `build_kernel.tar.gz`, `busybox-1.22.1.tar.gz`, `README.txt`.
  - `platform.tar` has MT8163 kernel/connectivity driver source, including WMT/WLAN/P2P kernel-side code.
  - It did not show an obvious Android userspace MTK `libbt-vendor` source or WiFi HAL source with ready `Android.mk`.
  - `fireos.tar` includes Amazon audio-related code such as `vendor/amazon/audio/libs/btremoted`, useful for a later audio pass, not for tonight’s no-speaker BT base bring-up.

- CM12 already contains source for:
  - `bluetooth.default` in `external/bluetooth/bluedroid/main/Android.mk`
  - Bluetooth app/framework pieces
  - generic Bluedroid configs

- CM12 does not appear to contain an MTK `libbt-vendor` source; built-in vendor options found are Broadcom/Qcom/TI. Stock `libbt-vendor.so` may become a justified exception if Bluedroid requires it and no MTK source is found.

### Next checks

- Rebuild after resolving `wpa_supplicant` duplicate P2P/AP symbols.
- Verify `wpa_supplicant`, P2P config, firmware, WMT launchers, and BT framework/HAL artifacts in output.
- If enabling BT packages, compile `bluetooth.default` from source and only use stock MTK `libbt-vendor.so` if required.
- Runtime via TWRP only after valid ZIP exists; collect logs for `wmtLoader`, `conn_launcher`, `wpa_supplicant`, `wlan0`, `stpbt`, `Bluetooth`.

### Test WiFi credential

- User provided overnight test WiFi credentials.
- Stored locally in `workspace/secrets/wifi-test.env` with mode `0600`.
- `.gitignore` excludes `workspace/secrets/`.
- Do not print PSK in logs/diary/commit messages.

### WiFi band preference

- Test SSID broadcasts both 2.4 GHz and 5 GHz.
- Prefer 5 GHz for runtime tests.
- First test plan: connect normally, then verify association frequency/channel; only add band/channel forcing if it picks 2.4 GHz.

### Bluetooth source/blob split

- Enabled source-built CM12 Bluedroid pieces:
  - `Bluetooth`
  - `bluetooth.default`
  - `bt_stack.conf`, `bt_did.conf`, `auto_pair_devlist.conf`
  - device `bdroid_buildcfg.h`
- Did not enable `audio.a2dp.default` yet; audio/noise path is for the next pass.
- Removed stock `libbt-utils.so` from blob list because CM12 builds `libbt-utils` from source.
- Kept stock MTK vendor bridge as justified blobs after source search found no MTK `libbt-vendor` implementation:
  - `libbt-vendor.so`
  - `libbluetooth_mtk.so`
  - `libnvram.so`
  - `libnvram_platform.so`
  - `libcustom_nvram.so`

### AP/P2P source path

- Enabled source-built `hostapd`/`hostapd_cli` from CM12 `external/wpa_supplicant_8/hostapd` using `BOARD_HOSTAPD_DRIVER := NL80211`.
- Did not use stock `hostapd` blob.
- P2P remains through CM12 `wpa_supplicant` native nl80211 hooks plus Amazon MTK `driver_cmd` helper.

### Hostapd MTK driver_cmd link fix

- Build failure: source-built `hostapd` linked `driver_nl80211.o` but missed `wpa_driver_nl80211_driver_cmd`.
- Fix: set `BOARD_HOSTAPD_PRIVATE_LIB := lib_driver_cmd_mt66xx`, same Amazon source-built helper used by `wpa_supplicant`.

### P2P stubs restored in Amazon helper

- Build failure after removing stubs: `wpa_supplicant` expected `wpa_driver_set_p2p_noa`, `wpa_driver_get_p2p_noa`, `wpa_driver_set_p2p_ps`, and `wpa_driver_set_ap_wps_p2p_ie` from the private lib.
- Restored Amazon helper stubs, with fixed `wpa_printf` arguments.
- With both `BOARD_WPA_SUPPLICANT_PRIVATE_LIB` and `BOARD_HOSTAPD_PRIVATE_LIB` set to `lib_driver_cmd_mt66xx`, CM12 should not emit duplicate built-in P2P stubs.

### Stale blob cleanup

- Output verification found stale Bluetooth blobs from older builds in `out-docker/target/product/biscuit/system` even after removing them from `PRODUCT_COPY_FILES`.
- Action: run `make installclean` before regenerating OTA, so packaged system only contains currently declared files.

### 64-bit WMT launcher runtime

- Runtime failure after first flash: `/system/bin/wmt_loader` and `/system/bin/6620_launcher` existed but failed with `No such file or directory`.
- Cause: both stock launchers are AArch64 and request `/system/bin/linker64`; CM12 Biscuit is intentionally 32-bit userspace and had no `linker64`.
- No userspace source for these launchers was found in the Amazon Echo source tar; only kernel WMT/STP/WLAN sources were present.
- Decision: keep 32-bit CM12 and add only the minimal stock 64-bit runtime required by these two launchers:
  - `bin/linker64`
  - `lib64/libc.so`
  - `lib64/libcutils.so`
  - `lib64/liblog.so`
  - `lib64/libm.so`
  - `lib64/libstdc++.so`

### 64-bit runtime dependency follow-up

- Runtime after adding `linker64` failed with `CANNOT LINK EXECUTABLE DEPENDENCIES: library "libsigchain.so" not found`.
- Added minimal follow-up dependency: `lib64/libsigchain.so`.

### WiFi driver load via `/dev/wmtWifi`

- Runtime after WMT launchers worked: `/dev/wmtWifi` existed but framework WiFi failed because `wlan0` did not exist.
- Manual test `echo 1 > /dev/wmtWifi` created `wlan0`.
- Patched CM12 `hardware/libhardware_legacy/wifi/wifi.c` no-module path:
  - `wifi_load_driver()` writes `1` to `/dev/wmtWifi` before setting `wlan.driver.status=ok`.
  - `wifi_unload_driver()` writes `0` to `/dev/wmtWifi` when possible.
- This is a local CM12 source patch; make it reproducible before final commit.

### Ueventd device-node permissions

- Runtime after `wifi_load_driver()` patch failed with `Cannot open /dev/wmtWifi: Permission denied`.
- `/dev/wmtWifi` was `root root 0600`; `ueventd.mt8163.rc` had correct rules but was not copied into ramdisk.
- Added explicit `PRODUCT_COPY_FILES` entry for `root/ueventd.mt8163.rc`.

### `wpa_supplicant` P2P stub crash fix

- Runtime: `wpa_supplicant` repeatedly SIGSEGV right after WPS virtual display/push_button setup.
- Likely cause: restored Amazon P2P stubs dereferenced `priv` as `struct i802_bss *`; CM12 call sites do not guarantee that for all hooks.
- Fix: keep required P2P symbols but make stubs avoid dereferencing `priv`.

### Temporary P2P disable for STA WiFi

- Even after making P2P stubs not dereference `priv`, `wpa_supplicant` still SIGSEGVs right after WPS/P2P setup.
- Debuggerd suppresses wpa tombstone due `prctl(PR_GET_DUMPABLE)==0`; no useful wpa backtrace captured yet.
- Temporary client-WiFi choice: disable `ANDROID_P2P` in CM12 `external/wpa_supplicant_8/wpa_supplicant/Android.mk` so STA can be tested.
- AP via `hostapd` remains enabled; P2P is deferred.

### Temporary WPS disable for STA WiFi

- Disabling `ANDROID_P2P` did not stop `wpa_supplicant` SIGSEGV; crash still occurs immediately after WPS virtual display/push_button setup.
- Temporary STA bring-up choice: comment out `CONFIG_WPS`, `CONFIG_WPS_ER`, `CONFIG_WPS_NFC`, and `CONFIG_P2P` in CM12 `wpa_supplicant/android.config`.
- This sacrifices WPS/P2P for now; WPA-PSK client testing should not need WPS.

### Disable AP code inside wpa_supplicant

- After disabling WPS/P2P, `wpa_supplicant` rebuild failed in `src/ap/ap_drv_ops.c` because `CONFIG_AP` expected P2P fields.
- Disabled `CONFIG_AP` inside `wpa_supplicant/android.config`; standalone source-built `hostapd` remains enabled for AP testing later.

### Disable Wi-Fi Display in wpa_supplicant

- `CONFIG_WIFI_DISPLAY=y` remained enabled and can pull the P2P/WPS path even after commenting `CONFIG_P2P`.
- Disabled `CONFIG_WIFI_DISPLAY` for STA-minimum test.

### 2026-07-21 — STA-only wpa_supplicant trim

- Re-scoped WiFi bring-up to client STA first; P2P/AP/WPS/Wi-Fi Display are nice-to-have, not blockers.
- Kept source-built `wpa_supplicant`; no fallback to stock binary/blob.
- Build failure after disabling P2P/AP/WPS/Wi-Fi Display was caused by `CONFIG_HS20`/`CONFIG_INTERWORKING` forcing GAS/offchannel, while `offchannel.c` still references P2P-only fields (`p2p_long_listen`).
- Config-only fix applied: disabled `CONFIG_INTERWORKING` and `CONFIG_HS20` in `workspace/cm12/external/wpa_supplicant_8/wpa_supplicant/android.config` so STA build avoids GAS/offchannel.
- Intentionally not preserving P2P/AP/WPS now; revisit only after STA association is stable.

### 2026-07-21 — `p2p_set_country` guard for STA-only build

- Last STA-only build failed at link: `ctrl_iface.c` referenced `p2p_set_country` while `CONFIG_P2P` was disabled.
- No config-only fix found that preserves Android `DRIVER` commands; disabling `ANDROID` would also remove needed MTK `driver_cmd` path.
- Minimal source fix applied in `wpa_supplicant/ctrl_iface.c`: guard the P2P country update with `#ifdef CONFIG_P2P`; normal driver `COUNTRY` command still returns through `wpa_drv_driver_cmd`.
- This keeps `wpa_supplicant` source-built and does not add stock binary/blob fallback.

### 2026-07-21 — STA-only OTA build success

- Docker build `e08fda90396d` completed successfully after 24:10.
- Generated OTA: `workspace/cm12/out-docker/target/product/biscuit/cm_biscuit-ota-a64cc4ce45.zip`.
- ZIP integrity check passed with `unzip -t` (`No errors detected`).
- This is the first source-built STA-only `wpa_supplicant` OTA after disabling P2P/AP/WPS/Wi-Fi Display/HS20/Interworking and guarding `p2p_set_country`.
- Next hardware checks: flash via TWRP, verify WiFi STA (`wlan0`, `wpa_supplicant`, `wpa_cli PONG`, association), then Bluetooth radio scan/device visibility. No app/audio/speaker scope yet.

### 2026-07-21 — Flashed STA-only OTA `a64cc4ce45`

- Rebooted from Android to TWRP via `adb reboot recovery`.
- Confirmed TWRP explicitly over ADB: `/sbin/twrp`, version `3.2.3-0`.
- Pushed `workspace/cm12/out-docker/target/product/biscuit/cm_biscuit-ota-a64cc4ce45.zip` to `/sdcard/`.
- Installed with TWRP CLI, no wipes: `script succeeded: result was [0.200000]`.
- Rebooted to Android; ADB returned as `device` with `ro.cm.version=12.1-20260721-UNOFFICIAL-biscuit`.
- Next: WiFi STA runtime checks, then Bluetooth scan visibility. No app/audio/speaker scope.

### 2026-07-21 — First hardware check after `a64cc4ce45`

- Boot OK after flash; ADB available and `sys.boot_completed=1`.
- WiFi kernel/driver side still works:
  - `svc wifi enable` sets `wlan.driver.status=ok`.
  - `wlan0` exists with MAC and is UP/DORMANT.
  - WMT/launcher processes present: `/system/bin/6620_launcher`, `mtk_wmtd`.
- WiFi userspace still not done:
  - `init.svc.wpa_supplicant=stopped` after crash/restart.
  - `wpa_cli -p/data/misc/wifi/sockets -iwlan0 ping` returns connection refused.
  - Logs still show `wpa_supplicant` parsing P2P config lines and entering WPS conversion before SIGSEGV.
  - Noted offending config line: `p2p_no_group_iface=1` is now invalid with `CONFIG_P2P` disabled.
- Bluetooth hardware/kernel base partially present:
  - `/dev/stpbt` exists with `bluetooth:bluetooth` permissions.
  - kernel threads/processes present: `btif_rxd`, `mtk_stp_btm`, `mtk_wmtd`, `6620_launcher`.
  - WMT launcher reports firmware patch flow and `service.wcn.driver.ready=yes`.
- Bluetooth framework not exposed yet:
  - `com.android.bluetooth` package exists.
  - SystemServer logs `No Bluetooth Service (Bluetooth Hardware Not Present)` and `Bluetooth binder is null`.
  - Current BT done criterion (visible scan devices) is not met yet.

### 2026-07-21 — STA config cleanup before next OTA

- WiFi userspace hypothesis: source-built STA-only `wpa_supplicant` is still receiving stock P2P/WPS config from vendor copied files, causing parse errors/WPS path before SIGSEGV.
- Build-side cleanup applied in both `workspace/` and `workspace/cm12/` vendor WiFi configs:
  - removed `config_methods=display push_button keypad`
  - removed `p2p_no_group_iface=1`
  - removed `driver_param=use_p2p_group_interface=1`
  - kept `wowlan_triggers=disconnect` in STA overlay
- Not tested on device yet. Next build/flash should verify `wpa_supplicant` stays running and `wpa_cli ... ping` returns `PONG` before adding saved network credentials.

### 2026-07-21 — Framework WPS init guard for STA-only supplicant

- Manual `wpa_supplicant` with minimal config responds `PONG`, so kernel/driver/source-built supplicant base STA is viable.
- Framework path still killed/crashed supplicant after `svc wifi enable`; logs showed Android legacy WPS/device-info setup commands during supplicant init.
- Chosen direction: keep `wpa_supplicant` STA-only without WPS/P2P/AP and patch framework to skip `initializeWpsDetails()` when `mP2pSupported` is false.
- Reproducibility patch added: `workspace/patches/cm12-biscuit-wifi-sta-userspace.patch`.
- Started clean OTA rebuild from this strategy; not flashed/tested yet.

### 2026-07-21 — `DRIVER MACADDR` and random-OUI follow-up

- OTA `deec7ca07f` with `DRIVER MACADDR` guard flashed successfully.
- `DRIVER MACADDR` no longer crashes when tested manually through init-started `wpa_supplicant`; it returns `Macaddr = fc:65:de:85:6f:a5` and stays alive.
- Full framework `svc wifi enable` still crashes `wpa_supplicant` after `setExternalSim(true)` / `Setting OUI` / `WifiNative-HAL startHal` path.
- CM12 `frameworks/opt/net/wifi/service/lib/wifi_hal.cpp` is a stub returning `WIFI_ERROR_NOT_SUPPORTED` / `WIFI_ERROR_UNINITIALIZED`; scan MAC OUI randomization is optional for STA.
- Temporary STA bring-up patch: skip `setRandomMacOui()` in `WifiStateMachine` until basic STA association is stable.

### 2026-07-21 — `external_sim` crash after `a980d980fc`

- Built and flashed OTA `cm_biscuit-ota-a980d980fc.zip` after skipping scan MAC OUI randomization.
- Boot OK; `svc wifi enable` still brings driver up (`wlan.driver.status=ok`, `wlan0` MAC `fc:65:de:85:6f:a5`).
- `wpa_supplicant` still exits/crashes; `wpa_cli` gets connection refused.
- New precise crash point: framework logs `WifiNative-HAL: Setting external_sim to 1`, immediately followed by `wpa_supplicant` SIGSEGV.
- STA bring-up patch: skip `mWifiNative.setExternalSim(true)` in `WifiStateMachine`; EAP-SIM/AKA is not needed for basic STA. Re-enable only if SIM enterprise auth becomes required.
- Started detached Docker rebuild `cm12-biscuit-build` from this patch.
### 2026-07-21 — Start MTK WiFi userspace integration

- The `external_sim` bypass OTA (`aa468d0e6f`) still leaves framework-started `wpa_supplicant` crashing with SIGSEGV; `wlan.driver.status=ok` and `wlan0` still prove kernel/WMT/radio bring-up is intact.
- Started PRD-driven MTK userspace integration instead of more one-off bypasses.
- Vendored from local MTK reference `workspace/tools/android_hardware_mediatek-lbule` commit `a4df15d`:
  - `wlan/wpa_supplicant_8_lib` as the active `lib_driver_cmd_mt66xx`;
  - `wlan/wifi_hal` as `libwifi-hal-mt66xx`.
- Preserved Amazon firmware/WMT/init path; no MTK firmware or combo tools imported.
- Kept Biscuit defensive `DRIVER MACADDR` path: read `/sys/class/net/wlan0/address` before touching supplicant/driver private state.
- Enabled `BOARD_WLAN_DEVICE := MediaTek` so CM12 links `libwifi-service` against MTK WiFi HAL.


## 2026-07-21 Bluetooth framework bring-up

- Root cause for missing `bluetooth_manager`: product did not install Bluetooth feature XMLs.
- Required files:
  - `frameworks/native/data/etc/android.hardware.bluetooth.xml -> system/etc/permissions/android.hardware.bluetooth.xml`
  - `frameworks/native/data/etc/android.hardware.bluetooth_le.xml -> system/etc/permissions/android.hardware.bluetooth_le.xml`
- After manually copying those XMLs and rebooting:
  - `pm list features` reports `android.hardware.bluetooth` and `android.hardware.bluetooth_le`.
  - `service list` reports `bluetooth_manager`.
  - CM12 `IBluetoothManager.enable(String)` transaction is `service call bluetooth_manager 8 s16 com.android.shell`.
  - Bluetooth reaches `state: 12`/ON with address `FC:65:DE:2D:FD:DD` and name `Echo Dot`.
  - Discovery starts successfully and logs visible devices via `BluetoothEventManager`/`btm_process_inq_results`.
- Added local helpers under `workspace/scripts/bluetooth/`:
  - `bt-enable.sh`
  - `bt-discover.sh`
  - `BtDiscover.java`
