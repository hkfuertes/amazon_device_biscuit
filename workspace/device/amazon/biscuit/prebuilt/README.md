# prebuilt/

Generated kernel drop for CM12 bring-up.

Run:

```sh
workspace/scripts/preflight.sh
workspace/scripts/build-kernel.sh
```

Outputs (ignored by git):

- `kernel` — `Image.gz-dtb` built from Amazon Echo Dot 5.5.5.4 source.
- `kernel.sha256`
- `kernel-selection.txt`

`BoardConfig.mk` can use this as `TARGET_PREBUILT_KERNEL` when bootimage build is wired.
