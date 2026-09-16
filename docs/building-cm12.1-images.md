# Building the CM12.1 Biscuit Images

> [!WARNING]
> **CM12.1 is the Android 5 / Fire OS 5 line and requires Amonet Biscuit v1.1.0.** Its recovery and runtime fstab use the v1 GPT-remapped `boot_a_x` / `boot_b_x` contract. Amonet v1 modifies the GPT and wipes userdata. Do not install these images on an Amonet 2 device or reuse Amonet 2 `current-system` / `current-boot` procedures here.
>
> Amonet 2 is the separate Android 7 / Fire OS 6 contract on the [`cm14.1`](https://github.com/hkfuertes/amazon_device_biscuit/tree/cm14.1) branch. Read the [Amonet v1 notes](amonet-biscuit-unlock.md) and the [archived upstream v1 guide](https://web.archive.org/web/20260612085826/https://xdaforums.com/t/unlock-root-twrp-unbrick-amazon-echo-dot-2nd-gen-2016-biscuit.4761416/) before installing anything.

This branch builds two reproducible CM12.1 products:

| Product | Lunch target | Build command | Purpose |
| --- | --- | --- | --- |
| Full | `cm_biscuit-userdebug` | `make full` | Full Android 5 / CM12.1 with the framework, BiscuitService, Wi-Fi, Bluetooth, LED/buttons, speaker, and microphone paths. |
| Minimal | `biscuit_minimal-userdebug` | `make minimal` | Framework-free Android-shaped base for root ADB, Wi-Fi provisioning, DHCP, raw hardware tools, and replaceable system add-ons. |

The minimal product is not a reduced full Android image. It intentionally has no APKs or Android framework services.

## Prerequisites

- A Linux host with Git, Docker, Python 3, `repo`, `curl`, and `sha256sum`.
- This repository checked out at its top level.
- Network access for the first bootstrap so tracked scripts can obtain pinned source archives and stock inputs.
- For installation only: a 2016 Echo Dot 2nd generation / Biscuit / RS03QR unlocked with **Amonet v1.1.0** and booted into its v1 TWRP.

Create the CM12 build image once if it is absent:

```sh
docker image inspect cm12-ubuntu14:latest >/dev/null 2>&1 || \
  docker build -t cm12-ubuntu14:latest \
    -f docker/cm12-ubuntu14.Dockerfile docker/
```

## Prepare a clean workspace

```sh
# Optional destructive clean of ignored downloads, sources, blobs, and outputs.
rm -rf workspace

# Materialize pinned CM12 sources, kernel input, certificates, and stock blobs.
scripts/bootstrap-workspace.sh

# Build the patched Biscuit kernel in its dedicated Docker image.
scripts/build-kernel.sh

# Read-only verification of inputs, pins, blobs, generated kernel, and host tools.
scripts/preflight.sh
```

`workspace/` is disposable. Do not make manual changes below `workspace/cm12`; express changes through tracked patches, scripts, or staged files.

## Build the full image

```sh
make full
docker logs -f cm12-biscuit-build
```

`make full` selects `cm_biscuit-userdebug`, applies `patches/full/`, clears the shared Biscuit product output, and starts the detached Docker build. It does not flash a device.

Use the [full-product smoke checklist](baseline-smoke-checks.md#full-product) after a confirmed v1-TWRP installation.

## Build the framework-free minimal image

```sh
make minimal
docker logs -f cm12-biscuit-build
```

`make minimal` selects `biscuit_minimal-userdebug`, applies `patches/minimal/`, and clears the shared product output before the detached build. The clean-output step prevents full-framework files from surviving a product switch.

Use the [framework-free minimal smoke checklist](baseline-smoke-checks.md#framework-free-minimal-product) after a confirmed v1-TWRP installation.

## Artifacts and preflight

Both products write below:

```txt
workspace/cm12/out-docker/target/product/biscuit/
```

The build wrapper gives OTAs stable names:

```txt
ota_biscuit_YYYYMMDD-SHORTSHA.zip
ota_biscuit_minimal_YYYYMMDD-SHORTSHA.zip
```

Before installation, inspect the generated updater against the **Amonet v1** contract. CM12 recovery uses the v1 GPT-remapped boot slots and must be installed only through confirmed v1 TWRP or confirmed v1 hacked fastboot. Do not substitute the native-A/B Amonet 2 aliases or procedures.

## Incremental builds

For ordinary device changes with a valid generated kernel:

```sh
scripts/preflight.sh
make full       # or: make minimal
docker logs -f cm12-biscuit-build
```

If kernel source preparation or `patches/kernel/` changes, run `scripts/build-kernel.sh` first. Build commands only create artifacts; installation is documented separately in [Amonet v1 notes](amonet-biscuit-unlock.md).

## Patch profiles

- `patches/full/` applies only to `cm_biscuit-userdebug`.
- `patches/minimal/` applies only to `biscuit_minimal-userdebug`.
- `patches/kernel/` applies while building the shared Biscuit kernel.

The profiles intentionally remain separate so a full-framework patch cannot leak into the framework-free image.
