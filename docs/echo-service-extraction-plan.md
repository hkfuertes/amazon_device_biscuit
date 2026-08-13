# echo_service extraction plan

Notes for later if we decide to split Biscuit's service into a reusable Echo service repo.

## Current recommendation

Do not extract yet unless a second Echo target is active. Keep Biscuit working here. When reuse becomes real, extract the smallest useful unit and keep Biscuit compatibility.

Suggested new name: `echo_service`.

Keep old shell entrypoint as an alias/wrapper:

```sh
/system/bin/echo_service
/system/bin/biscuit_service   # compatibility wrapper or symlink
```

## What exists today

Main service tree:

```text
sources/device_amazon_biscuit/biscuit-service/
  Android.mk
  biscuit_service                         # shell wrapper
  biscuit-ledd.cpp                        # LED daemon, owns socket
  biscuit-ledctl.cpp
  i2c-poke.cpp
  animations/*.animation
  service/AndroidManifest.xml
  service/src/com/amazon/biscuit/service/BiscuitService.java
  service/src/com/amazon/biscuit/service/IBiscuitService.aidl
  testclient/...
```

Device integration:

```text
sources/device_amazon_biscuit/device.mk
sources/device_amazon_biscuit/rootdir/init.device.rc
sources/device_amazon_biscuit/rootdir/init.biscuit.usb.rc
```

`device.mk` installs:

```text
biscuit-ledd
biscuit-ledctl
biscuit_service
BiscuitService
animations under /system/etc/biscuit-ledd/
conference_bridge for USB conference mode
```

`init.device.rc` defines:

```text
service biscuit-ledd /system/bin/biscuit-ledd
  socket biscuit-ledd stream 0660 system system

service conference_bridge /system/bin/conference_bridge
```

## What BiscuitService uses

Java service:

```text
sources/device_amazon_biscuit/biscuit-service/service/src/com/amazon/biscuit/service/BiscuitService.java
```

Uses Android APIs:

- `AudioManager`
  - `adjustStreamVolume(STREAM_MUSIC, ...)`
  - `setStreamVolume(STREAM_MUSIC, ...)`
  - `setMicrophoneMute(...)`
  - `isMicrophoneMute()`
- `WifiManager`
  - enable/disable/reconnect/configure network
- `BluetoothAdapter`
  - enable, discoverable pairing mode, disable
- `LocalSocket`
  - connects to reserved socket `biscuit-ledd`

Uses LED daemon protocol:

```text
PLAY <name>
FRAME <72 hex chars>
VOLUME <current> <max>
MUTE 1|0
OFF
STATUS
```

Wrapper commands exposed today:

```sh
biscuit_service volume up|down|set <0..max>
biscuit_service mute on|off|toggle
biscuit_service mic mute|unmute|toggle
biscuit_service bt pair|off
biscuit_service wifi on|off|connect <ssid> [psk]
biscuit_service usb conference on|off|status
biscuit_service usb uac2|adb
```

Do not log WiFi PSKs when documenting/debugging.

## Framework patches coupled to the service

### 1. Microphone mute broadcast — required for mute LED feedback

Patch:

```text
patches/cm12-biscuit-microphone-mute-broadcast.patch
```

Adds to `frameworks/base/media/java/android/media/AudioService.java`:

```text
com.amazon.biscuit.service.MICROPHONE_MUTE_CHANGED
com.amazon.biscuit.service.EXTRA_MICROPHONE_MUTED
```

Flow:

```text
biscuit_service mute on/off/toggle
  -> BiscuitService.setRealMicMuted(...)
  -> AudioManager.setMicrophoneMute(...)
  -> AudioService changes real mic state
  -> framework broadcasts MICROPHONE_MUTE_CHANGED
  -> BiscuitService receives it
  -> sends MUTE 1/0 to biscuit-ledd
```

Without this patch, shell mute can still change real microphone mute state, but LED feedback will not reliably update from framework state changes.

If renamed to `echo_service`, either:

- keep old `com.amazon.biscuit.service.*` broadcast for compatibility, or
- introduce `com.amazon.echo.service.*` and have Biscuit service listen to both during transition.

Lazy migration: listen to both, emit old one until second device needs new name.

### 2. Mic mute key / physical button handling — required for Echo buttons

Patch:

```text
patches/cm12-biscuit-framework-mic-mute-key.patch
```

Touches:

```text
frameworks/base/data/keyboards/Generic.kl
frameworks/base/policy/src/com/android/internal/policy/impl/PhoneWindowManager.java
```

Effects:

- maps Linux key 113 from `VOLUME_MUTE` to `MUTE`
- maps key 138 to `HELP`
- handles `KEYCODE_MUTE` by toggling:

```java
AudioManager.setMicrophoneMute(!audioManager.isMicrophoneMute())
```

- handles physical volume up/down by adjusting `STREAM_MUSIC`
- emits Amazon-style button broadcasts for non-volume/mute keys:

```text
com.amazon.device.intent.action.BUTTON_PRESSED
com.amazon.device.intent.action.BUTTON_RELEASED

extras:
com.amazon.device.intent.extra.BUTTON_NAME
com.amazon.device.intent.extra.KEY_CODE
com.amazon.device.intent.extra.SCAN_CODE
com.amazon.device.intent.extra.DEVICE_ID
```

This patch is not needed for shell-only `biscuit_service` commands. It is needed for physical Echo buttons to behave correctly.

## Volume broadcast

`BiscuitService` listens for standard Android broadcast:

```text
android.media.VOLUME_CHANGED_ACTION
```

and reads standard extras:

```text
android.media.EXTRA_VOLUME_STREAM_TYPE
android.media.EXTRA_VOLUME_STREAM_VALUE
```

No custom volume-change framework patch was found. The button patch only makes physical volume keys adjust `STREAM_MUSIC`, which then causes the normal Android volume changed broadcast.

## USB conference mode coupling

The Java service does not handle USB. The shell wrapper handles it directly with properties/init:

```sh
setprop sys.usb.config uac2,adb
setprop ctl.start conference_bridge
setprop ctl.stop conference_bridge
```

Related integration:

```text
sources/device_amazon_biscuit/rootdir/init.biscuit.usb.rc
sources/device_amazon_biscuit/rootdir/init.device.rc
patches/biscuit-kernel-usb-uac2-gadget.patch
conference_bridge package in device.mk
```

This should probably stay as an optional/device-specific module, not core `echo_service`, until another Echo needs it.

## Suggested extraction shape

New repo could contain:

```text
echo_service/
  service/                         # Android privileged service
  shell/echo_service                # shell wrapper
  shell/biscuit_service             # compat wrapper
  led/                              # current biscuit-ledd/ledctl, if reused
  animations/                       # default animations
  patches/cm12/frameworks-base/
    microphone-mute-broadcast.patch
    mic-mute-key.patch
  docs/
    integration-cm12.md
    commands.md
```

But avoid over-generalizing early. First extraction can remain Biscuit-shaped with a better repo name.

## Integration contract for this repo

Any future extraction must remain reproducible from tracked files. Do not depend on a manual `../echo_service` checkout without a pin.

Acceptable integration options:

1. Git submodule pinned to a commit.
2. Android repo/local manifest pinned to a revision.
3. Vendored source copy refreshed by a script.

Shortest safe first version: vendored source copy + refresh script. Move to submodule/repo manifest only when multiple device trees consume it.

## Hotfix / live framework patching idea

Possible debug loop, not normal release path:

```text
host PC:
  adb pull /system/framework/...
  apktool/baksmali patch
  rebuild
  make small TWRP flashable zip

TWRP:
  adb sideload patch.zip
  wipe dalvik/cache
  reboot
```

Notes:

- TWRP itself does not provide Java/apktool.
- `framework-res.apk` resource patches: apktool.
- `services.jar` / `framework.jar` Java patches: baksmali/smali.
- Bootclasspath mistakes can bootloop.
- Use flashable zip metadata, not ad-hoc `adb push`, if repeating.
- Permanent changes still belong as source patches + rebuilt OTA.

## Minimal future task list

When ready:

1. Rename/genericize public names carefully:
   - new command: `echo_service`
   - keep `biscuit_service` compatibility
   - maybe keep package `com.amazon.biscuit.service` for first extraction to avoid churn
2. Move service tree to new repo.
3. Move/document the two framework patches:
   - microphone mute broadcast
   - mic mute key / button handling
4. Add integration doc for CM12 device trees:
   - `PRODUCT_PACKAGES`
   - `PRODUCT_COPY_FILES` for animations
   - init socket service
   - privileged/platform-signed APK requirements
5. Keep USB conference mode optional/device-specific.
6. Add one smoke check:

```sh
adb shell biscuit_service volume up
adb shell biscuit_service mute toggle
adb shell pidof biscuit-ledd
adb shell logcat -d | grep -E 'BiscuitService|biscuit-ledd'
```

## Decision checkpoint

Extract only when one of these is true:

- second Echo device tree starts using it;
- framework patches need to be shared across devices;
- service development becomes independent of Biscuit board bring-up.

Until then, document and leave it here.
