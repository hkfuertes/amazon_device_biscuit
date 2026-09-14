#include <errno.h>
#include <math.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include <tinyalsa/asoundlib.h>

#define CARD 0
#define DEVICE 24
#define RATE 16000
#define CHANNELS 9
#define PERIOD_SIZE 256
#define PERIOD_COUNT 4

static int32_t s24_3le(const unsigned char *p)
{
    int32_t v = (int32_t)(p[0] | (p[1] << 8) | (p[2] << 16));
    if (v & 0x800000)
        v |= ~0xffffff;
    return v;
}

int main(int argc, char **argv)
{
    int seconds = argc > 1 ? atoi(argv[1]) : 1;
    struct pcm_config config = {
        .channels = CHANNELS,
        .rate = RATE,
        .period_size = PERIOD_SIZE,
        .period_count = PERIOD_COUNT,
        .format = PCM_FORMAT_S24_3LE,
    };
    struct pcm *pcm = pcm_open(CARD, DEVICE, PCM_IN, &config);
    unsigned char *buf;
    double sum[CHANNELS] = {0};
    int32_t peak[CHANNELS] = {0};
    int frames_total = 0;
    int periods = seconds * RATE / PERIOD_SIZE;

    if (!pcm || !pcm_is_ready(pcm)) {
        fprintf(stderr, "pcm_open failed: %s\n", pcm ? pcm_get_error(pcm) : "NULL");
        return 1;
    }

    buf = calloc(1, PERIOD_SIZE * CHANNELS * 3);
    if (!buf)
        return 1;

    for (int p = 0; p < periods; p++) {
        if (pcm_read(pcm, buf, PERIOD_SIZE * CHANNELS * 3) != 0) {
            fprintf(stderr, "pcm_read failed: %s\n", pcm_get_error(pcm));
            return 1;
        }
        for (int f = 0; f < PERIOD_SIZE; f++) {
            for (int ch = 0; ch < CHANNELS; ch++) {
                int32_t v = s24_3le(buf + (f * CHANNELS + ch) * 3);
                int32_t a = v < 0 ? -v : v;
                if (a > peak[ch]) peak[ch] = a;
                sum[ch] += (double)v * (double)v;
            }
        }
        frames_total += PERIOD_SIZE;
    }

    for (int ch = 0; ch < CHANNELS; ch++)
        printf("ch%d rms=%.0f peak=%d\n", ch, sqrt(sum[ch] / frames_total), peak[ch]);

    free(buf);
    pcm_close(pcm);
    return 0;
}
