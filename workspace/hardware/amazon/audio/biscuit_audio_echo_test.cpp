#include <math.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#include <media/AudioRecord.h>
#include <media/AudioTrack.h>
#include <system/audio.h>
#include <utils/Errors.h>
#include <utils/StrongPointer.h>

using android::AudioRecord;
using android::AudioTrack;
using android::sp;
using android::status_t;

static void put_u16(FILE *f, uint16_t v)
{
    fputc(v & 0xff, f);
    fputc((v >> 8) & 0xff, f);
}

static void put_u32(FILE *f, uint32_t v)
{
    put_u16(f, v & 0xffff);
    put_u16(f, (v >> 16) & 0xffff);
}

static int write_wav(const char *path, const int16_t *samples, uint32_t sample_count,
                     uint32_t rate, uint16_t channels)
{
    FILE *f = fopen(path, "wb");
    uint32_t data_bytes = sample_count * sizeof(int16_t);
    if (!f) {
        perror(path);
        return 1;
    }

    fwrite("RIFF", 1, 4, f); put_u32(f, 36 + data_bytes);
    fwrite("WAVEfmt ", 1, 8, f); put_u32(f, 16);
    put_u16(f, 1); put_u16(f, channels); put_u32(f, rate);
    put_u32(f, rate * channels * sizeof(int16_t));
    put_u16(f, channels * sizeof(int16_t)); put_u16(f, 16);
    fwrite("data", 1, 4, f); put_u32(f, data_bytes);
    fwrite(samples, sizeof(int16_t), sample_count, f);
    fclose(f);
    return 0;
}

int main(int argc, char **argv)
{
    const uint32_t rate = 16000;
    const int seconds = argc > 1 ? atoi(argv[1]) : 3;
    const char *wav_path = argc > 2 ? argv[2] : "/sdcard/biscuit-echo-test.wav";
    const int total = rate * seconds;
    int16_t *mono = (int16_t *)calloc(total, sizeof(int16_t));
    int16_t *stereo = (int16_t *)calloc(total * 2, sizeof(int16_t));
    size_t min_frames = 0;
    status_t ret;
    int got = 0;
    double sum = 0;
    int peak = 0;

    if (seconds <= 0 || !mono || !stereo) {
        fprintf(stderr, "usage: %s [seconds] [wav_path]\n", argv[0]);
        return 1;
    }

    ret = AudioRecord::getMinFrameCount(&min_frames, rate,
                                        AUDIO_FORMAT_PCM_16_BIT,
                                        AUDIO_CHANNEL_IN_MONO);
    if (ret != android::NO_ERROR) {
        fprintf(stderr, "AudioRecord getMinFrameCount failed: %d\n", ret);
        return 1;
    }

    sp<AudioRecord> rec = new AudioRecord(AUDIO_SOURCE_MIC, rate, AUDIO_FORMAT_PCM_16_BIT,
                                          AUDIO_CHANNEL_IN_MONO, min_frames * 2,
                                          NULL, NULL, 0, AUDIO_SESSION_ALLOCATE,
                                          AudioRecord::TRANSFER_SYNC);
    ret = rec->initCheck();
    if (ret != android::NO_ERROR) {
        fprintf(stderr, "AudioRecord init failed: %d\n", ret);
        return 1;
    }

    printf("recording %d seconds via AudioRecord/HAL...\n", seconds);
    ret = rec->start();
    if (ret != android::NO_ERROR) {
        fprintf(stderr, "AudioRecord start failed: %d\n", ret);
        return 1;
    }

    while (got < total) {
        ssize_t n = rec->read(mono + got, (total - got) * sizeof(int16_t));
        if (n < 0) {
            fprintf(stderr, "AudioRecord read failed: %zd\n", n);
            return 1;
        }
        if (n == 0)
            continue;
        got += n / sizeof(int16_t);
    }
    rec->stop();

    for (int i = 0; i < got; i++) {
        int a = mono[i] < 0 ? -mono[i] : mono[i];
        if (a > peak) peak = a;
        sum += (double)mono[i] * (double)mono[i];
        stereo[i * 2] = mono[i];
        stereo[i * 2 + 1] = mono[i];
    }

    if (write_wav(wav_path, mono, got, rate, 1) != 0)
        return 1;
    printf("saved %s samples=%d rms=%.0f peak=%d\n", wav_path, got, sqrt(sum / got), peak);

    ret = AudioTrack::getMinFrameCount(&min_frames, AUDIO_STREAM_MUSIC, rate);
    if (ret != android::NO_ERROR) {
        fprintf(stderr, "AudioTrack getMinFrameCount failed: %d\n", ret);
        return 1;
    }

    AudioTrack track(AUDIO_STREAM_MUSIC, rate, AUDIO_FORMAT_PCM_16_BIT,
                     AUDIO_CHANNEL_OUT_STEREO, min_frames * 2,
                     AUDIO_OUTPUT_FLAG_NONE, NULL, NULL, 0,
                     AUDIO_SESSION_ALLOCATE, AudioTrack::TRANSFER_SYNC);
    ret = track.initCheck();
    if (ret != android::NO_ERROR) {
        fprintf(stderr, "AudioTrack init failed: %d\n", ret);
        return 1;
    }

    printf("playing recording via AudioTrack/HAL...\n");
    ret = track.start();
    if (ret != android::NO_ERROR) {
        fprintf(stderr, "AudioTrack start failed: %d\n", ret);
        return 1;
    }

    int written = 0;
    while (written < got) {
        ssize_t n = track.write(stereo + written * 2, (got - written) * 2 * sizeof(int16_t), true);
        if (n < 0) {
            fprintf(stderr, "AudioTrack write failed: %zd\n", n);
            return 1;
        }
        written += n / (2 * sizeof(int16_t));
    }

    usleep(300000);
    track.stop();
    printf("played %d frames\n", written);
    fflush(stdout);
    _exit(0); /* ponytail: avoid CM12 destructor weirdness in shell tests. */
}
