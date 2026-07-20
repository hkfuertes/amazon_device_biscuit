FROM ubuntu:14.04
# Kernel build environment for Amazon Echo Dot (Biscuit) MT8163B — arm64 Linux 3.18
# Toolchain: aarch64-linux-android-4.9 (cloned from AOSP prebuilts at build time)

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    bc \
    bison \
    build-essential \
    ca-certificates \
    curl \
    flex \
    git \
    kmod \
    libelf-dev \
    libssl-dev \
    make \
    u-boot-tools \
    && rm -rf /var/lib/apt/lists/*

# Pre-bake the AOSP aarch64-linux-android-4.9 toolchain (lollipop-release branch).
# This is what Amazon's build_kernel.sh downloads at runtime; baking it here
# avoids a 500+ MB git clone per build invocation.
# ponytail: depth=1 cuts clone from ~800 MB to ~150 MB
RUN git clone --depth=1 -b lollipop-release \
    https://android.googlesource.com/platform/prebuilts/gcc/linux-x86/aarch64/aarch64-linux-android-4.9 \
    /toolchain/aarch64-linux-android-4.9

# ponytail: mkbootimg NOT baked here — build-boot-img.sh picks it up from:
#   1. CM12 out-docker/host/linux-x86/bin/mkbootimg  (preferred, built by build.sh)
#   2. apt-get install -y abootimg                   (fallback; build-boot-img.sh handles both)

WORKDIR /src
