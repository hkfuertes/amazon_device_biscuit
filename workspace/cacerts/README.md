# Android CA certs for Biscuit

Downloaded from AOSP `platform/system/ca-certificates/files`.

Regenerate from AOSP `main`:

```sh
workspace/scripts/update-ca-certs.sh
```

Or pin a ref/commit:

```sh
workspace/scripts/update-ca-certs.sh <git-ref-or-commit>
```

`workspace/scripts/stage-tree.sh` copies `*.[0-9]` from this directory to `workspace/cm12/libcore/luni/src/main/files/cacerts`, which CM12 installs as `/system/etc/security/cacerts`.
