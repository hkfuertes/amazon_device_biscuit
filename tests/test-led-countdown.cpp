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
    const int mint[] = { 0x6F, 0xD3, 0xB5 };
    const int ivory[] = { 0xF4, 0xE2, 0xB6 };
    const int coral[] = { 0xF0, 0x8A, 0x82 };

    std::string full = render_countdown_frame(100, 100, 80, 100);
    assert(full.size() == 72);
    for (int i = 0; i < 11; ++i) {
        expect_rgb(full, k_countdown_order[i], scaled(mint[0], 80),
                   scaled(mint[1], 80), scaled(mint[2], 80));
    }
    expect_rgb(full, k_countdown_order[11], mint[0], mint[1], mint[2]);

    Rgb at_twenty = countdown_color(20, 100);
    assert(at_twenty.red == ivory[0] && at_twenty.green == ivory[1] && at_twenty.blue == ivory[2]);
    Rgb below_twenty = countdown_color(19, 100);
    assert(below_twenty.red == coral[0] && below_twenty.green == coral[1] && below_twenty.blue == coral[2]);

    std::string half = render_countdown_frame(50, 100, 80, 100);
    for (int i = 0; i < 5; ++i) {
        expect_rgb(half, k_countdown_order[i], scaled(ivory[0], 80),
                   scaled(ivory[1], 80), scaled(ivory[2], 80));
    }
    expect_rgb(half, k_countdown_order[5], ivory[0], ivory[1], ivory[2]);
    for (int i = 6; i < 12; ++i) expect_rgb(half, k_countdown_order[i], 0, 0, 0);

    std::string final_frame = render_countdown_frame(1, 100, 80, 100);
    expect_rgb(final_frame, k_countdown_order[0], coral[0], coral[1], coral[2]);
    for (int i = 1; i < 12; ++i) expect_rgb(final_frame, k_countdown_order[i], 0, 0, 0);

    std::string empty = render_countdown_frame(0, 100, 80, 100);
    assert(empty == std::string(72, '0'));
    return 0;
}
