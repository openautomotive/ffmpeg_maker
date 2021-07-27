LOCAL_PATH := $(call my-dir)

include $(CLEAR_VARS)

prebuilts_lib64 := $(patsubst $(LOCAL_PATH)/%,%,$(wildcard $(LOCAL_PATH)/ffmpeg/arm64-v8a/lib/*.so))

$(warning "ffmpeg LOCAL_PATH=$(LOCAL_PATH), prebuilts_lib64=$(prebuilts_lib64)")

define ffmpeg-lib64-prebuilts
$(foreach t,$(1), \
  $(eval include $(CLEAR_VARS)) \
  $(eval LOCAL_MODULE_CLASS := SHARED_LIBRARIES) \
  $(eval LOCAL_MODULE_TAGS := optional) \
  $(eval LOCAL_MODULE := $(basename $(notdir $(t)))) \
  $(eval LOCAL_PROPRIETARY_MODULE := true) \
  $(eval LOCAL_MODULE_OWNER := mtk) \
  $(eval LOCAL_SRC_FILES_arm64 := $(t)) \
  $(eval LOCAL_MODULE_SUFFIX := .so) \
  $(eval LOCAL_MULTILIB := 64) \
  $(eval include $(BUILD_PREBUILT)))
endef
#$(eval LOCAL_MODULE     := $(patsubst %.apk,%,$(notdir $(t)))) \

$(call ffmpeg-lib64-prebuilts, \
	$(prebuilts_lib64))



prebuilts_lib := $(patsubst $(LOCAL_PATH)/%,%,$(wildcard $(LOCAL_PATH)/ffmpeg/armeabi-v7a/lib/*.so))

$(warning "ffmpeg LOCAL_PATH=$(LOCAL_PATH), prebuilts_lib=$(prebuilts_lib)")

define ffmpeg-lib-prebuilts
$(foreach t,$(1), \
  $(eval include $(CLEAR_VARS)) \
  $(eval LOCAL_MODULE_CLASS := SHARED_LIBRARIES) \
  $(eval LOCAL_MODULE_TAGS := optional) \
  $(eval LOCAL_MODULE := $(basename $(notdir $(t)))) \
  $(eval LOCAL_PROPRIETARY_MODULE := true) \
  $(eval LOCAL_MODULE_OWNER := mtk) \
  $(eval LOCAL_SRC_FILES_arm := $(t)) \
  $(eval LOCAL_MODULE_SUFFIX := .so) \
  $(eval LOCAL_MULTILIB := 32) \
  $(eval include $(BUILD_PREBUILT)))
endef
#$(eval LOCAL_MODULE     := $(patsubst %.apk,%,$(notdir $(t)))) \

$(call ffmpeg-lib-prebuilts, \
	$(prebuilts_lib))
