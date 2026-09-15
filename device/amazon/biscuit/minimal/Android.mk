LOCAL_PATH := $(call my-dir)

include $(CLEAR_VARS)
LOCAL_MODULE := biscuit-minimal-dhcpcd-run-hooks
LOCAL_MODULE_TAGS := optional
LOCAL_MODULE_CLASS := EXECUTABLES
LOCAL_MODULE_PATH := $(TARGET_OUT_EXECUTABLES)
LOCAL_MODULE_STEM := dhcpcd-run-hooks
LOCAL_SRC_FILES := dhcpcd-run-hooks
include $(BUILD_PREBUILT)

include $(CLEAR_VARS)
LOCAL_MODULE := biscuit-minimal-resolvconf-symlink
LOCAL_MODULE_TAGS := optional
LOCAL_MODULE_CLASS := ETC
LOCAL_MODULE_PATH := $(TARGET_OUT_ETC)
LOCAL_MODULE_STEM := resolv.conf
include $(BUILD_SYSTEM)/base_rules.mk

$(LOCAL_BUILT_MODULE):
	@echo "Symlink: $@ -> /data/misc/resolv/resolv.conf"
	$(hide) mkdir -p $(dir $@)
	$(hide) rm -rf $@
	$(hide) ln -s /data/misc/resolv/resolv.conf $@

$(LOCAL_INSTALLED_MODULE): $(LOCAL_BUILT_MODULE)
	@echo "Install symlink: $@"
	$(hide) mkdir -p $(dir $@)
	$(hide) rm -rf $@
	$(hide) cp -P $< $@

include $(CLEAR_VARS)
LOCAL_MODULE := biscuit-minimal-cacerts-symlink
LOCAL_MODULE_TAGS := optional
LOCAL_MODULE_CLASS := ETC
LOCAL_MODULE_PATH := $(TARGET_OUT_ETC)/ssl
LOCAL_MODULE_STEM := certs
include $(BUILD_SYSTEM)/base_rules.mk

$(LOCAL_BUILT_MODULE):
	@echo "Symlink: $@ -> ../security/cacerts"
	$(hide) mkdir -p $(dir $@)
	$(hide) rm -rf $@
	$(hide) ln -s ../security/cacerts $@

$(LOCAL_INSTALLED_MODULE): $(LOCAL_BUILT_MODULE)
	@echo "Install symlink: $@"
	$(hide) mkdir -p $(dir $@)
	$(hide) rm -rf $@
	$(hide) cp -P $< $@
