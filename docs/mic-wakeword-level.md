# Microphone level and wake word (microWakeWord) — Biscuit

Status: diagnosis complete, partial fix applied, pending validation with real AVA.

Related: `docs/audio-beam-direction.md` (ASP/beam/LED). Do not duplicate its
content.

## Symptom

Stock FireOS detects “Alexa” from the other end of the room (~5 m). With CM12 +
AVA, the wake word only fires from ~10 cm away.

## Root cause

**This is not an audio-chain problem.** It is an absolute-level mismatch between
what the HAL provides and what microWakeWord expects.

- AVA uses **microWakeWord** with the `okay_nabu` model (observed in `ava5/echo-biscuit-support/.../BiscuitMuteControllerTest.kt`: `{"wakeWords":["okay_nabu"],"microWakeWords":["okay_nabu"]}`).
- microWakeWord targets ESP32-S3 devices with a close microphone and **has no AGC**. It classifies directly from a mel spectrogram, which is sensitive to **absolute amplitude**. Its models are trained with speech at normal levels (~-25 dBFS).
- Biscuit capture delivers **-69 dBFS**, about 40 dB below the training range. Features fall out of distribution and the network does not fire.
- Amazon's wake-word engine normalizes level before classification, so stock operation is unaffected by the same analog gain.

The inverse-square-law calculation agrees:

```
10 cm -> 5 m  =  20*log10(500/10)  =  34 dB
```

About 34 dB more level is required for room-scale range.

## What was ruled out (with evidence)

All of these hypotheses were investigated and ruled out. Do not reopen them
without new evidence.

### “AudioRecord is 256x lower than raw” was a scaling artifact

`biscuit_mic_test` reports **24-bit** full scale (±8388607).
`biscuit_audiorecord_test` reports **16-bit** full scale (±32767). Normalized:

| Measurement | rms | full scale | dBFS |
|---|---|---|---|
| raw tinyalsa | 3000 | 8388608 | -69.0 |
| AudioRecord | 11 | 32768 | -69.5 |

It is the same level. The HAL does not lose a single dB. The factor of 256 was
exactly the 24-bit versus 16-bit difference.

### NVRAM / MTK audio parameters — irrelevant

- The HAL does not touch NVRAM in the capture path: zero calls to `GetAudioCustomParamFromNV`, `SetCaptureGain`, or `SetMicGain` in logcat during an `openInputStream`.
- Biscuit **does not have** `nvdata`, `nvram`, or `proinfo` partitions. It has only `persist`. Amazon uses IDME, not MTK NVRAM. `nvram_daemon` would add nothing.
- Actual partitions: `boot boot_a boot_a_x boot_b boot_b_x cache dkb expdb kb lk lk_a lk_b misc persist recovery system system_a system_b tee1 tee2 userdata`.

### Microphone calibration — present and valid

`libasp.so` reads `/proc/idme/miccal.<n>` and `/proc/idme/board_id`.
The device has `miccal.0`..`miccal.6` (seven microphones) with valid values
(18150, 17869, 15532, 16924, 17377, 17108, 13429). The error
`ERROR! micCals[%d]=0! PLEASE CHECK IDME MIC VALUE!` does not appear.

### Mixer / audio_init.sh — correctly applied

The live mixer state exactly matches `audio_init.sh`.
`INPUT_GAIN_SEL=0` means “0 dB”, so `DIF1_L Input Gain = Off` is correct.

### ASP passthrough — not the switch

`libasp.so` exposes `persist.asp.asr.passthrough`, `persist.asp.voice.passthrough`,
and `persist.asp.speaker.passthrough`. None is defined on the device.
A/B testing `true`/`false` four times: rms 10, 7, 8, 8 (noise, no difference),
and the log always reports the same `PipelineAsr in 6 9 16000 out 1 1 16000`.

### RMS level does not measure whether beamforming works

A normalized beamformer (delay-and-sum / MVDR) maintains **unit gain** in its
look direction; it improves **SNR**, not absolute level. An ASP output within
-0.8 dB of an individual microphone is normal. There is no “8 dB deficit”.

### `ADC_A Digital Volume Control = 88` — not a functional bug

```c
static const DECLARE_TLV_DB_SCALE(adc_3101_vol_tlv, -1200, -50, 0);
SOC_DOUBLE_R_SX_TLV("ADC_A Digital Volume Control",
                    ADC_LADC_VOL(0), ADC_RADC_VOL(0), 0, 0x28, 0x68, ...);
```

`snd_soc_info_volsw_sx` defines `max = 0x68 - 0x28 = 64`, and `get` calculates
`(reg - xmin) & 0x7F`. Solving for the observed 88:
`(reg - 40) & 127 = 88` -> `reg = 0x00`, which is the correct 0 dB reset
default. There is no hidden attenuation.

What is broken is **writing**: ALSA 0–64 maps to registers `0x28`–`0x68`, and
`0x29`–`0x67` is a reserved TLV320AIC3101 range. Fixing it requires changing the
driver and rebuilding the kernel. **Do not do this**: codec digital gain does
not improve SNR, and the level microWakeWord needs can be obtained more cheaply
in the wrapper.

### Broken `mtk-msdc.0` symlink — near-zero impact

```
init.mt8163.rc:59   symlink /dev/block/platform/soc/11230000.mmc   <- destination does NOT exist, wins
init.device.rc:4    symlink /dev/block/platform/soc                <- correct, same as stock
```

Both are `on fs`; the one parsed first creates the symlink and the second fails
with `EEXIST`. Only `bin/idme` and `lib/libnvram.so` use it, neither critical
(`/proc/idme` is exposed by the kernel and works). A trivial fix
(`soc/11230000.mmc` -> `soc`) is available if `bin/idme` is ever needed.

## Reference measurements

PGA sweep across all four ADCs, medians from interleaved 5-second captures
(40/80/40/80/40/80) to cancel ambient-noise drift:

| PGA | dB | raw rms | raw dBFS | AudioRecord rms | AR dBFS | AR peak |
|---|---|---|---|---|---|---|
| 40 | 20 dB | 4781 | -64.9 | 17 | -65.7 | 682 (2% FS) |
| 80 | 40 dB | 49902 | -44.5 | 91 | -51.1 | 12559 (38% FS) |

```
delta raw          +20.4 dB  (expected +20.0)  -> PGA scales linearly
delta AudioRecord  +14.6 dB                    -> ASP AGC absorbs ~5 dB
clipping           none (raw peak 16% FS)
```

Measured in silence, with ambient noise. **Not validated while the speaker is
playing.**

## Who sets the analog gain

| Layer | Value | Owner |
|---|---|---|
| TLV320ADC3101 chip | 0–119 (0–59.5 dB) | Texas Instruments |
| `tlv320aic3101.c` driver (`xmax = 0x50`) | 0–80 (0–40 dB) | Amazon (caps the chip) |
| `audio_init.sh` | 40 (20 dB) | Amazon |
| Driver initialization table (`MIC_PGA_GAIN_IDC`) | 20 dB | Amazon |

The five only `MICPGA` occurrences in the 800 MB stock `system.img` are the
five `audio_init.sh` lines. No blob changes it at runtime:

```
lib/hw/audio.primary_amazon.mt8163.so   0
lib/libasp.so                           0
lib/libaudiosetting.so                  0
lib/libaudiocustparam.so                0
lib/libaudiocomponentengine.so          0
```

Stock always runs with permanent 20 dB. This is a deliberate Amazon decision,
made twice, and it likely preserves AEC headroom (the speaker is centimeters
from the microphones).

## Current state

Vendor patch `patches/vendor/20-microphone-pga-70.patch`:

```
A_PGA_L="40" -> "70"     (20 dB -> 35 dB)
A_PGA_R="40" -> "70"
A_PGA_R_LINEIN="46"      <- unchanged
```

It applies after extracting `etc/audio_init.sh` from `system.img`. If the stock
format changes, the patch does not apply and extraction aborts with a diagnosis;
calibration is never silently rewritten.

It provides ~+11 dB in AudioRecord: estimated range 10 cm -> ~35 cm.
It helps, but it is the **worse** of the two available levers (see below).

## Revised target: 2 m, not 5 m

```
10 cm -> 5 m :  20*log10(50) = 34 dB
10 cm -> 2 m :  20*log10(20) = 26 dB
```

That is 8 dB less, exactly the difference between “forced” and “comfortable”.
Beyond 2–3 m, room reverberation becomes the limiting factor rather than level;
gain cannot fix it.

### Gain budget

From the measured sweep, +20 dB raw PGA yielded **+14.6 dB in AudioRecord**
(the ASP AGC absorbs the rest). Transfer factor ~0.73:

| Configuration | dB in AudioRecord | Estimated range |
|---|---|---|
| PGA 40 (stock) | 0 | 10 cm |
| PGA 70 (current commit) | +11 | ~35 cm |
| PGA 80 (maximum analog) | +14.6 | ~55 cm |
| PGA 80 + 11 dB digital | +26 | **2 m** |
| PGA 80 + 19 dB digital | +34 | 5 m |

Analog PGA alone **does not reach 1 m**. Digital gain is required.

### Why digital gain is the better lever here than PGA

1. **Neither improves SNR.** The ADC has ~92 dB SNR (floor below -90 dBFS) and the signal is at -65 dBFS: 27 dB above the electronic floor. Room acoustic noise dominates, not the ADC. Raising analog PGA is equivalent here to multiplying digitally.
2. **PGA does consume AEC headroom** (the speaker is centimeters from the microphones). Gain in `audio_wrapper.c` is applied **after** all HAL processing, so it is harmless to AEC.
3. **Hot-tunable** through a property, without recompiling or reflashing.
4. **Precisely clampable**.

Conclusion: PGA 70 is not wrong, but the wrapper should be the primary lever.

### Why fixed gain is insufficient, and AGC is required

At PGA 80, the AudioRecord peak reached **38% FS with only ambient noise**
(rms -51 dBFS, peak -8.3 dBFS -> crest factor 43 dB, an impulsive transient).
Multiplying that by 3.6 clips.

A fixed gain calibrated to fire at 2 m **will clip** when someone speaks close
by or during impulsive noise. The correct approach is **slow normalization
toward a target RMS** (~-25 dBFS) with a limiter: exactly what Amazon's engine
does and what microWakeWord does not include. It takes ~40 lines rather than
~20, but handles both nearby and distant speech instead of choosing one.

## State after the real test

The functional AVA/microWakeWord test passed **with only the analog-gain
increase**. For now, there is no need to flash or validate the experimental
AOSP/WebRTC AGC build.

Post-HAL baseline measurement before flashing AGC:

```txt
adb shell biscuit_audiorecord_test 5 6
samples=80128 rms=76 peak=1894 source=6
```

## Pending plan

1. **Leave PGA at 70 while it works.** Do not increase it to 80: it adds no SNR and removes AEC headroom.
2. **Do not flash AGC for now.** Resume only if the wake word again fails at the target distance, false negatives appear, or greater near/far range is needed.
3. **If the problem returns**, prefer AGC/limiting in `audio_wrapper.c`: it is our code and already wraps the HAL, so it can intercept `in->read()` before returning AudioRecord.
4. **Validate AEC with loud music** before treating the PGA as final:
   - raw must not clip (`peak` near 8388607 in `biscuit_mic_test`)
   - the wake word must still fire while the speaker is playing
   If it clips, lower PGA to 50–60 and compensate in the wrapper.

## How to reproduce the measurements

```sh
# raw level (24-bit full scale) and post-HAL level (16-bit full scale)
adb shell biscuit_mic_test 5
adb shell biscuit_audiorecord_test 5 6      # 6 = VOICE_RECOGNITION

# current analog gain and range
adb shell tinymix "ADC_A MICPGA Volume Ctrl"

# factory microphone calibration
adb shell 'for i in 0 1 2 3 4 5 6; do cat /proc/idme/miccal.$i; echo; done'

# ASP pipeline trace during capture
adb shell logcat -c
adb shell biscuit_audiorecord_test 2 6
adb shell logcat -d | grep -iE 'AudioALSA|ASP|Pipeline'
```

To compare levels between the two tools, normalize by full scale:
`dBFS = 20*log10(rms/8388608)` for `biscuit_mic_test` and
`20*log10(rms/32768)` for `biscuit_audiorecord_test`. Do not compare their raw
values directly.

Ambient noise is not stationary: take interleaved 5-second captures between
comparison points, then use the median rather than a single sample.
