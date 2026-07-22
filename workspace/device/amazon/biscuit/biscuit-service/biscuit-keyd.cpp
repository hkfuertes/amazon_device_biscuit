#include <errno.h>
#include <fcntl.h>
#include <linux/input.h>
#include <poll.h>
#include <stdio.h>
#include <string.h>
#include <sys/socket.h>
#include <sys/un.h>
#include <unistd.h>

#define SOCKET_PATH "/dev/socket/biscuit-ledd"

// ponytail: Action/circle long-press BT pairing removed until BT UX is wanted.
#define ACTION_KEY      KEY_HELP

static void send_led(const char* cmd) {
    int s = socket(AF_UNIX, SOCK_STREAM, 0);
    if (s < 0) return;
    sockaddr_un addr;
    memset(&addr, 0, sizeof(addr));
    addr.sun_family = AF_UNIX;
    strncpy(addr.sun_path, SOCKET_PATH, sizeof(addr.sun_path) - 1);
    if (connect(s, (sockaddr*)&addr, sizeof(addr)) == 0) {
        write(s, cmd, strlen(cmd));
        char buf[64];
        read(s, buf, sizeof(buf));
    }
    close(s);
}

int main() {
    const char* paths[] = { "/dev/input/event1", "/dev/input/event2" };
    pollfd fds[2];
    int n = 0;
    for (int i = 0; i < 2; ++i) {
        int fd = open(paths[i], O_RDONLY | O_NONBLOCK);
        if (fd >= 0) { fds[n].fd = fd; fds[n].events = POLLIN; ++n; }
    }
    if (n == 0) return 1;

    bool muted = false;
    int volume = 5;

    for (;;) {
        int ret = poll(fds, n, -1);
        if (ret < 0) continue;

        for (int i = 0; i < n; ++i) {
            if (!(fds[i].revents & POLLIN)) continue;
            input_event ev;
            while (read(fds[i].fd, &ev, sizeof(ev)) == sizeof(ev)) {
                if (ev.type != EV_KEY) continue;

                if (ev.code == ACTION_KEY) continue;

                if (ev.value != 1) continue;    // ignore key-up / repeat for other keys
                if (ev.code == KEY_MUTE) {
                    muted = !muted;
                    send_led(muted ? "MUTE 1\n" : "MUTE 0\n");
                } else if (ev.code == KEY_VOLUMEUP || ev.code == KEY_VOLUMEDOWN) {
                    if (ev.code == KEY_VOLUMEUP && volume < 10) ++volume;
                    if (ev.code == KEY_VOLUMEDOWN && volume > 0) --volume;
                    char cmd[32];
                    snprintf(cmd, sizeof(cmd), "VOLUME %d 10\n", volume);
                    send_led(cmd);
                }
            }
        }
    }
}
