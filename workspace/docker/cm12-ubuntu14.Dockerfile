FROM ubuntu:14.04

ENV DEBIAN_FRONTEND=noninteractive \
    USER=builder \
    LC_ALL=C

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
    bison \
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
    lib32ncurses5-dev \
    lib32readline-gplv2-dev \
    lib32z1-dev \
    libc6-dev-i386 \
    libgl1-mesa-dev \
    libx11-dev \
    libxml2-utils \
    openjdk-7-jdk \
    pngcrush \
    python \
    schedtool \
    unzip \
    x11proto-core-dev \
    xsltproc \
    zip \
    zlib1g-dev \
 && rm -rf /var/lib/apt/lists/*

RUN useradd -m -u 1000 builder
USER builder
WORKDIR /src
