#!/usr/bin/env bash
# Verify target-scoped CM12 patches apply deterministically and repeat safely.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
CM12="$TMP/cm12"
PATCH_DIR="$TMP/patches"
mkdir -p "$CM12/build" "$PATCH_DIR"
printf 'one\n' > "$CM12/first.txt"
printf 'alpha\n' > "$CM12/second.txt"

cat > "$PATCH_DIR/10-first.patch" <<'PATCH'
--- a/first.txt
+++ b/first.txt
@@ -1 +1 @@
-one
+two
PATCH
cat > "$PATCH_DIR/20-second.patch" <<'PATCH'
--- a/second.txt
+++ b/second.txt
@@ -1 +1 @@
-alpha
+beta
PATCH

CM12="$CM12" PATCH_DIR="$PATCH_DIR" "$REPO_ROOT/scripts/apply-patches.sh" > "$TMP/first.log"
[[ "$(<"$CM12/first.txt")" == two ]]
[[ "$(<"$CM12/second.txt")" == beta ]]
sed -n '1p;2p' "$TMP/first.log" | diff -u - <(printf 'APPLIED 10-first.patch\nAPPLIED 20-second.patch\n')
CM12="$CM12" PATCH_DIR="$PATCH_DIR" "$REPO_ROOT/scripts/apply-patches.sh" > "$TMP/repeat.log"
grep -qx 'SKIP already applied 10-first.patch' "$TMP/repeat.log"
grep -qx 'SKIP already applied 20-second.patch' "$TMP/repeat.log"

mkdir "$TMP/bad"
cat > "$TMP/bad/10-incompatible.patch" <<'PATCH'
--- a/first.txt
+++ b/first.txt
@@ -1 +1 @@
-missing
+replacement
PATCH
if CM12="$CM12" PATCH_DIR="$TMP/bad" "$REPO_ROOT/scripts/apply-patches.sh" > "$TMP/bad.log" 2>&1; then
  echo 'incompatible patch unexpectedly applied' >&2
  exit 1
fi
grep -q 'ERROR: patch does not apply cleanly: 10-incompatible.patch' "$TMP/bad.log"

WPA_CM12="$TMP/wpa-cm12"
WPA_PATCH_DIR="$TMP/wpa-patches"
mkdir -p "$WPA_CM12/build" "$WPA_CM12/external/wpa_supplicant_8/wpa_supplicant" "$WPA_PATCH_DIR"
cp "$REPO_ROOT/patches/cm12/cm12-biscuit-wpa-passphrase.patch" "$WPA_PATCH_DIR/"
cat > "$WPA_CM12/external/wpa_supplicant_8/wpa_supplicant/Android.mk" <<'MK'
LOCAL_MODULE := wpa_cli
LOCAL_MODULE_TAGS := debug
LOCAL_SHARED_LIBRARIES := libc libcutils liblog
LOCAL_CFLAGS := $(L_CFLAGS)
LOCAL_SRC_FILES := $(OBJS_c)
LOCAL_C_INCLUDES := $(INCLUDES)
include $(BUILD_EXECUTABLE)

# This needs QMI artifacts to be built
ifneq ($(QCPATH),)

ifeq ($(CONFIG_EAP_PROXY),qmi)
include $(CLEAR_VARS)

LOCAL_MODULE = libwpa_qmi_eap_proxy
LOCAL_SHARED_LIBRARIES := libcutils liblog libwpa_client
MK
CM12="$WPA_CM12" PATCH_DIR="$WPA_PATCH_DIR" "$REPO_ROOT/scripts/apply-patches.sh" > "$TMP/wpa-first.log"
[[ "$(grep -c 'LOCAL_MODULE := wpa_passphrase' "$WPA_CM12/external/wpa_supplicant_8/wpa_supplicant/Android.mk")" == 1 ]]
CM12="$WPA_CM12" PATCH_DIR="$WPA_PATCH_DIR" "$REPO_ROOT/scripts/apply-patches.sh" > "$TMP/wpa-repeat.log"
grep -qx 'SKIP already applied cm12-biscuit-wpa-passphrase.patch' "$TMP/wpa-repeat.log"

echo 'PASS CM12 patch series is ordered, repeatable, and rejects conflicts'
