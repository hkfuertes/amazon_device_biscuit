#define main biscuit_ledd_program_main
#include "../device/amazon/biscuit/biscuit-service/biscuit-ledd.cpp"
#undef main

#include <assert.h>
#include <stdlib.h>

static int component(const std::string& frame, int led, int channel) {
    char hex[3] = {
        frame[led * 6 + channel * 2],
        frame[led * 6 + channel * 2 + 1],
        0,
    };
    return (int)strtol(hex, NULL, 16);
}

static void expect_rgb(const std::string& frame, int led, int red, int green, int blue) {
    assert(component(frame, led, 0) == red);
    assert(component(frame, led, 1) == green);
    assert(component(frame, led, 2) == blue);
}

static int scaled(int value, int percent) {
    return (value * percent + 50) / 100;
}

int main() {
    const int purple[] = { 0xFF, 0x00, 0xFF };

    std::string full = render_countdown_frame(100, 100, 80, 100);
    assert(full.size() == 72);
    for (int i = 0; i < 11; ++i) {
        expect_rgb(full, k_countdown_order[i], scaled(purple[0], 80),
                   scaled(purple[1], 80), scaled(purple[2], 80));
    }
    expect_rgb(full, k_countdown_order[11], purple[0], purple[1], purple[2]);

    std::string half = render_countdown_frame(50, 100, 80, 100);
    for (int i = 0; i < 5; ++i) {
        expect_rgb(half, k_countdown_order[i], scaled(purple[0], 80),
                   scaled(purple[1], 80), scaled(purple[2], 80));
    }
    expect_rgb(half, k_countdown_order[5], purple[0], purple[1], purple[2]);
    for (int i = 6; i < 12; ++i) expect_rgb(half, k_countdown_order[i], 0, 0, 0);

    std::string final_frame = render_countdown_frame(1, 100, 80, 100);
    expect_rgb(final_frame, k_countdown_order[0], purple[0], purple[1], purple[2]);
    for (int i = 1; i < 12; ++i) expect_rgb(final_frame, k_countdown_order[i], 0, 0, 0);

    std::string empty = render_countdown_frame(0, 100, 80, 100);
    assert(empty == std::string(72, '0'));
    return 0;
}
