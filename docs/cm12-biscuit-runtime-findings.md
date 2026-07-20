# CM12 Biscuit runtime findings

Purpose: notes imported from `../cm12-biscuit` for reference only. No code, kernel, blobs, or config were copied.

## Source references

- `../cm12-biscuit/workspace/reports/issue-09-cm12-runtime-bringup.report.md`
- `../cm12-biscuit/workspace/reports/issue-11-connectivity-audio-buttons-leds.report.md`
- `../cm12-biscuit/workspace/cm12/device/amazon/biscuit/BoardConfig.mk`
- `../cm12-biscuit/workspace/cm12/device/amazon/biscuit/cm.mk`

## Imported findings

- The other repo reached CM12.1 framework boot with ADB and `sys.boot_completed=1`.
- Its device config used 32-bit userspace with 64-bit binder:
  - `TARGET_ARCH := arm`
  - `TARGET_ARCH_VARIANT := armv7-a-neon`
  - `TARGET_CPU_ABI := armeabi-v7a`
  - `TARGET_USES_64_BIT_BINDER := true`
- Its product inherited `full_base.mk`.
- Runtime fixes that mattered there:
  - stock MTK WCN/WiFi/BT/audio properties in the common `system.prop`;
  - `/dev/block/platform/mtk-msdc.0` symlink pointed at `/dev/block/platform/soc` so `/by-name/kb` exists;
  - missing 64-bit `libnetutils.so` was needed by `kisd`;
  - Bluetooth needed `/dev/stpbt` labelled `u:object_r:hci_attach_dev:s0`;
  - audio/mic needed stock shm/audio service investigation and SELinux service labels.
- It later verified WiFi scan/connectivity, Bluetooth enabled, speaker output, and kernel button events.
- LEDs/display stayed blocked: no `/sys/class/leds`, no `/dev/graphics`, no framebuffer node.

## Current repo finding before applying any imported fix

The current 32-bit userspace build panics before framework boot. Evidence saved from TWRP recovery:

- `workspace/logs/last_kmsg-after-bootloop.txt`
- panic process: `iptables`
- failure: kernel NULL dereference at `00000000`
- call path:
  - `memcpy`
  - `compat_do_replace`
  - `compat_do_ipt_set_ctl`
  - `compat_nf_setsockopt`
  - `compat_ip_setsockopt`
  - `compat_SyS_setsockopt`

Working hypothesis: 32-bit `iptables` on a 64-bit kernel hits the kernel compat netfilter path and panics. Therefore test 64-bit userspace first; only if 64-bit also fails, use the other repo findings above as guided fixes.
