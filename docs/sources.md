# Fuentes reproducibles

## CM12

- Manifest: `manifest/cm12.lock.xml`
- Sync: `scripts/sync-cm12.sh`
- Destino ignorado: `workspace/cm12/`

## Kernel

- Source: Amazon Echo Dot 5.5.5.4
- URL: `https://fireos-audio-src.s3.amazonaws.com/fcDtMdy42ieZkba5oyC4H3KcwU/Echo_Dot_src-5.5.5.4-20220824.tar.bz2`
- SHA256: `dd92a7ddd7c0fb9b61455542b84132ad00a445c38ef4f910b1272ac04f6f83dd`
- Materializador: `scripts/prepare-kernel-source.sh`
- Base ignorada e inmutable: `workspace/kernel/amazon/biscuit/`
- Soporte de build ignorado: `workspace/kernel/amazon/biscuit-build-support/`
- Stage de build ignorado: `workspace/kernel/build/biscuit/` via `scripts/stage-kernel-for-build.sh`
- Patches: `patches/kernel/biscuit-kernel-*.patch`

## Blobs propietarios Biscuit

- Source: OTA stock Biscuit full 272.6.4.1
- URL: `https://d1s31zyz7dcc2d.cloudfront.net/8811a0fc982bf3331dc54f5aec45d936/update-kindle-full_biscuit-272.6.4.1_user_641575220.bin`
- Input generado: `workspace/extracted/biscuit-stock-272.6.4.1/system.img` from `system.new.dat` + `system.transfer.list`
- Script: `scripts/extract-biscuit-stock-blobs.sh`
- Destino ignorado: `workspace/vendor/amazon/biscuit/`

Política: no versionar blobs; extraerlos de OTA. El extractor excluye Mali/GPU y genera `biscuit-vendor.mk`.

## Referencias externas usadas

- Amazon OSS MT8163 common: `https://github.com/amazon-oss/android_device_amazon_mt8163-common`
- Amazon OSS hardware helpers: `https://github.com/amazon-oss/android_hardware_amazon/tree/cm-12.1`
- MT8163 `frameworks/av` FLAC/OMX reference patch: `https://github.com/mt8173-dev/android_device_amazon_sloane/raw/7a41e2f9314b0b20f49538718e5e515824c2f97d/patches/frameworks/av/0001-mt8163-frameworks-av-add-required-changes-for-mt8163.patch`
- MTK helper comparison reference: `https://github.com/lbule/android_hardware_mediatek`

## Trabajo nuestro trackeado

```txt
device/amazon/biscuit/
device/amazon/mt8163-common/
hardware/amazon/
hardware/mediatek/
patches/cm12/
patches/kernel/
patches/vendor/
scripts/
docker/
```
