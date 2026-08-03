#include <errno.h>
#include <signal.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <unistd.h>

#include <binder/Binder.h>
#include <binder/IServiceManager.h>
#include <binder/IPCThreadState.h>
#include <binder/Parcel.h>
#include <binder/ProcessState.h>
#include <media/AudioRecord.h>
#include <system/audio.h>
#include <utils/Errors.h>
#include <utils/String16.h>
#include <utils/StrongPointer.h>

using android::AudioRecord;
using android::BBinder;
using android::defaultServiceManager;
using android::IBinder;
using android::Parcel;
using android::ProcessState;
using android::sp;
using android::status_t;
using android::String16;

static const char* kAspServiceName = "audiosignalprocessor";
static const String16 kAspInterface("com.amazon.asp.IAudioSignalProcessor");
static const String16 kEventInterface("com.amazon.asp.IAudioEventListener");
static const uint32_t kRegisterListener = 1;
static const uint32_t kUnregisterListener = 2;
static volatile sig_atomic_t g_stop;

static void stop_handler(int)
{
    g_stop = 1;
}

class AspEventListener : public BBinder {
public:
    const String16& getInterfaceDescriptor() const { return kEventInterface; }

protected:
    status_t onTransact(uint32_t code, const Parcel& data, Parcel* reply, uint32_t flags)
    {
        (void)reply;
        (void)flags;
        if (code != 1) {
            return BBinder::onTransact(code, data, reply, flags);
        }
        if (!data.enforceInterface(kEventInterface)) {
            return android::PERMISSION_DENIED;
        }

        int32_t what = 0;
        int32_t size = 0;
        status_t err = data.readInt32(&what);
        if (err == android::NO_ERROR) err = data.readInt32(&size);
        if (err != android::NO_ERROR || size < 0 || size > 4096) {
            printf("asp_event_bad what=%d size=%d err=%d\n", what, size, err);
            fflush(stdout);
            return android::NO_ERROR;
        }

        const uint8_t* bytes = static_cast<const uint8_t*>(data.readInplace(size));
        if (size && bytes == NULL) {
            printf("asp_event_bad what=%d size=%d err=readInplace\n", what, size);
            fflush(stdout);
            return android::NO_ERROR;
        }

        printf("asp_event what=%d size=%d", what, size);
        if (size == 4) {
            int32_t v;
            memcpy(&v, bytes, sizeof(v));
            printf(" int32=%d", v);
        }
        printf(" bytes=");
        int shown = size < 32 ? size : 32;
        for (int i = 0; i < shown; ++i) printf("%02x", bytes[i]);
        if (shown < size) printf("...");
        printf("\n");
        fflush(stdout);
        return android::NO_ERROR;
    }
};

static status_t send_listener(const sp<IBinder>& asp, uint32_t code, const sp<IBinder>& listener)
{
    Parcel data;
    status_t err = data.writeInterfaceToken(kAspInterface);
    if (err != android::NO_ERROR) return err;
    err = data.writeStrongBinder(listener);
    if (err != android::NO_ERROR) return err;
    return asp->transact(code, data, NULL, 0);
}

int main(int argc, char** argv)
{
    const int seconds_arg = argc > 1 ? atoi(argv[1]) : 20;
    const int seconds = seconds_arg > 0 ? seconds_arg : 20;
    const uint32_t rate = 16000;
    signal(SIGINT, stop_handler);
    signal(SIGTERM, stop_handler);

    ProcessState::self()->startThreadPool();

    sp<IBinder> asp = defaultServiceManager()->checkService(String16(kAspServiceName));
    if (asp == NULL) {
        fprintf(stderr, "%s service not found\n", kAspServiceName);
        return 1;
    }

    sp<IBinder> listener = new AspEventListener();
    status_t ret = send_listener(asp, kRegisterListener, listener);
    if (ret != android::NO_ERROR) {
        fprintf(stderr, "register listener failed: %d\n", ret);
        return 1;
    }

    size_t min_frames = 0;
    ret = AudioRecord::getMinFrameCount(&min_frames, rate,
                                        AUDIO_FORMAT_PCM_16_BIT,
                                        AUDIO_CHANNEL_IN_MONO);
    if (ret != android::NO_ERROR) {
        fprintf(stderr, "getMinFrameCount failed: %d\n", ret);
        send_listener(asp, kUnregisterListener, listener);
        return 1;
    }

    sp<AudioRecord> rec = new AudioRecord(AUDIO_SOURCE_VOICE_RECOGNITION, rate,
                                          AUDIO_FORMAT_PCM_16_BIT,
                                          AUDIO_CHANNEL_IN_MONO, min_frames * 2,
                                          NULL, NULL, 0, AUDIO_SESSION_ALLOCATE,
                                          AudioRecord::TRANSFER_SYNC);
    ret = rec->initCheck();
    if (ret != android::NO_ERROR) {
        fprintf(stderr, "AudioRecord init failed: %d\n", ret);
        send_listener(asp, kUnregisterListener, listener);
        return 1;
    }

    ret = rec->start();
    if (ret != android::NO_ERROR) {
        fprintf(stderr, "AudioRecord start failed: %d\n", ret);
        send_listener(asp, kUnregisterListener, listener);
        return 1;
    }

    printf("listening seconds=%d source=VOICE_RECOGNITION discard_audio=1\n", seconds);
    fflush(stdout);

    int16_t buf[256];
    const time_t end = time(NULL) + (seconds > 0 ? seconds : 20);
    while (!g_stop && time(NULL) < end) {
        ssize_t n = rec->read(buf, sizeof(buf));
        if (n < 0) {
            fprintf(stderr, "AudioRecord read failed: %zd\n", n);
            break;
        }
    }

    rec->stop();
    send_listener(asp, kUnregisterListener, listener);
    printf("done\n");
    fflush(stdout);
    _exit(0); /* ponytail: avoid CM12 destructor weirdness after AudioRecord. */
}
