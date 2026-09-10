# `biscuitd` plan

## Goal

Add one small native C daemon, `/system/bin/biscuitd`, to the framework-free
`biscuit_minimal` product. It will own the direct hardware behavior formerly
split between Android `BiscuitService` and `biscuit-ledd`:

- silence and write the LED ring;
- process the physical volume and microphone-mute buttons;
- adjust speaker volume; and
- apply a real microphone mute with visible feedback.

`biscuitd` is deliberately not named `biscuit_service`: that name referred to
the old Android shell wrapper and would imply an Android service that no longer
exists.

## Scope and constraints

- Use one C binary and init service, with no Java, Binder, APK, Unix control
  socket, controller daemon, or new third-party dependency.
- Use `poll()` on Linux input events, direct LED sysfs writes, and the existing
  `libtinyalsa` library. Do not fork `tinymix` from the daemon.
- Keep the product framework-free. Do not add AudioFlinger, the Android
  framework, or the former Biscuit service stack.
- When `biscuitd` is integrated, remove the separate `led-bootstrap.sh` init
  hook so only one process writes `/sys/bus/i2c/devices/0-003f/frame`.
- Do not claim microphone mute works until the actual capture-path mixer
  control has been identified and tested. Ring-only mute feedback is not an
  acceptable substitute.
- Initial scope has no persistent volume or mute preference. At boot, the
  daemon reflects the configured mixer state; persistence can be added only if
  it is needed later.

## Known hardware contract

- The LED ring uses:
  - `/sys/bus/i2c/devices/0-003f/boot_animation`
  - `/sys/bus/i2c/devices/0-003f/frame`
- The frame is 72 hexadecimal characters: 12 RGB LEDs.
- The volume GPIO keys are known Linux input codes `KEY_VOLUMEUP` (115) and
  `KEY_VOLUMEDOWN` (114). The device path must be discovered at runtime rather
  than hard-coded as `event2`.
- The physical microphone-mute keycode and the safe mixer control which mutes
  capture remain unverified. They are required discovery work before coding the
  mute path.

## Minimal design

### Files and packaging

Create a small device-local module, for example:

```text
device/amazon/biscuit/biscuitd/
  Android.mk
  biscuitd.c
```

Add `biscuitd` and its existing native dependency closure to
`biscuit_minimal_device.mk`, then define one root init service in
`init.biscuit.bootstrap.rc`. The daemon must start after the audio bootstrap
has configured the codec and must tolerate input, mixer, or LED sysfs nodes
appearing late.

### Startup and LED behavior

At startup, `biscuitd` waits for the two LED nodes with a bounded retry,
writes `0` to `boot_animation`, and clears the ring.

- Volume change: write a green 12-segment level frame, hold it for one second,
  then clear it.
- Microphone muted: display a persistent red ring.
- Microphone unmuted: clear the ring.
- Repeated key presses reset the one-second volume-display deadline.

Use the daemon's poll/timer deadline rather than a worker thread or a second
service.

### Input behavior

Open input event devices read-only, identify them through their input metadata,
and process validated `EV_KEY` press events. Ignore release events and avoid
turning kernel autorepeat into multiple unintended state transitions.

- `KEY_VOLUMEUP`: increment the validated playback mixer control.
- `KEY_VOLUMEDOWN`: decrement it.
- The validated microphone-mute key: toggle real capture mute and update the
  persistent red/off ring state.

### Mixer behavior

Use tinyalsa to open the real card, locate the validated controls by name,
query their ranges, clamp values, and update all relevant playback channels.
The step size should produce usable physical-button behavior without assuming
an Android `STREAM_MUSIC` range.

The microphone path must use the control proven by the discovery test. Failure
to find or change it must leave a clear diagnostic in logd and must not report a
successful mute merely because the LED changed.

## Implementation sequence

1. **Read-only hardware discovery**
   - Capture the microphone-mute button's `getevent` keycode while it is
     pressed.
   - Enumerate mixer controls and identify a safe, reversible real capture-mute
     control.
   - Confirm the current playback-volume control and its range.

2. **Implement the native core**
   - Add input polling, LED rendering, bounded startup retry, timer handling,
     and direct tinyalsa playback-volume updates.
   - Add the verified microphone-mute control only after step 1.

3. **Integrate cleanly**
   - Package and start `biscuitd` through init.
   - Replace, rather than run alongside, `led-bootstrap.sh`.
   - Add static product checks and a small host test for frame rendering,
     clamping, and key-event handling.

4. **Build and validate on Biscuit**
   - Build an OTA, preflight it, sideload without wiping data, and verify two
     clean boots.
   - Validate volume up/down, one-second level feedback, mute/unmute feedback,
     real microphone capture mute, and that Wi-Fi/audio bootstrap still works.

## Acceptance criteria

- One native `biscuitd` process owns LED, button, volume, and mute behavior.
- No Android framework, Java component, `biscuit-ledd`, or competing LED helper
  is packaged for this role.
- Volume buttons change actual speaker playback volume and show bounded green
  feedback.
- The mute button changes actual microphone capture state and shows red/off
  state correctly.
- Missing hardware nodes or controls fail safely without boot failure, busy
  loops, or fake success.
