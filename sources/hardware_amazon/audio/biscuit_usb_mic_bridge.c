#include <errno.h>
#include <signal.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#include <tinyalsa/asoundlib.h>

#define IN_CARD 0
#define IN_DEVICE 24
#define IN_RATE 16000
#define IN_CHANNELS 9
#define IN_PERIOD 256
#define IN_PERIODS 4

#define OUT_RATE 44100
#define OUT_CHANNELS 2
#define OUT_PERIODS 4

static volatile sig_atomic_t running = 1;

static void stop(int sig)
{
    (void)sig;
    running = 0;
}

static int32_t s24_3le_to_s32(const unsigned char *p)
{
    int32_t v = (int32_t)(p[0] | (p[1] << 8) | (p[2] << 16));
    if (v & 0x800000)
        v |= ~0xffffff;
    return v;
}

static int route_enum_or_value(struct mixer *mixer, const char *name, const char *value, int fallback)
{
    struct mixer_ctl *ctl = mixer_get_ctl_by_name(mixer, name);
    unsigned int i, n;
    int ret;

    if (!ctl)
        return -ENOENT;

    ret = mixer_ctl_set_enum_by_string(ctl, value);
    if (ret == 0)
        return 0;

    n = mixer_ctl_get_num_values(ctl);
    for (i = 0; i < n; i++)
        ret = mixer_ctl_set_value(ctl, i, fallback);
    return ret;
}

static int route_value(struct mixer *mixer, const char *name, int v0, int v1)
{
    struct mixer_ctl *ctl = mixer_get_ctl_by_name(mixer, name);
    if (!ctl)
        return -ENOENT;
    if (mixer_ctl_get_num_values(ctl) > 0)
        mixer_ctl_set_value(ctl, 0, v0);
    if (mixer_ctl_get_num_values(ctl) > 1)
        mixer_ctl_set_value(ctl, 1, v1);
    return 0;
}

static void apply_mic_route(void)
{
    struct mixer *mixer = mixer_open(IN_CARD);
    const char *adcs[] = {"A", "B", "C", "D"};
    unsigned int i;

    if (!mixer)
        return;

    /* ponytail: same fixed 7-mic route as audio_hw.c; expose ch0 to USB for first pass. */
    for (i = 0; i < 4; i++) {
        char name[80];
        snprintf(name, sizeof(name), "ADC_%s Left Ip Select ADC_%s DIF1_L switch", adcs[i], adcs[i]);
        route_enum_or_value(mixer, name, "On", 1);
        snprintf(name, sizeof(name), "ADC_%s Right Ip Select ADC_%s DIF1_R switch", adcs[i], adcs[i]);
        route_enum_or_value(mixer, name, "On", 1);
        snprintf(name, sizeof(name), "ADC_%s MICPGA Volume Ctrl", adcs[i]);
        route_value(mixer, name, 40, 40);
        snprintf(name, sizeof(name), "ADC_%s DIF1_L Input Gain", adcs[i]);
        route_enum_or_value(mixer, name, "Off", 0);
        snprintf(name, sizeof(name), "ADC_%s DIF1_R Input Gain", adcs[i]);
        route_enum_or_value(mixer, name, "Off", 0);
    }
    route_enum_or_value(mixer, "SpiTimeStamps", "Off", 0);
    mixer_close(mixer);
}

static int read_usb_pcm(int *card, int *device)
{
    FILE *f = fopen("/sys/class/android_usb/android0/f_audio_source/pcm", "r");
    if (!f)
        return -errno;
    if (fscanf(f, "%d %d", card, device) != 2 || *card < 0 || *device < 0) {
        fclose(f);
        return -ENODEV;
    }
    fclose(f);
    return 0;
}

int main(void)
{
    int out_card = -1, out_device = -1;
    struct pcm_config in_config = {
        .channels = IN_CHANNELS,
        .rate = IN_RATE,
        .period_size = IN_PERIOD,
        .period_count = IN_PERIODS,
        .format = PCM_FORMAT_S24_3LE,
    };
    struct pcm_config out_config = {
        .channels = OUT_CHANNELS,
        .rate = OUT_RATE,
        .period_size = 1024,
        .period_count = OUT_PERIODS,
        .format = PCM_FORMAT_S16_LE,
    };
    struct pcm *in = NULL, *out = NULL;
    unsigned char raw[IN_PERIOD * IN_CHANNELS * 3];
    int16_t mono[IN_PERIOD];
    int16_t stereo[1024 * OUT_CHANNELS];
    uint64_t pos = 0;
    const uint64_t step = ((uint64_t)IN_RATE << 32) / OUT_RATE;

    signal(SIGINT, stop);
    signal(SIGTERM, stop);

    if (read_usb_pcm(&out_card, &out_device) != 0) {
        fprintf(stderr, "audio_source is not active; run: biscuit_service usb mic on\n");
        return 1;
    }

    apply_mic_route();
    in = pcm_open(IN_CARD, IN_DEVICE, PCM_IN, &in_config);
    if (!in || !pcm_is_ready(in)) {
        fprintf(stderr, "pcm_open mic %d,%d failed: %s\n", IN_CARD, IN_DEVICE, in ? pcm_get_error(in) : "NULL");
        return 1;
    }

    out = pcm_open(out_card, out_device, PCM_OUT, &out_config);
    if (!out || !pcm_is_ready(out)) {
        fprintf(stderr, "pcm_open usb %d,%d failed: %s\n", out_card, out_device, out ? pcm_get_error(out) : "NULL");
        pcm_close(in);
        return 1;
    }

    fprintf(stderr, "bridging mic %d,%d -> usb %d,%d\n", IN_CARD, IN_DEVICE, out_card, out_device);

    while (running) {
        unsigned out_frames = 0;
        if (pcm_read(in, raw, sizeof(raw)) != 0) {
            fprintf(stderr, "pcm_read failed: %s\n", pcm_get_error(in));
            break;
        }

        for (unsigned i = 0; i < IN_PERIOD; i++)
            mono[i] = (int16_t)(s24_3le_to_s32(raw + i * IN_CHANNELS * 3) >> 8);

        while ((pos >> 32) < IN_PERIOD && out_frames < 1024) {
            int16_t s = mono[pos >> 32];
            stereo[out_frames * 2] = s;
            stereo[out_frames * 2 + 1] = s;
            out_frames++;
            pos += step;
        }
        pos -= (uint64_t)IN_PERIOD << 32;

        if (out_frames && pcm_write(out, stereo, out_frames * OUT_CHANNELS * sizeof(int16_t)) != 0) {
            fprintf(stderr, "pcm_write failed: %s\n", pcm_get_error(out));
            break;
        }
    }

    pcm_close(out);
    pcm_close(in);
    return 0;
}
