# PRD — Biscuit USB Conference Mode

## Problem Statement

Biscuit ya enumera como dispositivo USB UAC2 duplex (`uac2,adb`), pero todavía no puede actuar como altavoz/micrófono de conferencia de forma usable. Falta una capa software que conecte el audio USB del host con el altavoz y micrófono Android del Echo Dot, controlable por comandos simples y recuperable si algo falla.

## Solution

Añadir un modo conferencia controlado por `biscuit_service` que active `uac2,adb` y arranque un bridge nativo entre:

- USB UAC2 PCM del gadget.
- Android audio para speaker/mic.

Flujo objetivo:

```text
PC playback -> UAC2 OUT -> conference_bridge -> Android AudioTrack -> speaker
mic -> Android AudioRecord -> conference_bridge -> UAC2 IN -> PC capture
```

## User Stories

1. As a user, I want Biscuit to appear as a USB speaker and microphone, so that I can use it in Zoom/Meet/Teams.
2. As a user, I want one command to enable conference mode, so that I do not need manual USB/sysfs steps.
3. As a user, I want one command to disable conference mode, so that the device returns to normal ADB mode.
4. As a developer, I want ADB to remain available in conference mode, so that debugging stays possible.
5. As a developer, I want the bridge to fail clearly if mic or speaker cannot open, so that half-working states are obvious.
6. As a developer, I want rollback-safe testing, so that USB experiments do not strand the device.
7. As a future app developer, I want the bridge behind a stable service command, so that an APK UI can be added later without changing audio plumbing.

## Implementation Decisions

- Build a small native `conference_bridge` binary.
- Use tinyalsa only for the UAC2 gadget PCM side.
- Use Android audio APIs for physical speaker/mic, not direct codec ALSA, to avoid fighting AudioFlinger/audio policy unnecessarily.
- Treat conference mode as exclusive for microphone capture.
- Speaker output may mix with other Android audio initially.
- Add `biscuit_service usb conference on|off|status`.
- `conference on` activates `uac2,adb` and starts the bridge.
- `conference off` stops the bridge and returns USB config to `adb`.
- Keep AEC/AGC/noise suppression out of v1; rely on host conferencing software first.

## Testing Decisions

- Test external behavior, not internals.
- First validate PC → Biscuit speaker path.
- Then validate Biscuit mic → PC path.
- Then validate full-duplex playback+capture.
- Always arm a rollback timer before enabling `uac2,adb` during risky tests.
- Confirm after tests:
  - ADB is alive.
  - USB state returns to `adb`.
  - no kernel panic/Oops/BUG appears in dmesg.

## Out of Scope

- APK/UI.
- Bluetooth conferencing.
- Echo cancellation tuning.
- Automatic arbitration with arbitrary Android mic users.
- Replacing Android audio HAL/policy with a full USB audio HAL integration.

## Further Notes

Current kernel/UAC2 baseline is good: host sees duplex USB Audio, playback/capture/full-duplex smoke tests pass, and no kernel panic was observed. Next implementation should be a tracer bullet, not a full audio product.
