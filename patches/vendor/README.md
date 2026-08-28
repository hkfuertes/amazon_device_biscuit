# Biscuit vendor patch series

Applied after stock extraction to `vendor/amazon/mt8163-common/proprietary/`, never to tracked blobs.

- `10-force-software-egl.patch` keeps Biscuit on the headless software EGL path.
- `20-microphone-pga-70.patch` changes only `A_PGA_L` and `A_PGA_R` from stock 40 (20 dB) to 70 (35 dB); `A_PGA_R_LINEIN` remains stock.

A patch mismatch is a stock-baseline mismatch and must fail extraction. Update a patch only with a reviewed stock input change.
