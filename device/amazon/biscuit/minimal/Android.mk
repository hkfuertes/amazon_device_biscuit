LOCAL_PATH := $(call my-dir)

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
