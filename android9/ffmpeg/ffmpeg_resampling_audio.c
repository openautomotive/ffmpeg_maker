/*
 * Copyright (c) 2012 Stefano Sabatini
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
 * THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 */

/**
 * @example resampling_audio.c
 * libswresample API use example.
 */
#ifdef LOG_TAG
#undef LOG_TAG
#endif
#define LOG_TAG "ffmpeg_resampling_audio"
#include <log/log.h> /* use android log */

#include "ffmpeg_resampling_audio.h"

/* use android log */
#ifdef fprintf
#undef fprintf
#endif
#define fprintf(file, ...) \
    do { \
        if (stderr == file) { \
            ALOGE(__VA_ARGS__); \
        } else if (stdout == file) { \
            ALOGD(__VA_ARGS__); \
        } \
    } while (0)

int ffmpeg_resampling_init(struct SwrContextWrapper *swr_ctx_wrapper)
{
    int64_t src_ch_layout = AV_CH_LAYOUT_STEREO, dst_ch_layout = AV_CH_LAYOUT_STEREO;
    int src_rate = 48000, dst_rate = 16000;
    enum AVSampleFormat src_sample_fmt = AV_SAMPLE_FMT_S16, dst_sample_fmt = AV_SAMPLE_FMT_S16;
    int src_nb_channels = 0, dst_nb_channels = 0;
    int src_linesize = 0, dst_linesize = 0;
    int src_nb_samples = 0, src_bytes_per_samples = 0, dst_nb_samples = 0;
    struct SwrContext *swr_ctx = NULL;
    uint8_t **dst_data = NULL;
    int ret = AVERROR(EPERM);

    if(!swr_ctx_wrapper) {
        fprintf(stderr, "invalid swr_ctx_wrapper\n");
        ret = AVERROR(EINVAL);
        goto end;
    }

    /* allocate source and destination samples buffers */
    src_nb_channels = av_get_channel_layout_nb_channels(src_ch_layout);
    src_bytes_per_samples = src_nb_channels * av_get_bytes_per_sample(src_sample_fmt);
    src_linesize = swr_ctx_wrapper->pre_defined_input_size;
    if (0 >= src_linesize || src_linesize % src_bytes_per_samples) {
        fprintf(stderr, "pre_defined_input_size not align with src format\n");
        ret = AVERROR(EINVAL);
        goto end;
    }
    src_nb_samples = src_linesize / src_bytes_per_samples;

    /* create resampler context */
    swr_ctx = swr_alloc();
    if (!swr_ctx) {
        fprintf(stderr, "Could not allocate resampler context\n");
        ret = AVERROR(ENOMEM);
        goto end;
    }

    /* set options */
    av_opt_set_int(swr_ctx, "in_channel_layout",    src_ch_layout, 0);
    av_opt_set_int(swr_ctx, "in_sample_rate",       src_rate, 0);
    av_opt_set_sample_fmt(swr_ctx, "in_sample_fmt", src_sample_fmt, 0);

    av_opt_set_int(swr_ctx, "out_channel_layout",    dst_ch_layout, 0);
    av_opt_set_int(swr_ctx, "out_sample_rate",       dst_rate, 0);
    av_opt_set_sample_fmt(swr_ctx, "out_sample_fmt", dst_sample_fmt, 0);

    /* initialize the resampling context */
    if ((ret = swr_init(swr_ctx)) < 0) {
        fprintf(stderr, "Failed to initialize the resampling context\n");
        goto end;
    }

    /* compute the number of converted samples: buffering is avoided
     * ensuring that the output buffer will contain at least all the
     * converted input samples */
    dst_nb_samples = av_rescale_rnd(src_nb_samples, dst_rate, src_rate, AV_ROUND_UP);

    /* buffer is going to be directly written to a rawaudio file, no alignment */
    dst_nb_channels = av_get_channel_layout_nb_channels(dst_ch_layout);
    ret = av_samples_alloc_array_and_samples(&dst_data, &dst_linesize, dst_nb_channels,
                                             dst_nb_samples, dst_sample_fmt, 0);
    if (ret < 0) {
        fprintf(stderr, "Could not allocate destination samples\n");
        goto end;
    }

    swr_ctx_wrapper->swr_ctx = swr_ctx;
    swr_ctx_wrapper->src_rate = src_rate;
    swr_ctx_wrapper->dst_rate = dst_rate;
    swr_ctx_wrapper->src_nb_channels = src_nb_channels;
    swr_ctx_wrapper->dst_nb_channels = dst_nb_channels;
    swr_ctx_wrapper->src_sample_fmt = src_sample_fmt;
    swr_ctx_wrapper->dst_sample_fmt = dst_sample_fmt;
    swr_ctx_wrapper->src_bytes_per_samples = src_bytes_per_samples;
    swr_ctx_wrapper->dst_data = dst_data;
    swr_ctx_wrapper->dst_linesize = dst_linesize;
    swr_ctx_wrapper->dst_nb_samples = dst_nb_samples;

    fprintf(stdout, "swr_ctx_wrapper swr_ctx=%p\n", swr_ctx_wrapper->swr_ctx);
    return 0;

end:
    if (dst_data)
        av_freep(&dst_data[0]);
    av_freep(&dst_data);

    swr_free(&swr_ctx);
    return ret < 0;

}

int resampling_process(struct SwrContextWrapper *swr_ctx_wrapper, uint8_t *pInBuffer, uint32_t inBytes, uint8_t **ppOutBuffer, uint32_t *pOutBytes)
{
    uint8_t **src_data = NULL, **dst_data = NULL;;
    int src_linesize, dst_linesize;
    int src_nb_samples, dst_nb_samples;
    int dst_bufsize;
    int ret;

    /* init data */
    if (!swr_ctx_wrapper || !swr_ctx_wrapper->swr_ctx) {
        fprintf(stderr, "invalid swr_ctx=%p, swr_ctx_wrapper=%p\n", swr_ctx_wrapper->swr_ctx, swr_ctx_wrapper);
        ret = AVERROR(EINVAL);
        goto end;
    }

    /* compute src_nb_samples */
    src_linesize = inBytes;
    if (0 >= src_linesize || src_linesize % swr_ctx_wrapper->src_bytes_per_samples) {
        fprintf(stderr, "inBytes not align with src format\n");
        ret = AVERROR(EINVAL);
        goto end;
    }
    src_nb_samples = src_linesize / swr_ctx_wrapper->src_bytes_per_samples;

    /* fill audio data */
    src_data = &pInBuffer;
    
    /* compute destination number of samples */
    dst_nb_samples = av_rescale_rnd(swr_get_delay(swr_ctx_wrapper->swr_ctx, swr_ctx_wrapper->src_rate) +
            src_nb_samples, swr_ctx_wrapper->dst_rate, swr_ctx_wrapper->src_rate, AV_ROUND_UP);
    if (dst_nb_samples > swr_ctx_wrapper->dst_nb_samples) {
        av_freep(&swr_ctx_wrapper->dst_data[0]);
        ret = av_samples_alloc(dst_data, &dst_linesize, swr_ctx_wrapper->dst_nb_channels,
                                        dst_nb_samples, swr_ctx_wrapper->dst_sample_fmt, 1);
        if (ret < 0) {
            fprintf(stderr, "Could not allocate dst buffer\n");
            ret = AVERROR(ENOMEM);
            goto end;
        }
        swr_ctx_wrapper->dst_data = dst_data;
        swr_ctx_wrapper->dst_linesize = dst_linesize;
        swr_ctx_wrapper->dst_nb_samples = dst_nb_samples;
    }
    
    /* convert to destination format */
    ret = swr_convert(swr_ctx_wrapper->swr_ctx, swr_ctx_wrapper->dst_data, swr_ctx_wrapper->dst_nb_samples,
            (const uint8_t **)src_data, src_nb_samples);
    if (ret < 0) {
        fprintf(stderr, "Error while converting\n");
        goto end;
    }
    dst_bufsize = av_samples_get_buffer_size(&swr_ctx_wrapper->dst_linesize, swr_ctx_wrapper->dst_nb_channels,
                                             ret, swr_ctx_wrapper->dst_sample_fmt, 1);
    if (dst_bufsize < 0) {
        fprintf(stderr, "Could not get sample buffer size\n");
        goto end;
    }
    printf("in:%d out:%d\n", src_nb_samples, ret);
    *ppOutBuffer = swr_ctx_wrapper->dst_data[0];
    *pOutBytes = dst_bufsize;
    return 0;
end:
    return ret < 0;
}

void ffmpeg_resampling_deinit(struct SwrContextWrapper *swr_ctx_wrapper)
{
    if(!swr_ctx_wrapper) {
        fprintf(stderr, "invalid swr_ctx_wrapper\n");
        goto end;
    }

    if (swr_ctx_wrapper->dst_data)
        av_freep(&swr_ctx_wrapper->dst_data[0]);
    av_freep(&swr_ctx_wrapper->dst_data);

    swr_free(&swr_ctx_wrapper->swr_ctx);

end:
    return;

}