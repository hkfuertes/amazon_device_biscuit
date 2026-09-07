FROM ubuntu:20.04

ENV DEBIAN_FRONTEND=noninteractive \
    USER=builder \
    LC_ALL=C

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
    bison \
    bc \
    build-essential \
    ca-certificates \
    ccache \
    curl \
    flex \
    g++-multilib \
    gcc-multilib \
    git-core \
    gnupg \
    gperf \
    imagemagick \
    lib32ncurses5-dev \
    lib32readline-dev \
    lib32z1-dev \
    libc6-dev-i386 \
    libssl-dev \
    libgl1-mesa-dev \
    libx11-dev \
    libxml2-utils \
    openjdk-8-jdk \
    pngcrush \
    python \
    rsync \
    schedtool \
    unzip \
    x11proto-core-dev \
    xsltproc \
    zip \
    zlib1g-dev \
 && rm -rf /var/lib/apt/lists/*

# Android 7.1 host clang is linked to ncurses ABI 5, absent from Focal.
RUN set -eu; \
    base=https://archive.ubuntu.com/ubuntu/pool/main/n/ncurses; \
    curl -fsSLo /tmp/libtinfo5.deb "$base/libtinfo5_6.1-1ubuntu1.18.04.1_amd64.deb"; \
    curl -fsSLo /tmp/libncurses5.deb "$base/libncurses5_6.1-1ubuntu1.18.04.1_amd64.deb"; \
    printf '%s\n' \
      'f7a59966bba0f997dd1bee0994c43cd563026a81e791cacc6540a2a8c9a49e53  /tmp/libtinfo5.deb' \
      '7374b0d1bf39a7b250dcf18251bba9dbf548d90ddcfa66d31670d73d667abaeb  /tmp/libncurses5.deb' \
      | sha256sum -c -; \
    dpkg -i /tmp/libtinfo5.deb /tmp/libncurses5.deb; \
    rm -f /tmp/libtinfo5.deb /tmp/libncurses5.deb

# ponytail: build-only Jack 4.8 requires TLSv1/TLSv1.1; remove when Jack is retired.
RUN sed -i 's/TLSv1, TLSv1\.1, //' /etc/java-8-openjdk/security/java.security

RUN useradd -m -u 1000 builder
USER builder
WORKDIR /src
