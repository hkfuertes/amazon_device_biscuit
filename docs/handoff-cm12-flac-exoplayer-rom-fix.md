# Handoff: CM12.1 Biscuit FLAC / ExoPlayer ROM fix

Next skill: `diagnose`.

## Goal

Fix FLAC playback at the CM12.1 Biscuit ROM/framework level so Ava can keep using ExoPlayer/MediaCodec without the AirHass FLAC stream going silent. Avoid app-side full switch to `android.media.MediaPlayer`, because that made AirHass audible but user reported Assist then stopped working.

## Current evidence

Repo: `/home/hkfuertes/projects/amazon_device_biscuit`
Branch created for this handoff: `handoff/cm12-flac-exoplayer-rom-fix`

Ava repo context:
- `/home/hkfuertes/projects/Ava`
- AirHass sends HA media-player URL like `http://192.168.77.254:<port>/stream-*.flac` with `media_content_type=audio/flac`.
- WAV via Ava media_player works.
- FLAC via Ava ExoPlayer path reports playback but is silent.
- Temporary Ava branch `fix/media-player-flac-playback` commit `8119499` replaced `AudioPlayer` with `android.media.MediaPlayer`; FLAC and AirHass became audible, but user reported Assist broke. Do not use as final unless the app route is revisited carefully.
- A later uncommitted Ava experiment on `fix/exoplayer-flac-airhass` tried an ExoPlayer `MediaCodecSelector` hypothesis; ROM fix is preferred.

Live ExoPlayer repro log on Biscuit:

```text
I/ExoPlayerImpl: Init ... [AndroidXMedia3/1.8.0] [biscuit, Echo Dot, amazon, 22]
E/SoftOMXPlugin: unable to dlopen libstagefright_soft_flacdec.so: dlopen failed: library "libstagefright_soft_flacdec.so" not found
E/OMX: FAILED to allocate omx component 'OMX.google.flac.decoder'
D/AudioPlayer: onIsPlayingChanged: isPlaying=true
I/ExoPlayerImpl: Release ...
```

Device state checked:

```text
/system/etc/media_codecs.xml
/system/etc/media_codecs_ffmpeg.xml
/system/etc/media_codecs_google_audio.xml
/system/etc/audio_policy.conf
/system/etc/media_codecs_ffmpeg.xml:        <MediaCodec name="OMX.ffmpeg.flac.decoder"   type="audio/flac" >
/system/etc/media_codecs_google_audio.xml:  <MediaCodec name="OMX.google.flac.decoder" type="audio/flac">
```

Device libraries checked:

```text
/system/lib/libstagefright_soft_flacenc.so exists
/system/lib/libstagefright_soft_flacdec.so is missing
/system/lib/libffmpeg_extractor.so exists
/system/lib/libffmpeg_omx.so exists
/system/lib/libffmpeg_utils.so exists
```

ROM source findings:

- `patches/cm12-biscuit-frameworks-av-flacdec.patch` adds `frameworks/av/media/libstagefright/codecs/flac/dec/Android.mk` and `SoftFlacDecoder.cpp` for module `libstagefright_soft_flacdec`.
- `patches/cm12-biscuit-frameworks-av-flacdec-acodec.patch` adjusts `ACodec.cpp` to handle FLAC decode setup.
- Workspace has the patched source files present:
  - `workspace/cm12/frameworks/av/media/libstagefright/codecs/flac/dec/Android.mk`
  - `workspace/cm12/frameworks/av/media/libstagefright/codecs/flac/dec/SoftFlacDecoder.cpp`
- But existing build output has no decoder library:

```sh
find workspace/cm12/out-docker -iname '*soft_flacdec*' | wc -l   # 0
find workspace/cm12/out-docker -iname '*soft_flacenc*' | wc -l   # 7
```

- Product config appears to request the decoder:
  - `sources/device_amazon_mt8163_common/mt8163-common.mk:41` has `PRODUCT_PACKAGES += libstagefright_soft_flacdec`
  - `workspace/cm12/device/amazon/mt8163-common/mt8163-common.mk:41` same
  - `workspace/cm12/device/amazon/biscuit/device.mk:8` inherits `device/amazon/mt8163-common/mt8163-common.mk`

- Main codec XML is likely wrong/minimal:

```xml
<!-- workspace/cm12/device/amazon/biscuit/media_codecs.xml -->
<MediaCodecs>
    <Include href="media_codecs_google_audio.xml" />
</MediaCodecs>
```

The output/system main XML also only includes Google audio. `media_codecs_ffmpeg.xml` exists on `/system/etc`, but if it is not included by the root `media_codecs.xml`, MediaCodec clients may not enumerate `OMX.ffmpeg.flac.decoder`.

## Ranked hypotheses

1. `OMX.google.flac.decoder` is advertised but broken because `libstagefright_soft_flacdec.so` is not installed. ExoPlayer/MediaCodec tries it and silently fails/misreports playback.
2. `OMX.ffmpeg.flac.decoder` could be usable, but the main `/system/etc/media_codecs.xml` does not include `media_codecs_ffmpeg.xml`, so framework enumeration probably misses it.
3. Even after including ffmpeg XML, ExoPlayer may still choose Google first unless the ROM orders ffmpeg before Google or removes the broken Google FLAC entry.
4. The proper final fix is to make `libstagefright_soft_flacdec.so` actually build/package, then Google FLAC is no longer broken. The fastest validation fix is to expose/prefer ffmpeg FLAC and hide broken Google FLAC.

## Minimal ROM test patch

Try the smallest ROM-level change first:

```diff
diff --git a/sources/device_amazon_biscuit/media_codecs.xml b/sources/device_amazon_biscuit/media_codecs.xml
@@
 <MediaCodecs>
+    <Include href="media_codecs_ffmpeg.xml" />
     <Include href="media_codecs_google_audio.xml" />
 </MediaCodecs>
```

Also apply the same to the workspace copy if testing without full source staging:

```diff
diff --git a/workspace/cm12/device/amazon/biscuit/media_codecs.xml b/workspace/cm12/device/amazon/biscuit/media_codecs.xml
@@
 <MediaCodecs>
+    <Include href="media_codecs_ffmpeg.xml" />
     <Include href="media_codecs_google_audio.xml" />
 </MediaCodecs>
```

Why ffmpeg before Google: Ava currently uses ExoPlayer with default decoder fallback off. If both decoders are listed and Google appears first, ExoPlayer may still pick the broken one. Ordering ffmpeg first is the lazy validation.

If that still chooses Google or stays silent, make a test XML that removes/comment-outs only the Google FLAC decoder entry from `media_codecs_google_audio.xml` until `libstagefright_soft_flacdec.so` is built. Do not remove Google audio wholesale; MP3/AAC/etc may rely on it.

## Proper ROM fix path

Make `libstagefright_soft_flacdec` actually appear in the product image:

1. Verify module is visible to make:
   ```sh
   cd workspace/cm12
   source build/envsetup.sh
   lunch cm_biscuit-userdebug
   mmm frameworks/av/media/libstagefright/codecs/flac/dec
   ```
   Use this repo's Docker build wrapper if host env is not configured.

2. If module is not visible, check Android make traversal. `frameworks/av/media/libstagefright/codecs/Android.mk` currently contains:
   ```make
   include $(call all-makefiles-under,$(LOCAL_PATH))
   ```
   so the new `codecs/flac/dec/Android.mk` should be discovered. If not, the parent makefile may not be included by the product build path.

3. If module builds but does not package, keep/fix:
   ```make
   PRODUCT_PACKAGES += \
       libstagefright_soft_flacdec
   ```
   in `sources/device_amazon_mt8163_common/mt8163-common.mk` and workspace copy.

4. Rebuild OTA/system image and confirm:
   ```sh
   adb shell 'ls -l /system/lib/libstagefright_soft_flacdec.so'
   adb shell 'grep -R "OMX.*flac" -n /system/etc/media_codecs*.xml'
   ```

5. Install normal Ava master/ExoPlayer APK, no MediaPlayer branch, then replay one FLAC URL through HA media_player. Expected:
   - audible FLAC
   - no `unable to dlopen libstagefright_soft_flacdec.so`
   - Assist still works

## Validation loop

No need for AirHass initially. Use one deterministic HA media_player call with a short FLAC tone served from laptop:

```sh
# laptop source IP used previously: 192.168.77.137
# device: 192.168.77.150
# HA: http://192.168.77.254
```

Expected existing failure with ExoPlayer before ROM fix:
- HA state goes `playing`/`idle`.
- App log says ExoPlayer `onIsPlayingChanged=true`.
- No audible FLAC.
- Log contains missing `libstagefright_soft_flacdec.so`.

Expected pass after ROM fix:
- audible FLAC tone/AirHass.
- no missing-decoder log.
- Ava Assist start/stop still works.

## Notes

- Do not commit sensitive HA token or Wi-Fi credentials.
- User prefers event-driven behavior; avoid fake waits/offsets.
- If touching this ROM repo, stay on a branch first. Current handoff branch already exists.
