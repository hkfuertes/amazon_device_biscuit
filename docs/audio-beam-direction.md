# Voice direction / ASP beam — Biscuit

## Summary

Stock does not appear to calculate direction directly in Alexa. The stock-blob
chain is:

```txt
libasp / audiosignalprocessor
  -> ASP callback with a beam/direction event
  -> stock audiohub
  -> LIPC beamDir event/property in com.doppler.audio
  -> stock ledd BeamDirection / BeamPattern
  -> ring animation
```

In the current CM12 build:

- `audiosignalprocessor` exists as a Binder service.
- `libasp.so` and `libaspclient.so` are present.
- `biscuit-ledd` is our simple Unix-socket daemon; it does not implement `BeamDirection`/`beamDir`.
- The Java `BiscuitService` is the right place to expose our public API; the shell wrapper should only call it.

## Stock evidence

Inspected local sources:

```txt
workspace/extracted/biscuit-stock-272.6.4.1/system.img
/tmp/biscuit-stock-led/audiohub
/tmp/biscuit-stock-led/ledd
/tmp/biscuit-stock-asp/libasp.so
/tmp/biscuit-stock-asp/libaspclient.so
```

Relevant strings:

### `bin/audiohub`

```txt
audiosignalprocessor
libaspclient.so
beamDir
E AudioHub:setBeamDirFailed:reason=unableToSendEvent,event=%s,err=%s:
E AudioHub:initASPFailed:reason=failedToRegisterASPEventListener:
E AudioHub:onEventFailed:reason=invalidSize,size=%d:
com.doppler.audio
```

### `bin/ledd`

```txt
com.doppler.ledd
Pattern
BeamPattern
BeamPatternOn
BeamPatternOff
BeamDirection
com.doppler.audiod
com.doppler.audio
beamDir
E LipcInterface:setBeamPattern:reason=invalidArg,val=%s:Bad argument
E LipcInterface:beamDirEvent:reason=invalidArg:Could not get beam value
WakeWordLEDComplete
```

### `libasp.so`

```txt
com.amazon.asp.IAudioEventListener
com.amazon.asp.IAudioSignalProcessor
audiosignalprocessor
AFE config mics %d beams %d speakers %d
AFEDiagBeamChangeCount
Beam change count: %d
```

Arbitration commands also appear, but they are probably not the direct direction
value:

```txt
ASP_CMD_REQUEST_ARBITRATION_DATA
{"sequenceID":%d,"voiceEnergy":%d,"ambientEnergy":%d}
```

## Check on the current CM12 build

Device readout:

```txt
service list | grep audiosignalprocessor
87 audiosignalprocessor: [com.amazon.asp.IAudioSignalProcessor]
```

This suggests that we can register a listener like stock `audiohub` without
porting all of `audiohub`.

## How to discover the actual value

Minimum test, with no persistent changes:

1. Temporarily build/push `biscuit_asp_beam_probe` to `/data/local/tmp`.
2. The probe registers a `com.amazon.asp.IAudioEventListener` with `audiosignalprocessor` through Binder.
3. Open capture with `AudioRecord` source `VOICE_RECOGNITION` (`6`) to activate `PipelineAsr`.
4. Discard audio; log only ASP events: `what`, `size`, raw bytes, and, if `size == 4`, interpret it as a candidate `beamDir` `int32`.
5. Speak from several positions and map the value to the physical ring sector.

Do not use audio playback for this test.

```sh
# from the amazon_device_biscuit root
scripts/stage-tree.sh

docker rm -f cm12-biscuit-build >/dev/null 2>&1 || true
docker run -d --name cm12-biscuit-build \
  -v "$PWD:$PWD" \
  -w "$PWD/workspace/cm12" \
  cm12-ubuntu14:latest \
  bash -lc 'source build/envsetup.sh >/dev/null && lunch cm_biscuit-userdebug && export OUT_DIR="$PWD/out-docker" && export PATH="$OUT_DIR/host/linux-x86/bin:$PATH" && mmm hardware/amazon/audio'

docker logs -f cm12-biscuit-build

adb push workspace/cm12/out-docker/target/product/biscuit/system/bin/biscuit_asp_beam_probe /data/local/tmp/
adb shell chmod 755 /data/local/tmp/biscuit_asp_beam_probe
adb shell /data/local/tmp/biscuit_asp_beam_probe 20
```

Expected output:

```txt
listening seconds=20 source=VOICE_RECOGNITION discard_audio=1
asp_event what=<n> size=<n> int32=<candidate> bytes=<hex>
done
```

## Search for precalculated angles (static RE)

Hypothesis: Amazon converts beam -> angle in a userspace blob, and we can copy
the table. Result: **it does not exist in userspace**.

Method: local disassembly with capstone+pyelftools (wheels in
`~/.local/lib/python3.13/site-packages`, no sudo), xref searches for strings
(pools, `R_ARM_RELATIVE` relocs, movw/movt), and a `.rodata` scan for
float/double tables in arithmetic progression (0,30,60... or radians).

Findings:

- `libasp.so`: 0 angle tables. The AFE in the DSP calculates the beam; libasp only receives the index and re-emits it through `ReportEvent(what=3, int32)`.
- The number of beams comes from AFE configuration at runtime (cloud-delivered WHA JSON): `AFE config mics %d beams %d speakers %d`. It is not hard-coded in the blob.
- `audiohub`: raw passthrough, without conversion (see the previous section).
- `ledd`: the `BeamPattern/BeamPatternOn/BeamPatternOff/BeamDirection/beamDir` string cluster is in `.rodata` (`0x4c1cc..0x4c2b3`) **with no reference** from code or data (probably dead code or handled by a library we did not extract). There is no beam-to-LED table.

Conclusion: `beamDir` is a raw AFE beam index end to end. Its relationship to
physical angles/positions must be measured empirically.

Resolution clue: the values observed during the first real test were `3,5,7,9,11`
(all odd). That fits **12 beams of 30°** (index x 30 = degrees:
90,150,210,270,330...), consistent with a 12-LED ring. This remains to be
confirmed with the mapping protocol.

## Empirical beam-to-physical-sector mapping protocol (pending)

1. Choose a physical ring reference (for example, buttons/cable connector).
2. Place a voice source in a loop (phone/speaker) at a fixed distance (~1 m).
3. For each position (front, 45°, right, 135°, behind, 225°, left, 315°), speak for 15–20 seconds while `biscuit_asp_beam_probe 25` runs.
4. Record the dominant `int32` for each position -> `beam idx -> sector` table.
5. Validate by repeating two positions; if the map is linear (`idx x 30 + offset`), interpolate the rest.

## Possible future Java `BiscuitService` support

Our public API should live in the Java service, not in the shell wrapper:

- Optional Binder/AIDL: `int getBeamDirection()` or `String beamStatus()`.
- Optional sticky broadcast:

```txt
com.amazon.biscuit.service.BEAM_DIRECTION_CHANGED
com.amazon.biscuit.service.EXTRA_BEAM_DIRECTION   int
```

Suggested minimum implementation:

```txt
native ASP listener/helper
  -> notifies the current direction to Java BiscuitService
  -> BiscuitService validates/rate-limits
  -> optionally sends a new command to biscuit-ledd
```

Reason for the native helper: `libaspclient.so` exposes a C++ Binder interface
(`com.amazon.asp.IAudioSignalProcessor`), not a Java/AIDL API already available
in the tree.

Minimum LED extension if we want to display it:

```txt
biscuit-ledd: BEAM <0..N-1> command
Java BiscuitService: set/get beam method/action
shell wrapper: thin client only, afterwards
```

Keep it lazy: first obtain a probe and value map; only then add a stable API.
