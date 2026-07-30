# Audio codec smoke tests

Small local samples live in:

```txt
testdata/audio/sample-3s.mp3
testdata/audio/wake_word_triggered.flac
testdata/audio/start_listening_button.flac
```

Push samples:

```sh
adb push testdata/audio/sample-3s.mp3 /data/local/tmp/sample-3s.mp3
adb push testdata/audio/wake_word_triggered.flac /data/local/tmp/wake_word_triggered.flac
```

Play through Android `ACTION_VIEW` / CM Eleven preview:

```sh
adb shell 'am start -W -a android.intent.action.VIEW \
  -d file:///data/local/tmp/sample-3s.mp3 \
  -t audio/mpeg'

adb shell 'am start -W -a android.intent.action.VIEW \
  -d file:///data/local/tmp/wake_word_triggered.flac \
  -t audio/flac'
```

Capture focused logs:

```sh
adb logcat -c
# run one playback command
adb logcat -d -v time | grep -Ei 'MediaCodec|MediaCodecList|OMX|Stagefright|FFmpeg|MediaPlayer|AudioTrack|AudioFlinger|flac|mp3|mpeg|Exception|error|fatal|SIGABRT' | tail -200
```

Observed on current live image, 2026-07-30:

- MP3 via `ACTION_VIEW` opens `com.cyanogenmod.eleven/.ui.activities.preview.AudioPreviewActivity` and plays sound.
- MP3 path logs `FFmpegExtractor`, then official Stagefright handles `audio/mpeg`, then `AudioTrack`/`AudioFlinger`.
- FLAC via `ACTION_VIEW` starts the same Eleven preview activity but `am start -W` can hang/time out and no clear playback was heard.

Useful MP3 log lines:

```txt
FFmpegExtractor: ffmpeg detected media content as 'audio/mpeg'
FFmpegExtractor: suppoted codec(mp3) by official Stagefright
AudioTrack::set : Exit
```
