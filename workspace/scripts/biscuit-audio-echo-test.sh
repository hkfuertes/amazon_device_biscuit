#!/usr/bin/env bash
# Record, save WAV, and play back through Android AudioRecord/AudioTrack -> AudioFlinger -> Audio HAL.
set -euo pipefail

ADB="${ADB:-adb}"
REMOTE_BIN="${REMOTE_BIN:-/system/bin/biscuit_audio_echo_test}"
REMOTE_WAV="${1:-/sdcard/biscuit-echo-test.wav}"
SECONDS_TO_RECORD="${SECONDS_TO_RECORD:-3}"

say() { printf '==> %s\n' "$*"; }

say "checking device + HAL test binary"
"$ADB" devices -l
"$ADB" shell "test -x '$REMOTE_BIN' && ls -l '$REMOTE_BIN'"

say "clearing old capture + logcat"
"$ADB" shell "rm -f '$REMOTE_WAV'"
"$ADB" logcat -c || true

say "recording + playback via AudioRecord/AudioTrack (${SECONDS_TO_RECORD}s)"
"$ADB" shell "'$REMOTE_BIN' '$SECONDS_TO_RECORD' '$REMOTE_WAV'; ls -l '$REMOTE_WAV'"

say "audio HAL log from this run"
"$ADB" logcat -d -v brief | grep -Ei 'audio\.amazon_wrapper|AudioFlinger|AudioPolicy|AudioALSA(StreamManager|StreamIn|StreamOut|Hardware)|openInputStream|openOutputStream|AudioRecord|AudioTrack|cannot|error|mPcm == NULL' | tail -120 || true
