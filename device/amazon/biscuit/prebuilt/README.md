# prebuilt/

Generated kernel drop for CM12 bring-up.

Run:

```sh
scripts/build-kernel.sh
```

Outputs (ignored by git):

- `kernel` — `Image.gz-dtb` built from `workspace/kernel/amazon/biscuit`.
- `kernel.sha256`
- `kernel-selection.txt`

`BoardConfig.mk` can use this as `TARGET_PREBUILT_KERNEL` when bootimage build is wired.
