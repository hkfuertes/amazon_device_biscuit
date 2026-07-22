#!/usr/bin/env bash
set -euo pipefail

# CM12 IBluetoothManager.enable(String) transaction id.
adb shell 'service call bluetooth_manager 8 s16 com.android.shell; sleep 2; dumpsys bluetooth_manager 2>&1 | head -120'
