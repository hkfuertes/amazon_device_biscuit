#define LOG_TAG "BiscuitSensors"

#include <errno.h>
#include <fcntl.h>
#include <hardware/hardware.h>
#include <hardware/sensors.h>
#include <cutils/log.h>
#include <dirent.h>
#include <limits.h>
#include <pthread.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <unistd.h>

#define LIGHT_HANDLE 1
#define DEFAULT_DELAY_NS 500000000LL
#define MIN_DELAY_US 200000

struct biscuit_poll_device {
    struct sensors_poll_device_t device;
    pthread_mutex_t lock;
    int active;
    int64_t delay_ns;
    char lux_path[PATH_MAX];
};

static const struct sensor_t sSensorList[] = {{
    .name = "Biscuit ambient light",
    .vendor = "AMS/TAOS",
    .version = 1,
    .handle = LIGHT_HANDLE,
    .type = SENSOR_TYPE_LIGHT,
    .maxRange = 65535.0f,
    .resolution = 1.0f,
    .power = 0.1f,
    .minDelay = MIN_DELAY_US,
    .fifoReservedEventCount = 0,
    .fifoMaxEventCount = 0,
    .stringType = SENSOR_STRING_TYPE_LIGHT,
    .requiredPermission = "",
    .maxDelay = 1000000,
    .flags = SENSOR_FLAG_ON_CHANGE_MODE,
    .reserved = {0},
}};

static int find_lux_path(char *out, size_t out_len)
{
    const char *fixed = "/sys/bus/iio/devices/iio:device0/illuminance0_input";
    if (access(fixed, R_OK) == 0) {
        strlcpy(out, fixed, out_len);
        return 0;
    }

    DIR *dir = opendir("/sys/bus/iio/devices");
    if (!dir) return -errno;

    struct dirent *de;
    while ((de = readdir(dir)) != NULL) {
        if (strncmp(de->d_name, "iio:device", 10) != 0) continue;
        char path[PATH_MAX];
        snprintf(path, sizeof(path), "/sys/bus/iio/devices/%s/illuminance0_input", de->d_name);
        if (access(path, R_OK) == 0) {
            strlcpy(out, path, out_len);
            closedir(dir);
            return 0;
        }
    }

    closedir(dir);
    return -ENOENT;
}

static int read_lux(struct biscuit_poll_device *dev, float *lux)
{
    if (!dev->lux_path[0] && find_lux_path(dev->lux_path, sizeof(dev->lux_path)) < 0)
        return -ENOENT;

    FILE *f = fopen(dev->lux_path, "r");
    if (!f) {
        dev->lux_path[0] = '\0';
        return -errno;
    }

    float value = 0.0f;
    int ok = fscanf(f, "%f", &value);
    fclose(f);
    if (ok != 1) return -EIO;

    *lux = value < 0.0f ? 0.0f : value;
    return 0;
}

static int64_t now_ns(void)
{
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return (int64_t)ts.tv_sec * 1000000000LL + ts.tv_nsec;
}

static void sleep_ns(int64_t ns)
{
    if (ns < 10000000LL) ns = 10000000LL;
    struct timespec ts = { ns / 1000000000LL, ns % 1000000000LL };
    nanosleep(&ts, NULL);
}

static int poll__activate(struct sensors_poll_device_t *d, int handle, int enabled)
{
    if (handle != LIGHT_HANDLE) return -EINVAL;
    struct biscuit_poll_device *dev = (struct biscuit_poll_device *)d;
    pthread_mutex_lock(&dev->lock);
    dev->active = enabled ? 1 : 0;
    pthread_mutex_unlock(&dev->lock);
    return 0;
}

static int poll__setDelay(struct sensors_poll_device_t *d, int handle, int64_t ns)
{
    if (handle != LIGHT_HANDLE) return -EINVAL;
    if (ns < (int64_t)MIN_DELAY_US * 1000LL) ns = (int64_t)MIN_DELAY_US * 1000LL;
    struct biscuit_poll_device *dev = (struct biscuit_poll_device *)d;
    pthread_mutex_lock(&dev->lock);
    dev->delay_ns = ns;
    pthread_mutex_unlock(&dev->lock);
    return 0;
}

static int poll__poll(struct sensors_poll_device_t *d, sensors_event_t *data, int count)
{
    if (count < 1) return -EINVAL;
    struct biscuit_poll_device *dev = (struct biscuit_poll_device *)d;

    pthread_mutex_lock(&dev->lock);
    int active = dev->active;
    int64_t delay = dev->delay_ns;
    pthread_mutex_unlock(&dev->lock);

    sleep_ns(active ? delay : DEFAULT_DELAY_NS);
    if (!active) return 0;

    float lux = 0.0f;
    if (read_lux(dev, &lux) < 0) return 0;

    memset(data, 0, sizeof(*data));
    data->version = sizeof(*data);
    data->sensor = LIGHT_HANDLE;
    data->type = SENSOR_TYPE_LIGHT;
    data->timestamp = now_ns();
    data->light = lux;
    return 1;
}

static int poll__close(struct hw_device_t *dev)
{
    struct biscuit_poll_device *poll = (struct biscuit_poll_device *)dev;
    pthread_mutex_destroy(&poll->lock);
    free(poll);
    return 0;
}

static int sensors__get_sensors_list(struct sensors_module_t *module,
        struct sensor_t const **list)
{
    (void)module;
    *list = sSensorList;
    return sizeof(sSensorList) / sizeof(sSensorList[0]);
}

static int open_sensors(const struct hw_module_t *module, const char *name,
        struct hw_device_t **device)
{
    if (strcmp(name, SENSORS_HARDWARE_POLL) != 0) return -EINVAL;

    struct biscuit_poll_device *dev = calloc(1, sizeof(*dev));
    if (!dev) return -ENOMEM;

    dev->device.common.tag = HARDWARE_DEVICE_TAG;
    dev->device.common.version = SENSORS_DEVICE_API_VERSION_1_0;
    dev->device.common.module = (struct hw_module_t *)module;
    dev->device.common.close = poll__close;
    dev->device.activate = poll__activate;
    dev->device.setDelay = poll__setDelay;
    dev->device.poll = poll__poll;
    dev->delay_ns = DEFAULT_DELAY_NS;
    pthread_mutex_init(&dev->lock, NULL);
    find_lux_path(dev->lux_path, sizeof(dev->lux_path));

    *device = &dev->device.common;
    return 0;
}

static struct hw_module_methods_t sensors_module_methods = {
    .open = open_sensors,
};

struct sensors_module_t HAL_MODULE_INFO_SYM = {
    .common = {
        .tag = HARDWARE_MODULE_TAG,
        .version_major = 1,
        .version_minor = 0,
        .id = SENSORS_HARDWARE_MODULE_ID,
        .name = "Biscuit Sensors",
        .author = "Amazon/CM12 biscuit",
        .methods = &sensors_module_methods,
    },
    .get_sensors_list = sensors__get_sensors_list,
};
