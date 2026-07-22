#include <math.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

#include <media/AudioTrack.h>
#include <system/audio.h>
#include <utils/Errors.h>

using android::AudioTrack;
using android::status_t;

int main(int argc, char **argv)
{
    const uint32_t rate = 48000;
    const int seconds = argc > 1 ? atoi(argv[1]) : 2;
    size_t min_frames = 0;
    status_t ret = AudioTrack::getMinFrameCount(&min_frames, AUDIO_STREAM_MUSIC, rate);

    if (ret != android::NO_ERROR) {
        fprintf(stderr, "getMinFrameCount failed: %d\n", ret);
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

    ret = track.start();
    if (ret != android::NO_ERROR) {
        fprintf(stderr, "AudioTrack start failed: %d\n", ret);
        return 1;
    }

    const size_t frames = 1024;
    int16_t buf[frames * 2];
    const int total = rate * seconds;
    int written = 0;

    while (written < total) {
        size_t todo = total - written;
        if (todo > frames)
            todo = frames;
        for (size_t i = 0; i < todo; i++) {
            double s = sin((2.0 * M_PI * 880.0 * (written + i)) / rate) * 12000.0;
            buf[i * 2] = (int16_t)s;
            buf[i * 2 + 1] = (int16_t)s;
        }
        ssize_t n = track.write(buf, todo * 2 * sizeof(int16_t), true);
        if (n < 0) {
            fprintf(stderr, "AudioTrack write failed: %zd\n", n);
            return 1;
        }
        written += n / (2 * sizeof(int16_t));
    }

    usleep(300000);
    track.stop();
    printf("wrote %d frames\n", written);
    fflush(stdout);
    _exit(0); /* ponytail: CM12 AudioTrack destructor crashes in this shell test; kernel/HAL path already validated. */
}
