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
#ifndef FFMPEG_RESAMPLING_AUDIO_H
#define FFMPEG_RESAMPLING_AUDIO_H

#include <libavutil/opt.h>
#include <libavutil/channel_layout.h>
#include <libavutil/samplefmt.h>
#include <libswresample/swresample.h>

struct SwrContextWrapper {
    struct SwrContext *swr_ctx;
    int pre_defined_input_size;/*input data size*/
    int src_rate;
    int dst_rate;
    int src_nb_channels;
    int dst_nb_channels;
    enum AVSampleFormat src_sample_fmt;
    enum AVSampleFormat dst_sample_fmt;
    int src_bytes_per_samples;
    uint8_t **dst_data;
    int dst_linesize;
    int dst_nb_samples;
};

int ffmpeg_resampling_init(struct SwrContextWrapper *swr_ctx_wrapper);
int resampling_process(struct SwrContextWrapper *swr_ctx_wrapper, uint8_t *pInBuffer, uint32_t inBytes, uint8_t **ppOutBuffer, uint32_t *pOutBytes);
void ffmpeg_resampling_deinit(struct SwrContextWrapper *swr_ctx_wrapper);

#endif /* FFMPEG_RESAMPLING_AUDIO_H */
