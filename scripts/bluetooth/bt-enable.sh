#!/usr/bin/env bash
set -euo pipefail

# IBluetoothManager.enable(String) transaction id for this branch.
adb shell 'service call bluetooth_manager 8 s16 com.android.shell; sleep 2; dumpsys bluetooth_manager 2>&1 | head -120'
