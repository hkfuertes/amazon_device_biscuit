# Bluetooth HFP scouting for Biscuit

Date: 2026-08-10

## Goal

Explore whether Biscuit can expose itself over Bluetooth as:

- A2DP Sink: phone/PC -> Biscuit speaker.
- HFP/HSP Hands-Free: bidirectional call audio, Biscuit speaker + mic.

A2DP sink is already known working/available. Missing piece is HFP Hands-Free role.

## Findings

### A2DP Sink already enabled

`packages/apps/Bluetooth/res/values/config.xml` has:

```xml
<bool name="profile_supported_a2dp_sink">true</bool>
```

The Bluetooth app also has A2DP sink JNI/service code:

- `packages/apps/Bluetooth/jni/com_android_bluetooth_a2dp_sink.cpp`
- `packages/apps/Bluetooth/src/com/android/bluetooth/a2dpsink/`

### HFP Hands-Free client exists but is disabled

The role Biscuit needs is Android's HFP **client** / Hands-Free role, not the normal phone Audio Gateway role.

Existing code paths:

- Framework API:
  - `frameworks/base/core/java/android/bluetooth/BluetoothHeadsetClient.java`
  - `frameworks/base/core/java/android/bluetooth/IBluetoothHeadsetClient.aidl`
  - `BluetoothProfile.HEADSET_CLIENT`
- Bluetooth app service/JNI:
  - `packages/apps/Bluetooth/src/com/android/bluetooth/hfpclient/HeadsetClientService.java`
  - `packages/apps/Bluetooth/src/com/android/bluetooth/hfpclient/HeadsetClientStateMachine.java`
  - `packages/apps/Bluetooth/jni/com_android_bluetooth_hfpclient.cpp`
- Bluedroid stack:
  - `external/bluetooth/bluedroid/bta/hf_client/`
  - `external/bluetooth/bluedroid/btif/src/btif_hf_client.c`
  - `external/bluetooth/bluedroid/btif/src/bluetooth.c` exports `BT_PROFILE_HANDSFREE_CLIENT_ID` / `handsfree_client`.
- Build inclusion seen in:
  - `external/bluetooth/bluedroid/bta/Android.mk`
  - `external/bluetooth/bluedroid/main/Android.mk`

But default config disables it:

```xml
<bool name="profile_supported_hfpclient">false</bool>
```

`btservice/Config.java` already includes `HeadsetClientService.class` in `PROFILE_SERVICES`, gated by that bool.

### Existing HFP AG is not enough

`profile_supported_hs_hfp=true` enables the normal Headset/HFP profile used by Android as a phone/audio gateway. That is the opposite role from Biscuit-as-speakerphone.

For Biscuit we likely need:

```xml
<bool name="profile_supported_hfpclient">true</bool>
```

Probably via device overlay rather than editing package defaults.

### Audio routing is the risky part

`HeadsetClientStateMachine` opens SCO audio and then uses AudioManager/HAL params:

```text
MODE_IN_CALL
STREAM_BLUETOOTH_SCO
hfp_set_sampling_rate=8000/16000
hfp_enable=true
hfp_volume=...
```

The MTK proprietary audio HAL blobs do **not** contain these Qualcomm-style strings:

- `hfp_enable`
- `hfp_set_sampling_rate`
- `hfp_volume`

Those strings exist in Qualcomm HAL source under `hardware/qcom/audio*`, not in the Amazon/MTK proprietary HAL.

However, the MTK audio HAL does contain many BT SCO/BTCVSD symbols, for example in:

- `vendor/amazon/mt8163-common/proprietary/lib/hw/audio.primary_amazon.mt8163.so`
- `vendor/amazon/mt8163-common/proprietary/lib64/hw/audio.primary_amazon.mt8163.so`

Examples from `strings`:

```text
AudioBTCVSDControl
BT_SCO_SetMode
BT_SCO_TX_Open
BT_SCO_RX_Open
AudioALSAPlaybackHandlerBTSCO
AudioALSAPlaybackHandlerBTCVSD
AudioALSACaptureHandlerBTC
SetBtHeadsetNrec
```

`audio_policy.conf` also includes SCO-capable input:

```text
AUDIO_DEVICE_IN_ALL_SCO
```

So BlueDroid/HFP may connect, but SCO audio may need MTK-specific routing if AudioManager params are ignored.

## Existing Biscuit helper state

`biscuit_service` currently exposes only simple Bluetooth commands:

```sh
adb shell biscuit_service bt pair
adb shell biscuit_service bt off
```

Backed by `BiscuitService.java`:

- enables adapter
- enters discoverable/connectable pairing mode
- disables adapter

No profile-specific HFP control exists yet.

## Recommended lazy PoC

1. Enable HFP client via Biscuit/device overlay:

   ```xml
   <bool name="profile_supported_hfpclient">true</bool>
   ```

2. Add minimal `BiscuitService` / `biscuit_service` commands for HFP client:

   ```sh
   adb shell biscuit_service bt hfp connect <addr>
   adb shell biscuit_service bt hfp audio on
   adb shell biscuit_service bt hfp audio off
   adb shell biscuit_service bt hfp status
   ```

3. Build only needed modules first:

   ```sh
   make Bluetooth BiscuitService biscuit_service
   ```

4. Test in this order:

   - Phone/PC sees Biscuit as hands-free capable device.
   - HFP SLC connects.
   - `BluetoothHeadsetClient.connectAudio()` reaches SCO connected state.
   - Speaker output works.
   - Mic input works.
   - No regressions to A2DP sink.

## Likely outcomes

- Best case: enabling `profile_supported_hfpclient` is enough; MTK HAL routes SCO through existing BTCVSD paths.
- Medium case: profile connects but no audio; need MTK-specific AudioManager parameters/routing.
- Worst case: profile is present but unstable in this CM12/MTK stack; keep USB conference mode as primary solution.

## Do not overbuild yet

Do not port BlueDroid, write a custom SCO bridge, or touch audio HAL until the bool-enabled PoC proves where it fails.
