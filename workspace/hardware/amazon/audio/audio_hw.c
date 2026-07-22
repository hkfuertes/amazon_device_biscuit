#define LOG_TAG "biscuit_audio_hw"

#include <errno.h>
#include <pthread.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <unistd.h>

#include <cutils/log.h>
#include <hardware/audio.h>
#include <hardware/hardware.h>
#include <system/audio.h>
#include <tinyalsa/asoundlib.h>

#define CARD 0
#define DEVICE 23
#define RATE 48000
#define CHANNELS 2
#define PERIOD_SIZE 1024
#define PERIOD_COUNT 4

struct biscuit_audio_device {
    struct audio_hw_device device;
    pthread_mutex_t lock;
    bool mic_mute;
};

struct biscuit_stream_out {
    struct audio_stream_out stream;
    pthread_mutex_t lock;
    struct pcm *pcm;
    uint64_t frames_written;
};

static struct pcm_config out_config = {
    .channels = CHANNELS,
    .rate = RATE,
    .period_size = PERIOD_SIZE,
    .period_count = PERIOD_COUNT,
    .format = PCM_FORMAT_S16_LE,
};

static int route_enum_or_value(struct mixer *mixer, const char *name, const char *value, int fallback)
{
    struct mixer_ctl *ctl = mixer_get_ctl_by_name(mixer, name);
    unsigned int i, n;
    int ret;

    if (!ctl) {
        ALOGW("missing mixer ctl: %s", name);
        return -ENOENT;
    }

    ret = mixer_ctl_set_enum_by_string(ctl, value);
    if (ret == 0)
        return 0;

    n = mixer_ctl_get_num_values(ctl);
    for (i = 0; i < n; i++) {
        ret = mixer_ctl_set_value(ctl, i, fallback);
        if (ret != 0)
            ALOGW("failed mixer ctl %s[%u]=%d", name, i, fallback);
    }
    return ret;
}

static int route_value(struct mixer *mixer, const char *name, int v0, int v1)
{
    struct mixer_ctl *ctl = mixer_get_ctl_by_name(mixer, name);
    unsigned int n;
    int ret = 0;

    if (!ctl) {
        ALOGW("missing mixer ctl: %s", name);
        return -ENOENT;
    }

    n = mixer_ctl_get_num_values(ctl);
    if (n > 0)
        ret = mixer_ctl_set_value(ctl, 0, v0);
    if (n > 1)
        ret |= mixer_ctl_set_value(ctl, 1, v1);
    if (ret != 0)
        ALOGW("failed mixer ctl %s=%d,%d", name, v0, v1);
    return ret;
}

static void apply_speaker_route(void)
{
    struct mixer *mixer = mixer_open(CARD);

    if (!mixer) {
        ALOGE("mixer_open(%d) failed", CARD);
        return;
    }

    /* ponytail: fixed bring-up route; make policy/routing dynamic when another output exists. */
    route_enum_or_value(mixer, "HPL Output Mixer L_DAC Switch", "On", 1);
    route_enum_or_value(mixer, "HPR Output Mixer R_DAC Switch", "On", 1);
    route_enum_or_value(mixer, "Audio_DacMux_Setting", "Off", 0);
    route_enum_or_value(mixer, "Right Channel Only", "On", 1);
    route_value(mixer, "HP Driver Gain Volume", 6, 6);
    route_enum_or_value(mixer, "MFP Gpio Mute", "Off", 0);
    route_enum_or_value(mixer, "Ext_Speaker_Amp_Switch", "On", 1);

    mixer_close(mixer);
}

static uint32_t out_get_sample_rate(const struct audio_stream *stream) { return RATE; }
static int out_set_sample_rate(struct audio_stream *stream, uint32_t rate) { return rate == RATE ? 0 : -EINVAL; }
static size_t out_get_buffer_size(const struct audio_stream *stream) { return PERIOD_SIZE * CHANNELS * sizeof(int16_t); }
static audio_channel_mask_t out_get_channels(const struct audio_stream *stream) { return AUDIO_CHANNEL_OUT_STEREO; }
static audio_format_t out_get_format(const struct audio_stream *stream) { return AUDIO_FORMAT_PCM_16_BIT; }
static int out_set_format(struct audio_stream *stream, audio_format_t format) { return format == AUDIO_FORMAT_PCM_16_BIT ? 0 : -EINVAL; }
static int out_dump(const struct audio_stream *stream, int fd) { return 0; }
static audio_devices_t out_get_device(const struct audio_stream *stream) { return AUDIO_DEVICE_OUT_SPEAKER; }
static int out_set_device(struct audio_stream *stream, audio_devices_t device) { return 0; }
static int out_set_parameters(struct audio_stream *stream, const char *kv_pairs) { return 0; }
static char *out_get_parameters(const struct audio_stream *stream, const char *keys) { return strdup(""); }
static int out_add_audio_effect(const struct audio_stream *stream, effect_handle_t effect) { return 0; }
static int out_remove_audio_effect(const struct audio_stream *stream, effect_handle_t effect) { return 0; }
static uint32_t out_get_latency(const struct audio_stream_out *stream) { return (PERIOD_SIZE * PERIOD_COUNT * 1000) / RATE; }
static int out_set_volume(struct audio_stream_out *stream, float left, float right) { return -ENOSYS; }
static int out_get_render_position(const struct audio_stream_out *stream, uint32_t *dsp_frames) { *dsp_frames = 0; return -EINVAL; }
static int out_get_next_write_timestamp(const struct audio_stream_out *stream, int64_t *timestamp) { return -EINVAL; }
static int out_set_callback(struct audio_stream_out *stream, stream_callback_t callback, void *cookie) { return -ENOSYS; }
static int out_pause(struct audio_stream_out *stream) { return -ENOSYS; }
static int out_resume(struct audio_stream_out *stream) { return -ENOSYS; }
static int out_drain(struct audio_stream_out *stream, audio_drain_type_t type) { return 0; }
static int out_flush(struct audio_stream_out *stream) { return 0; }

static int out_standby(struct audio_stream *stream)
{
    struct biscuit_stream_out *out = (struct biscuit_stream_out *)stream;

    pthread_mutex_lock(&out->lock);
    if (out->pcm) {
        pcm_close(out->pcm);
        out->pcm = NULL;
    }
    pthread_mutex_unlock(&out->lock);
    return 0;
}

static ssize_t out_write(struct audio_stream_out *stream, const void *buffer, size_t bytes)
{
    struct biscuit_stream_out *out = (struct biscuit_stream_out *)stream;
    int ret;

    pthread_mutex_lock(&out->lock);
    if (!out->pcm) {
        apply_speaker_route();
        struct pcm_config config = out_config;
        out->pcm = pcm_open(CARD, DEVICE, PCM_OUT, &config);
        if (!out->pcm || !pcm_is_ready(out->pcm)) {
            ALOGE("pcm_open(%d,%d) failed: %s", CARD, DEVICE, out->pcm ? pcm_get_error(out->pcm) : "NULL");
            if (out->pcm) {
                pcm_close(out->pcm);
                out->pcm = NULL;
            }
            pthread_mutex_unlock(&out->lock);
            usleep((bytes * 1000000ULL) / (RATE * CHANNELS * sizeof(int16_t)));
            return -ENODEV;
        }
    }

    ret = pcm_write(out->pcm, buffer, bytes);
    if (ret == 0)
        out->frames_written += bytes / (CHANNELS * sizeof(int16_t));
    pthread_mutex_unlock(&out->lock);

    return ret == 0 ? (ssize_t)bytes : -EIO;
}

static int out_get_presentation_position(const struct audio_stream_out *stream, uint64_t *frames, struct timespec *timestamp)
{
    const struct biscuit_stream_out *out = (const struct biscuit_stream_out *)stream;
    *frames = out->frames_written;
    clock_gettime(CLOCK_MONOTONIC, timestamp);
    return 0;
}

static int adev_open_output_stream(struct audio_hw_device *dev,
                                   audio_io_handle_t handle,
                                   audio_devices_t devices,
                                   audio_output_flags_t flags,
                                   struct audio_config *config,
                                   struct audio_stream_out **stream_out,
                                   const char *address)
{
    struct biscuit_stream_out *out;

    if (config) {
        config->sample_rate = RATE;
        config->channel_mask = AUDIO_CHANNEL_OUT_STEREO;
        config->format = AUDIO_FORMAT_PCM_16_BIT;
    }

    out = calloc(1, sizeof(*out));
    if (!out)
        return -ENOMEM;

    pthread_mutex_init(&out->lock, NULL);
    out->stream.common.get_sample_rate = out_get_sample_rate;
    out->stream.common.set_sample_rate = out_set_sample_rate;
    out->stream.common.get_buffer_size = out_get_buffer_size;
    out->stream.common.get_channels = out_get_channels;
    out->stream.common.get_format = out_get_format;
    out->stream.common.set_format = out_set_format;
    out->stream.common.standby = out_standby;
    out->stream.common.dump = out_dump;
    out->stream.common.get_device = out_get_device;
    out->stream.common.set_device = out_set_device;
    out->stream.common.set_parameters = out_set_parameters;
    out->stream.common.get_parameters = out_get_parameters;
    out->stream.common.add_audio_effect = out_add_audio_effect;
    out->stream.common.remove_audio_effect = out_remove_audio_effect;
    out->stream.get_latency = out_get_latency;
    out->stream.set_volume = out_set_volume;
    out->stream.write = out_write;
    out->stream.get_render_position = out_get_render_position;
    out->stream.get_next_write_timestamp = out_get_next_write_timestamp;
    out->stream.set_callback = out_set_callback;
    out->stream.pause = out_pause;
    out->stream.resume = out_resume;
    out->stream.drain = out_drain;
    out->stream.flush = out_flush;
    out->stream.get_presentation_position = out_get_presentation_position;

    *stream_out = &out->stream;
    return 0;
}

static void adev_close_output_stream(struct audio_hw_device *dev, struct audio_stream_out *stream)
{
    struct biscuit_stream_out *out = (struct biscuit_stream_out *)stream;
    out_standby(&stream->common);
    pthread_mutex_destroy(&out->lock);
    free(out);
}

static int adev_close(hw_device_t *device)
{
    struct biscuit_audio_device *adev = (struct biscuit_audio_device *)device;
    pthread_mutex_destroy(&adev->lock);
    free(adev);
    return 0;
}

static uint32_t adev_get_supported_devices(const struct audio_hw_device *dev) { return AUDIO_DEVICE_OUT_SPEAKER; }
static int adev_init_check(const struct audio_hw_device *dev) { return 0; }
static int adev_set_voice_volume(struct audio_hw_device *dev, float volume) { return 0; }
static int adev_set_master_volume(struct audio_hw_device *dev, float volume) { return -ENOSYS; }
static int adev_get_master_volume(struct audio_hw_device *dev, float *volume) { *volume = 1.0f; return 0; }
static int adev_set_master_mute(struct audio_hw_device *dev, bool mute) { return -ENOSYS; }
static int adev_get_master_mute(struct audio_hw_device *dev, bool *mute) { *mute = false; return 0; }
static int adev_set_mode(struct audio_hw_device *dev, audio_mode_t mode) { return 0; }
static int adev_set_parameters(struct audio_hw_device *dev, const char *kv_pairs) { return 0; }
static char *adev_get_parameters(const struct audio_hw_device *dev, const char *keys) { return strdup(""); }
static size_t adev_get_input_buffer_size(const struct audio_hw_device *dev, const struct audio_config *config) { return 0; }
static int adev_open_input_stream(struct audio_hw_device *dev, audio_io_handle_t handle, audio_devices_t devices, struct audio_config *config, struct audio_stream_in **stream_in, audio_input_flags_t flags, const char *address, audio_source_t source) { return -ENOSYS; }
static void adev_close_input_stream(struct audio_hw_device *dev, struct audio_stream_in *stream) { }
static int adev_dump(const audio_hw_device_t *device, int fd) { return 0; }

static int adev_set_mic_mute(struct audio_hw_device *dev, bool state)
{
    struct biscuit_audio_device *adev = (struct biscuit_audio_device *)dev;
    adev->mic_mute = state;
    return 0;
}

static int adev_get_mic_mute(const struct audio_hw_device *dev, bool *state)
{
    const struct biscuit_audio_device *adev = (const struct biscuit_audio_device *)dev;
    *state = adev->mic_mute;
    return 0;
}

static int adev_open(const hw_module_t *module, const char *name, hw_device_t **device)
{
    struct biscuit_audio_device *adev;

    if (strcmp(name, AUDIO_HARDWARE_INTERFACE) != 0)
        return -EINVAL;

    adev = calloc(1, sizeof(*adev));
    if (!adev)
        return -ENOMEM;

    pthread_mutex_init(&adev->lock, NULL);
    adev->device.common.tag = HARDWARE_DEVICE_TAG;
    adev->device.common.version = AUDIO_DEVICE_API_VERSION_2_0;
    adev->device.common.module = (struct hw_module_t *)module;
    adev->device.common.close = adev_close;
    adev->device.get_supported_devices = adev_get_supported_devices;
    adev->device.init_check = adev_init_check;
    adev->device.set_voice_volume = adev_set_voice_volume;
    adev->device.set_master_volume = adev_set_master_volume;
    adev->device.get_master_volume = adev_get_master_volume;
    adev->device.set_master_mute = adev_set_master_mute;
    adev->device.get_master_mute = adev_get_master_mute;
    adev->device.set_mode = adev_set_mode;
    adev->device.set_mic_mute = adev_set_mic_mute;
    adev->device.get_mic_mute = adev_get_mic_mute;
    adev->device.set_parameters = adev_set_parameters;
    adev->device.get_parameters = adev_get_parameters;
    adev->device.get_input_buffer_size = adev_get_input_buffer_size;
    adev->device.open_output_stream = adev_open_output_stream;
    adev->device.close_output_stream = adev_close_output_stream;
    adev->device.open_input_stream = adev_open_input_stream;
    adev->device.close_input_stream = adev_close_input_stream;
    adev->device.dump = adev_dump;

    *device = &adev->device.common;
    return 0;
}

static struct hw_module_methods_t hal_module_methods = {
    .open = adev_open,
};

struct audio_module HAL_MODULE_INFO_SYM = {
    .common = {
        .tag = HARDWARE_MODULE_TAG,
        .module_api_version = AUDIO_MODULE_API_VERSION_0_1,
        .hal_api_version = HARDWARE_HAL_API_VERSION,
        .id = AUDIO_HARDWARE_MODULE_ID,
        .name = "Biscuit MT8163 speaker audio HAL",
        .author = "amazon_device_biscuit",
        .methods = &hal_module_methods,
    },
};
