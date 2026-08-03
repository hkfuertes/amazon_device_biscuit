#define LOG_TAG "audio.amazon_wrapper"

#include <errno.h>
#include <pthread.h>
#include <stdbool.h>
#include <stdlib.h>
#include <string.h>

#include <cutils/log.h>
#include <hardware/audio.h>
#include <hardware/hardware.h>

struct wrapper_audio_device {
    struct audio_hw_device device;
    struct audio_hw_device *amazon_device;
    pthread_mutex_t lock;
};

static struct audio_hw_device *amazon(struct audio_hw_device *dev)
{
    return ((struct wrapper_audio_device *)dev)->amazon_device;
}

static const struct audio_hw_device *camazon(const struct audio_hw_device *dev)
{
    return ((const struct wrapper_audio_device *)dev)->amazon_device;
}

static uint32_t adev_get_supported_devices(const struct audio_hw_device *dev)
{
    const struct audio_hw_device *a = camazon(dev);
    return a->get_supported_devices ? a->get_supported_devices(a) : 0;
}

static int adev_init_check(const struct audio_hw_device *dev)
{
    const struct audio_hw_device *a = camazon(dev);
    return a->init_check ? a->init_check(a) : 0;
}

static int adev_set_voice_volume(struct audio_hw_device *dev, float volume)
{
    struct audio_hw_device *a = amazon(dev);
    return a->set_voice_volume ? a->set_voice_volume(a, volume) : 0;
}

static int adev_set_master_volume(struct audio_hw_device *dev, float volume)
{
    struct audio_hw_device *a = amazon(dev);
    return a->set_master_volume ? a->set_master_volume(a, volume) : -ENOSYS;
}

static int adev_get_master_volume(struct audio_hw_device *dev, float *volume)
{
    struct audio_hw_device *a = amazon(dev);
    if (a->get_master_volume)
        return a->get_master_volume(a, volume);
    *volume = 1.0f;
    return 0;
}

static int adev_set_master_mute(struct audio_hw_device *dev, bool mute)
{
    struct audio_hw_device *a = amazon(dev);
    return a->set_master_mute ? a->set_master_mute(a, mute) : -ENOSYS;
}

static int adev_get_master_mute(struct audio_hw_device *dev, bool *mute)
{
    struct audio_hw_device *a = amazon(dev);
    if (a->get_master_mute)
        return a->get_master_mute(a, mute);
    *mute = false;
    return 0;
}

static int adev_set_mode(struct audio_hw_device *dev, audio_mode_t mode)
{
    struct audio_hw_device *a = amazon(dev);
    return a->set_mode ? a->set_mode(a, mode) : 0;
}

static int adev_set_mic_mute(struct audio_hw_device *dev, bool state)
{
    struct audio_hw_device *a = amazon(dev);
    return a->set_mic_mute ? a->set_mic_mute(a, state) : 0;
}

static int adev_get_mic_mute(const struct audio_hw_device *dev, bool *state)
{
    const struct audio_hw_device *a = camazon(dev);
    if (a->get_mic_mute)
        return a->get_mic_mute(a, state);
    *state = false;
    return 0;
}

static int adev_set_parameters(struct audio_hw_device *dev, const char *kv_pairs)
{
    struct audio_hw_device *a = amazon(dev);
    return a->set_parameters ? a->set_parameters(a, kv_pairs) : 0;
}

static char *adev_get_parameters(const struct audio_hw_device *dev, const char *keys)
{
    const struct audio_hw_device *a = camazon(dev);
    return a->get_parameters ? a->get_parameters(a, keys) : strdup("");
}

static size_t adev_get_input_buffer_size(const struct audio_hw_device *dev,
                                         const struct audio_config *config)
{
    const struct audio_hw_device *a = camazon(dev);
    return a->get_input_buffer_size ? a->get_input_buffer_size(a, config) : 0;
}

static int adev_open_output_stream(struct audio_hw_device *dev,
                                   audio_io_handle_t handle,
                                   audio_devices_t devices,
                                   audio_output_flags_t flags,
                                   struct audio_config *config,
                                   struct audio_stream_out **stream_out,
                                   const char *address)
{
    struct audio_hw_device *a = amazon(dev);
    return a->open_output_stream(a, handle, devices, flags, config, stream_out, address);
}

static void adev_close_output_stream(struct audio_hw_device *dev, struct audio_stream_out *stream)
{
    struct audio_hw_device *a = amazon(dev);
    a->close_output_stream(a, stream);
}

static int adev_open_input_stream(struct audio_hw_device *dev, audio_io_handle_t handle,
                                  audio_devices_t devices, struct audio_config *config,
                                  struct audio_stream_in **stream_in,
                                  audio_input_flags_t flags, const char *address,
                                  audio_source_t source)
{
    struct audio_hw_device *a = amazon(dev);
    return a->open_input_stream(a, handle, devices, config, stream_in, flags, address, source);
}

static void adev_close_input_stream(struct audio_hw_device *dev, struct audio_stream_in *stream)
{
    struct audio_hw_device *a = amazon(dev);
    a->close_input_stream(a, stream);
}

static int adev_dump(const struct audio_hw_device *dev, int fd)
{
    const struct audio_hw_device *a = camazon(dev);
    return a->dump ? a->dump(a, fd) : 0;
}

static int adev_create_audio_patch(struct audio_hw_device *dev, unsigned int num_sources,
                                   const struct audio_port_config *sources, unsigned int num_sinks,
                                   const struct audio_port_config *sinks,
                                   audio_patch_handle_t *handle)
{
    struct audio_hw_device *a = amazon(dev);
    return a->create_audio_patch ? a->create_audio_patch(a, num_sources, sources, num_sinks, sinks, handle) : -ENOSYS;
}

static int adev_release_audio_patch(struct audio_hw_device *dev, audio_patch_handle_t handle)
{
    struct audio_hw_device *a = amazon(dev);
    return a->release_audio_patch ? a->release_audio_patch(a, handle) : -ENOSYS;
}

static int adev_get_audio_port(struct audio_hw_device *dev, struct audio_port *port)
{
    struct audio_hw_device *a = amazon(dev);
    return a->get_audio_port ? a->get_audio_port(a, port) : -ENOSYS;
}

static int adev_set_audio_port_config(struct audio_hw_device *dev, const struct audio_port_config *config)
{
    struct audio_hw_device *a = amazon(dev);
    return a->set_audio_port_config ? a->set_audio_port_config(a, config) : -ENOSYS;
}

static int adev_close(hw_device_t *device)
{
    struct wrapper_audio_device *adev = (struct wrapper_audio_device *)device;

    if (!adev)
        return 0;
    if (adev->amazon_device)
        adev->amazon_device->common.close((hw_device_t *)adev->amazon_device);
    pthread_mutex_destroy(&adev->lock);
    free(adev);
    return 0;
}

static int adev_open(const hw_module_t *module, const char *name, hw_device_t **device)
{
    int rc;
    struct wrapper_audio_device *adev;
    const hw_module_t *amazon_module;

    if (strcmp(name, AUDIO_HARDWARE_INTERFACE) != 0)
        return -EINVAL;

    adev = calloc(1, sizeof(*adev));
    if (!adev)
        return -ENOMEM;

    pthread_mutex_init(&adev->lock, NULL);

    /* ponytail: wrapper only; stock OTA HAL does routing/tuning below us. */
    rc = hw_get_module_by_class(AUDIO_HARDWARE_MODULE_ID, "primary_amazon", &amazon_module);
    if (rc < 0) {
        ALOGE("failed to load stock amazon audio HAL: %d", rc);
        goto fail;
    }

    rc = amazon_module->methods->open(amazon_module, name, (hw_device_t **)&adev->amazon_device);
    if (rc < 0) {
        ALOGE("failed to open stock amazon audio HAL: %d", rc);
        goto fail;
    }

    adev->device.common.tag = HARDWARE_DEVICE_TAG;
    adev->device.common.version = AUDIO_DEVICE_API_VERSION_2_0;
    adev->device.common.module = (hw_module_t *)module;
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
    adev->device.create_audio_patch = adev_create_audio_patch;
    adev->device.release_audio_patch = adev_release_audio_patch;
    adev->device.get_audio_port = adev_get_audio_port;
    adev->device.set_audio_port_config = adev_set_audio_port_config;

    *device = &adev->device.common;
    return 0;

fail:
    pthread_mutex_destroy(&adev->lock);
    free(adev);
    return rc;
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
        .name = "Biscuit Amazon audio HAL wrapper",
        .author = "amazon_device_biscuit",
        .methods = &hal_module_methods,
    },
};
