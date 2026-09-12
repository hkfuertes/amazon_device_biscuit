#!/usr/bin/env bash
# Stage verified Fire OS 6 audio plus the proven stock Biscuit headless HWC closure.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CM14="${CM14:-$REPO_ROOT/workspace/cm14.1}"
OTA_URL="https://d1s31zyz7dcc2d.cloudfront.net/2026/8/3/f49aaff7-dd63-4d9c-9e9a-c17498267de5/update-kindle-biscuit_puffin-NS6574_user_7623_0013121734532.bin"
OTA_SHA256="64ab6d2dd85f8093abdd62c275d229c7e9fdd68e4d46892b48bdbd1d100d46d8"
OTA="$REPO_ROOT/workspace/downloads/$(basename "$OTA_URL")"
SYSTEM_IMG="$REPO_ROOT/workspace/extracted/biscuit-fireos-6.5.7.4/system.img"
SYSTEM_SHA256="eccfa850c3009d5454f69a411c0b757be642059b3224cae8fc941fa0dd22c570"
MANIFEST="$REPO_ROOT/cm14.1/vendor/amazon/mt8163-common/fireos6-audio-files.txt"
STOCK_HWC_SYSTEM_IMG="$REPO_ROOT/workspace/extracted/biscuit-stock-272.6.4.1/system.img"
STOCK_HWC_SYSTEM_SHA256="bd928aa5087b8d8c40095c784dfc159cc2555ed4130d617b258bfd0a06659f7c"
STOCK_HWC_OTA_SHA256="28bc050e4a2af79c9ca66e251de7bf04c42ce8d7934dd97673d3d04f5fa0917b"
HWC_MANIFEST="$REPO_ROOT/cm14.1/vendor/amazon/mt8163-common/biscuit-headless-hwc-files.txt"
RADIO_MANIFEST="$REPO_ROOT/cm14.1/vendor/amazon/mt8163-common/biscuit-radio-files.txt"
COMMON_OUT="$CM14/vendor/amazon/mt8163-common"
PROP="$COMMON_OUT/proprietary"
mkdir -p "$REPO_ROOT/workspace/tmp"
TMP="$(mktemp -d "$REPO_ROOT/workspace/tmp/cm14-fireos6-audio.XXXXXXXXXX")"
trap 'rm -rf "$TMP"' EXIT

for tool in 7z curl python3 readelf sha256sum stat unzip; do
  command -v "$tool" >/dev/null || { echo "ERROR: required tool not found: $tool" >&2; exit 1; }
done
if ! command -v patchelf >/dev/null && ! command -v docker >/dev/null; then
  echo "ERROR: patchelf is unavailable and Docker is not installed." >&2
  exit 1
fi
[[ -d "$CM14/build" ]] || { echo "ERROR: CM14.1 is not synced at $CM14" >&2; exit 1; }
if ! command -v patchelf >/dev/null; then
  docker image inspect cm14.1-ubuntu20:latest >/dev/null 2>&1 && \
    docker run --rm --network none --entrypoint patchelf cm14.1-ubuntu20:latest \
      --version >/dev/null 2>&1 || {
      echo "ERROR: rebuild cm14.1-ubuntu20:latest with patchelf before staging audio blobs." >&2
      exit 1
    }
fi
[[ -f "$MANIFEST" ]] || { echo "ERROR: missing audio manifest: $MANIFEST" >&2; exit 1; }
[[ -f "$HWC_MANIFEST" ]] || { echo "ERROR: missing headless HWC manifest: $HWC_MANIFEST" >&2; exit 1; }
[[ -f "$RADIO_MANIFEST" ]] || { echo "ERROR: missing Biscuit radio manifest: $RADIO_MANIFEST" >&2; exit 1; }

mkdir -p "$(dirname "$OTA")" "$(dirname "$SYSTEM_IMG")" "$REPO_ROOT/workspace/tmp"
if [[ ! -f "$OTA" ]]; then
  curl --fail --location --progress-bar -o "$OTA" "$OTA_URL"
fi
printf '%s  %s\n' "$OTA_SHA256" "$OTA" | sha256sum -c -
unzip -t "$OTA" >/dev/null

if [[ ! -f "$SYSTEM_IMG" ]] || ! printf '%s  %s\n' "$SYSTEM_SHA256" "$SYSTEM_IMG" | sha256sum -c - >/dev/null 2>&1; then
  rm -f "$SYSTEM_IMG"
  python3 "$REPO_ROOT/scripts/extract-fireos6-payload.py" "$OTA" system "$SYSTEM_IMG"
fi
printf '%s  %s\n' "$SYSTEM_SHA256" "$SYSTEM_IMG" | sha256sum -c -

if [[ ! -f "$STOCK_HWC_SYSTEM_IMG" ]] || ! printf '%s  %s\n' "$STOCK_HWC_SYSTEM_SHA256" "$STOCK_HWC_SYSTEM_IMG" | sha256sum -c - >/dev/null 2>&1; then
  rm -f "$STOCK_HWC_SYSTEM_IMG"
  BISCUIT_STOCK_OTA_SHA256="$STOCK_HWC_OTA_SHA256" \
    "$REPO_ROOT/scripts/prepare-biscuit-stock-system-image.sh"
fi
printf '%s  %s\n' "$STOCK_HWC_SYSTEM_SHA256" "$STOCK_HWC_SYSTEM_IMG" | sha256sum -c -

rm -rf "$PROP"
mkdir -p "$PROP"
copy_files=()
blob_count=0

extract_file() {
  local image="$1" source="$2" destination="$3" expected_sha="$4" expected_size="$5"
  rm -rf "$TMP/unpack"
  7z x -y -o"$TMP/unpack" "$image" "$source" >/dev/null 2>&1 || true
  local extracted="$TMP/unpack/$source"
  [[ -f "$extracted" ]] || { echo "ERROR: missing source file: $source" >&2; exit 1; }
  [[ "$(stat -c %s "$extracted")" == "$expected_size" ]] || { echo "ERROR: wrong size: $source" >&2; exit 1; }
  [[ "$(sha256sum "$extracted" | awk '{print $1}')" == "$expected_sha" ]] || {
    echo "ERROR: SHA-256 mismatch: $source" >&2; exit 1;
  }
  local mode=0644
  case "$destination" in
    bin/*) mode=0755 ;;
  esac
  install -D -m "$mode" "$extracted" "$PROP/$destination"
  copy_files+=("vendor/amazon/mt8163-common/proprietary/$destination:\$(TARGET_COPY_OUT_SYSTEM)/$destination")
  ((blob_count += 1))
}

while IFS=: read -r source destination expected_sha expected_size; do
  [[ -z "$source" || "$source" == \#* ]] && continue
  [[ "$destination" != /* && "$destination" != *".."* ]] || {
    echo "ERROR: unsafe destination in manifest: $destination" >&2; exit 1;
  }
  extract_file "$SYSTEM_IMG" "$source" "$destination" "$expected_sha" "$expected_size"
done < "$MANIFEST"
audio_count="$blob_count"

hwc_count=0
while IFS=: read -r source destination expected_sha expected_size; do
  [[ -z "$source" || "$source" == \#* ]] && continue
  [[ "$destination" != /* && "$destination" != *".."* ]] || {
    echo "ERROR: unsafe destination in HWC manifest: $destination" >&2; exit 1;
  }
  extract_file "$STOCK_HWC_SYSTEM_IMG" "$source" "$destination" "$expected_sha" "$expected_size"
  ((hwc_count += 1))
done < "$HWC_MANIFEST"
[[ "$hwc_count" == 1 ]] || { echo "ERROR: expected one headless HWC blob, got $hwc_count" >&2; exit 1; }

radio_count=0
while IFS=: read -r source destination expected_sha expected_size; do
  [[ -z "$source" || "$source" == \#* ]] && continue
  [[ "$destination" != /* && "$destination" != *".."* ]] || {
    echo "ERROR: unsafe destination in radio manifest: $destination" >&2; exit 1;
  }
  extract_file "$STOCK_HWC_SYSTEM_IMG" "$source" "$destination" "$expected_sha" "$expected_size"
  ((radio_count += 1))
done < "$RADIO_MANIFEST"
[[ "$radio_count" == 14 ]] || { echo "ERROR: expected 14 radio blobs, got $radio_count" >&2; exit 1; }

for config in \
  etc/a2dp_audio_policy_configuration.xml \
  etc/audio_device.xml \
  etc/audio_policy.conf \
  etc/audio_policy_configuration.xml \
  etc/audio_policy_volumes.xml \
  etc/r_submix_audio_policy_configuration.xml \
  etc/usb_audio_policy_configuration.xml; do
  rm -rf "$TMP/unpack"
  7z x -y -o"$TMP/unpack" "$SYSTEM_IMG" "system/$config" >/dev/null 2>&1 || true
  [[ -f "$TMP/unpack/system/$config" ]] || { echo "ERROR: missing Fire OS audio config: $config" >&2; exit 1; }
  install -D -m 0644 "$TMP/unpack/system/$config" "$PROP/$config"
  copy_files+=("vendor/amazon/mt8163-common/proprietary/$config:\$(TARGET_COPY_OUT_SYSTEM)/$config")
done

rm -rf "$TMP/algorithms"
7z x -y -o"$TMP/algorithms" "$SYSTEM_IMG" 'system/vendor/etc/audio-algorithms/*' >/dev/null 2>&1 || true
algorithm_dir="$TMP/algorithms/system/vendor/etc/audio-algorithms"
[[ -d "$algorithm_dir" ]] || { echo "ERROR: missing Fire OS audio algorithms" >&2; exit 1; }
algorithm_count="$(find "$algorithm_dir" -type f -printf . | wc -c | tr -d '[:space:]')"
[[ "$algorithm_count" == 40 ]] || {
  echo "ERROR: unexpected Fire OS audio algorithm count" >&2; exit 1;
}
install -d "$PROP/vendor/etc"
cp -a "$algorithm_dir" "$PROP/vendor/etc/audio-algorithms"

hal="$PROP/lib/hw/audio.primary_amazon.mt8163.so"
add_needed() {
  if command -v patchelf >/dev/null; then
    patchelf --add-needed "$1" "$hal"
  else
    docker run --rm --network none --user "$(id -u):$(id -g)" \
      -v "$PROP:/blobs" --entrypoint patchelf cm14.1-ubuntu20:latest \
      --add-needed "$1" /blobs/lib/hw/audio.primary_amazon.mt8163.so
  fi
}
add_needed libutils_shim.so
add_needed libtinyalsa_shim.so
readelf -dW "$hal" | grep -q '\[libutils_shim.so\]'
readelf -dW "$hal" | grep -q '\[libtinyalsa_shim.so\]'

{
  cat <<'MK'
# Generated by scripts/extract-cm14-fireos6-audio-blobs.sh.
# Fire OS 6.5.7.4 audio closure plus stock Biscuit's proven headless HWC; blobs are intentionally untracked.
LOCAL_PATH := $(call my-dir)

PRODUCT_COPY_FILES += \
MK
  for ((i = 0; i < ${#copy_files[@]}; i++)); do
    suffix=$' \\'
    [[ $i -eq $((${#copy_files[@]} - 1)) ]] && suffix=''
    printf '    %s%s\n' "${copy_files[$i]}" "$suffix"
  done
  cat <<'MK'

PRODUCT_COPY_FILES += \
    $(call find-copy-subdir-files,*,$(LOCAL_PATH)/proprietary/vendor/etc/audio-algorithms,$(TARGET_COPY_OUT_SYSTEM)/vendor/etc/audio-algorithms)
MK
} > "$COMMON_OUT/mt8163-common-vendor.mk"

echo "Staged $audio_count verified Fire OS 6 audio blobs, 40 algorithm files, $hwc_count headless HWC blob, and $radio_count Biscuit radio files."
