#include <errno.h>
#include <pthread.h>
#include <signal.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#include <media/AudioRecord.h>
#include <media/AudioTrack.h>
#include <system/audio.h>
#include <tinyalsa/asoundlib.h>
#include <utils/Errors.h>
#include <utils/StrongPointer.h>

using android::AudioRecord;
using android::AudioTrack;
using android::sp;
using android::status_t;

#define USB_RATE 48000
#define USB_CHANNELS 2
#define USB_PERIOD 240
#define USB_PERIODS 4
#define MIC_RATE 16000
#define MIC_CHANNELS 1
#define MIC_PERIOD 160

static volatile sig_atomic_t running = 1;

struct pcm_id {
    int card;
    int device;
};

static void stop_handler(int)
{
    _exit(0);
}

static void fail_process(void)
{
    _exit(1);
}

static int parse_pcm_line(const char *line, int *card, int *device)
{
    return sscanf(line, "%02d-%02d:", card, device) == 2;
}

static int find_usb_pcm(struct pcm_id *id)
{
    FILE *f = fopen("/proc/asound/pcm", "r");
    char line[256];
    int fallback_card = -1, fallback_dev = -1;

    if (!f)
        return -errno;

    while (fgets(line, sizeof(line), f)) {
        int card = -1, dev = -1;
        if (!parse_pcm_line(line, &card, &dev))
            continue;
        if (!strstr(line, "playback") || !strstr(line, "capture"))
            continue;
        if (strstr(line, "UAC") || strstr(line, "uac") || strstr(line, "USB") || strstr(line, "Gadget")) {
            id->card = card;
            id->device = dev;
            fclose(f);
            return 0;
        }
        if (card != 0 && fallback_card < 0) {
            fallback_card = card;
            fallback_dev = dev;
        }
    }
    fclose(f);

    if (fallback_card >= 0) {
        id->card = fallback_card;
        id->device = fallback_dev;
        return 0;
    }
    return -ENODEV;
}

static void fill_usb_config(struct pcm_config *config, unsigned int period_size)
{
    memset(config, 0, sizeof(*config));
    config->channels = USB_CHANNELS;
    config->rate = USB_RATE;
    config->period_size = period_size;
    config->period_count = USB_PERIODS;
    config->format = PCM_FORMAT_S16_LE;
}

static void *usb_to_speaker(void *arg)
{
    struct pcm_id *usb = (struct pcm_id *)arg;
    struct pcm_config config;
    fill_usb_config(&config, USB_PERIOD);
    struct pcm *in = pcm_open(usb->card, usb->device, PCM_IN, &config);
    int16_t buf[USB_PERIOD * USB_CHANNELS];
    size_t min_frames = 0;
    status_t ret;

    if (!in || !pcm_is_ready(in)) {
        fprintf(stderr, "conference_bridge: usb capture %d,%d failed: %s\n",
                usb->card, usb->device, in ? pcm_get_error(in) : "NULL");
        fail_process();
        return NULL;
    }

    ret = AudioTrack::getMinFrameCount(&min_frames, AUDIO_STREAM_MUSIC, USB_RATE);
    if (ret != android::NO_ERROR) {
        fprintf(stderr, "conference_bridge: AudioTrack min frames failed: %d\n", ret);
        pcm_close(in);
        fail_process();
        return NULL;
    }

    AudioTrack track(AUDIO_STREAM_MUSIC, USB_RATE, AUDIO_FORMAT_PCM_16_BIT,
                     AUDIO_CHANNEL_OUT_STEREO, min_frames * 2,
                     AUDIO_OUTPUT_FLAG_NONE, NULL, NULL, 0,
                     AUDIO_SESSION_ALLOCATE, AudioTrack::TRANSFER_SYNC);
    ret = track.initCheck();
    if (ret != android::NO_ERROR) {
        fprintf(stderr, "conference_bridge: AudioTrack init failed: %d\n", ret);
        pcm_close(in);
        fail_process();
        return NULL;
    }
    ret = track.start();
    if (ret != android::NO_ERROR) {
        fprintf(stderr, "conference_bridge: AudioTrack start failed: %d\n", ret);
        pcm_close(in);
        fail_process();
        return NULL;
    }

    while (running) {
        if (pcm_read(in, buf, sizeof(buf)) != 0) {
            fprintf(stderr, "conference_bridge: usb read failed: %s\n", pcm_get_error(in));
            fail_process();
            break;
        }
        ssize_t n = track.write(buf, sizeof(buf), true);
        if (n < 0) {
            fprintf(stderr, "conference_bridge: AudioTrack write failed: %zd\n", n);
            fail_process();
            break;
        }
    }

    track.stop();
    pcm_close(in);
    return NULL;
}

static void *mic_to_usb(void *arg)
{
    struct pcm_id *usb = (struct pcm_id *)arg;
    struct pcm_config config;
    fill_usb_config(&config, USB_PERIOD * 3);
    struct pcm *out = pcm_open(usb->card, usb->device, PCM_OUT, &config);
    int16_t mic[MIC_PERIOD];
    int16_t usb_buf[MIC_PERIOD * 3 * USB_CHANNELS];
    size_t min_frames = 0;
    status_t ret;

    if (!out || !pcm_is_ready(out)) {
        fprintf(stderr, "conference_bridge: usb playback %d,%d failed: %s\n",
                usb->card, usb->device, out ? pcm_get_error(out) : "NULL");
        fail_process();
        return NULL;
    }

    ret = AudioRecord::getMinFrameCount(&min_frames, MIC_RATE,
                                        AUDIO_FORMAT_PCM_16_BIT,
                                        AUDIO_CHANNEL_IN_MONO);
    if (ret != android::NO_ERROR) {
        fprintf(stderr, "conference_bridge: AudioRecord min frames failed: %d\n", ret);
        pcm_close(out);
        fail_process();
        return NULL;
    }

    sp<AudioRecord> rec = new AudioRecord(AUDIO_SOURCE_VOICE_RECOGNITION, MIC_RATE,
                                          AUDIO_FORMAT_PCM_16_BIT,
                                          AUDIO_CHANNEL_IN_MONO, min_frames * 2,
                                          NULL, NULL, 0, AUDIO_SESSION_ALLOCATE,
                                          AudioRecord::TRANSFER_SYNC);
    ret = rec->initCheck();
    if (ret != android::NO_ERROR) {
        fprintf(stderr, "conference_bridge: AudioRecord init failed: %d\n", ret);
        pcm_close(out);
        fail_process();
        return NULL;
    }
    ret = rec->start();
    if (ret != android::NO_ERROR) {
        fprintf(stderr, "conference_bridge: AudioRecord start failed: %d\n", ret);
        pcm_close(out);
        fail_process();
        return NULL;
    }

    while (running) {
        ssize_t n = rec->read(mic, sizeof(mic));
        if (n < 0) {
            fprintf(stderr, "conference_bridge: AudioRecord read failed: %zd\n", n);
            fail_process();
            break;
        }
        int samples = n / sizeof(int16_t);
        int out_frames = 0;
        for (int i = 0; i < samples; ++i) {
            int16_t s = mic[i];
            for (int r = 0; r < 3; ++r) {
                usb_buf[out_frames * 2] = s;
                usb_buf[out_frames * 2 + 1] = s;
                ++out_frames;
            }
        }
        if (out_frames && pcm_write(out, usb_buf, out_frames * USB_CHANNELS * sizeof(int16_t)) != 0) {
            fprintf(stderr, "conference_bridge: usb write failed: %s\n", pcm_get_error(out));
            fail_process();
            break;
        }
    }

    rec->stop();
    pcm_close(out);
    return NULL;
}

int main(void)
{
    struct pcm_id usb;
    pthread_t speaker_thread, mic_thread;

    signal(SIGINT, stop_handler);
    signal(SIGTERM, stop_handler);

    if (find_usb_pcm(&usb) != 0) {
        fprintf(stderr, "conference_bridge: no UAC2 duplex PCM; run: biscuit_service usb conference on\n");
        return 1;
    }

    fprintf(stderr, "conference_bridge: using UAC2 pcm %d,%d at %d Hz stereo S16_LE\n",
            usb.card, usb.device, USB_RATE);

    if (pthread_create(&speaker_thread, NULL, usb_to_speaker, &usb) != 0) {
        perror("conference_bridge: pthread_create speaker");
        return 1;
    }
    if (pthread_create(&mic_thread, NULL, mic_to_usb, &usb) != 0) {
        perror("conference_bridge: pthread_create mic");
        _exit(1);
    }

    pthread_join(speaker_thread, NULL);
    running = 0;
    pthread_join(mic_thread, NULL);

    /* ponytail: v1 fixed 16k->48k nearest-neighbor upsample; real resampler only if call quality proves it matters. */
    _exit(0);
}
