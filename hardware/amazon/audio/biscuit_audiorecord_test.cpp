#include <math.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

#include <media/AudioRecord.h>
#include <system/audio.h>
#include <utils/Errors.h>
#include <utils/StrongPointer.h>

using android::AudioRecord;
using android::sp;
using android::status_t;

int main(int argc, char **argv)
{
    const uint32_t rate = 16000;
    const int seconds = argc > 1 ? atoi(argv[1]) : 1;
    const audio_source_t source = (audio_source_t)(argc > 2 ? atoi(argv[2]) : AUDIO_SOURCE_MIC);
    size_t min_frames = 0;
    status_t ret = AudioRecord::getMinFrameCount(&min_frames, rate,
                                                 AUDIO_FORMAT_PCM_16_BIT,
                                                 AUDIO_CHANNEL_IN_MONO);
    if (ret != android::NO_ERROR) {
        fprintf(stderr, "getMinFrameCount failed: %d\n", ret);
        return 1;
    }

    sp<AudioRecord> rec = new AudioRecord(source, rate, AUDIO_FORMAT_PCM_16_BIT,
                                          AUDIO_CHANNEL_IN_MONO, min_frames * 2,
                                          NULL, NULL, 0, AUDIO_SESSION_ALLOCATE,
                                          AudioRecord::TRANSFER_SYNC);
    ret = rec->initCheck();
    if (ret != android::NO_ERROR) {
        fprintf(stderr, "AudioRecord init failed: %d\n", ret);
        return 1;
    }

    ret = rec->start();
    if (ret != android::NO_ERROR) {
        fprintf(stderr, "AudioRecord start failed: %d\n", ret);
        return 1;
    }

    int16_t buf[256];
    int total = rate * seconds;
    int got = 0;
    double sum = 0;
    int peak = 0;

    while (got < total) {
        ssize_t n = rec->read(buf, sizeof(buf));
        if (n < 0) {
            fprintf(stderr, "AudioRecord read failed: %zd\n", n);
            return 1;
        }
        int samples = n / sizeof(int16_t);
        for (int i = 0; i < samples; i++) {
            int a = buf[i] < 0 ? -buf[i] : buf[i];
            if (a > peak) peak = a;
            sum += (double)buf[i] * (double)buf[i];
        }
        got += samples;
    }

    rec->stop();
    printf("samples=%d rms=%.0f peak=%d source=%d\n", got, sqrt(sum / got), peak, (int)source);
    fflush(stdout);
    _exit(0); /* ponytail: avoid CM12 destructor weirdness in shell tests. */
}
