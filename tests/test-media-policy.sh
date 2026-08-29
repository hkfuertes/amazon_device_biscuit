#!/usr/bin/env bash
# Guard the declared media policy without requiring a CM12 checkout.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
POLICY="$REPO_ROOT/docs/sources.md"
MEDIA="$REPO_ROOT/device/amazon/biscuit/media_codecs.xml"

[[ ! -e "$REPO_ROOT/scripts/disable-mtk-omx-codecs.sh" ]]
! grep -q 'disable-mtk-omx-codecs' "$REPO_ROOT/scripts/stage-tree.sh"
! grep -qi 'OMX\.MTK\|mtk_omx' "$MEDIA"
grep -Fqx '    <Include href="media_codecs_ffmpeg.xml" />' "$MEDIA"
grep -Fqx '    <Include href="media_codecs_google_audio.xml" />' "$MEDIA"
grep -Fq 'MTK OMX and its libraries are not extracted, staged, advertised, or integrated.' "$POLICY"
grep -Fq 'Google, FFmpeg, and FLAC codecs are built from source.' "$POLICY"
grep -Fq 'The supported variant remains `userdebug`:' "$POLICY"

echo 'PASS media policy excludes OMX MTK and retains source codecs/userdebug'
