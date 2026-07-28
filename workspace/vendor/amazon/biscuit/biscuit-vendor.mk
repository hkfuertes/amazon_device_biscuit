# Biscuit blobs extracted from stock Biscuit system.img.
# No-GPU/headless path: intentionally no libGLES_mali, gralloc.mt8163.mali, or libgpu_aux.

PRODUCT_COPY_FILES += \
    vendor/amazon/biscuit/proprietary/lib/egl/egl.cfg:system/lib/egl/egl.cfg \
    vendor/amazon/biscuit/proprietary/lib/egl/libGLES_android.so:system/lib/egl/libGLES_android.so \
    vendor/amazon/biscuit/proprietary/lib/hw/gralloc.mt8163.so:system/lib/hw/gralloc.mt8163.so \
    vendor/amazon/biscuit/proprietary/lib/hw/hwcomposer.mt8163.so:system/lib/hw/hwcomposer.mt8163.so \
    vendor/amazon/biscuit/proprietary/lib/libGdmaScalerPipe.so:system/lib/libGdmaScalerPipe.so \
    vendor/amazon/biscuit/proprietary/lib/libbwc.so:system/lib/libbwc.so \
    vendor/amazon/biscuit/proprietary/lib/libdpframework.so:system/lib/libdpframework.so \
    vendor/amazon/biscuit/proprietary/lib/libgralloc_extra.so:system/lib/libgralloc_extra.so \
    vendor/amazon/biscuit/proprietary/lib/libgui_ext.so:system/lib/libgui_ext.so \
    vendor/amazon/biscuit/proprietary/lib/libion_mtk.so:system/lib/libion_mtk.so \
    vendor/amazon/biscuit/proprietary/lib/libm4u.so:system/lib/libm4u.so \
    vendor/amazon/biscuit/proprietary/lib/libstlport.so:system/lib/libstlport.so \
    vendor/amazon/biscuit/proprietary/lib/libui_ext.so:system/lib/libui_ext.so \
    vendor/amazon/biscuit/proprietary/lib64/egl/libGLES_android.so:system/lib64/egl/libGLES_android.so \
    vendor/amazon/biscuit/proprietary/lib64/hw/gralloc.mt8163.so:system/lib64/hw/gralloc.mt8163.so \
    vendor/amazon/biscuit/proprietary/lib64/hw/hwcomposer.mt8163.so:system/lib64/hw/hwcomposer.mt8163.so \
    vendor/amazon/biscuit/proprietary/lib64/libbwc.so:system/lib64/libbwc.so \
    vendor/amazon/biscuit/proprietary/lib64/libdpframework.so:system/lib64/libdpframework.so \
    vendor/amazon/biscuit/proprietary/lib64/libgralloc_extra.so:system/lib64/libgralloc_extra.so \
    vendor/amazon/biscuit/proprietary/lib64/libion_mtk.so:system/lib64/libion_mtk.so \
    vendor/amazon/biscuit/proprietary/lib64/libm4u.so:system/lib64/libm4u.so \
    vendor/amazon/biscuit/proprietary/lib64/libstlport.so:system/lib64/libstlport.so \
    vendor/amazon/biscuit/proprietary/bin/idme:system/bin/idme \
    vendor/amazon/biscuit/proprietary/bin/devicetype_service:system/bin/devicetype_service \
    vendor/amazon/biscuit/proprietary/lib/hw/keystore.mt8163.so:system/lib/hw/keystore.mt8163.so \
    vendor/amazon/biscuit/proprietary/lib/libtz_uree.so:system/lib/libtz_uree.so \
    vendor/amazon/biscuit/proprietary/lib64/hw/keystore.mt8163.so:system/lib64/hw/keystore.mt8163.so \
    vendor/amazon/biscuit/proprietary/lib64/libtz_uree.so:system/lib64/libtz_uree.so \
    vendor/amazon/biscuit/proprietary/bin/6620_launcher:system/bin/6620_launcher \
    vendor/amazon/biscuit/proprietary/bin/wmt_loader:system/bin/wmt_loader \
    vendor/amazon/biscuit/proprietary/etc/firmware/ROMv2_lm_patch_1_0_hdr.bin:system/etc/firmware/ROMv2_lm_patch_1_0_hdr.bin \
    vendor/amazon/biscuit/proprietary/etc/firmware/ROMv2_lm_patch_1_1_hdr.bin:system/etc/firmware/ROMv2_lm_patch_1_1_hdr.bin \
    vendor/amazon/biscuit/proprietary/etc/firmware/WIFI_RAM_CODE_8163:system/etc/firmware/WIFI_RAM_CODE_8163 \
    vendor/amazon/biscuit/proprietary/etc/firmware/WMT_SOC.cfg:system/etc/firmware/WMT_SOC.cfg \
    vendor/amazon/biscuit/proprietary/etc/wifi/wpa_supplicant.conf:system/etc/wifi/wpa_supplicant.conf \
    vendor/amazon/biscuit/proprietary/etc/wifi/wpa_supplicant_overlay.conf:system/etc/wifi/wpa_supplicant_overlay.conf \
    vendor/amazon/biscuit/proprietary/bin/linker64:system/bin/linker64 \
    vendor/amazon/biscuit/proprietary/lib64/libc.so:system/lib64/libc.so \
    vendor/amazon/biscuit/proprietary/lib64/libcutils.so:system/lib64/libcutils.so \
    vendor/amazon/biscuit/proprietary/lib64/liblog.so:system/lib64/liblog.so \
    vendor/amazon/biscuit/proprietary/lib64/libm.so:system/lib64/libm.so \
    vendor/amazon/biscuit/proprietary/lib64/libsigchain.so:system/lib64/libsigchain.so \
    vendor/amazon/biscuit/proprietary/lib64/libstdc++.so:system/lib64/libstdc++.so \
    vendor/amazon/biscuit/proprietary/lib/libbt-vendor.so:system/lib/libbt-vendor.so \
    vendor/amazon/biscuit/proprietary/lib/libbluetooth_mtk.so:system/lib/libbluetooth_mtk.so \
    vendor/amazon/biscuit/proprietary/lib/libnvram.so:system/lib/libnvram.so \
    vendor/amazon/biscuit/proprietary/lib/libnvram_platform.so:system/lib/libnvram_platform.so \
    vendor/amazon/biscuit/proprietary/lib/libcustom_nvram.so:system/lib/libcustom_nvram.so
