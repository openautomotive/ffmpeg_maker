1. add header file in src

#ifdef __cplusplus
extern "C" {
    #include "ffmpeg_resampling_audio.h"
}
#endif

2. init ctx

static struct SwrContextWrapper mSwrContextWrapper;
mSwrContextWrapper.pre_defined_input_size = kReadBufferSize;
ffmpeg_resampling_init(&mSwrContextWrapper);


3. process data

resampling_process(&mSwrContextWrapper, (uint8_t *)linear_buffer, (int)kReadBufferSize, (uint8_t **)&pBufferAfterBliSrc, (int *)&bytesAfterBliSrc);

4. destory

ffmpeg_resampling_deinit(&mSwrContextWrapper);

5. add build info for android

# add ffmpeg resampling support @{
    LOCAL_CFLAGS += -DUSE_FFMPEG_RESAMPLING
    LOCAL_C_INCLUDES += \
        $(LOCAL_PATH)/ffmpeg \
        $(LOCAL_PATH)/ffmpeg/prebuilts/ffmpeg/armeabi-v7a/include

    LOCAL_SRC_FILES += \
        ffmpeg/ffmpeg_resampling_audio.c

    LOCAL_SHARED_LIBRARIES += \
        libavcodec \
        libavdevice \
        libavfilter \
        libavformat \
        libavutil \
        libswresample \
        libswscale
# @}

include $(local_path)/ffmpeg/prebuilts/Android.mk
