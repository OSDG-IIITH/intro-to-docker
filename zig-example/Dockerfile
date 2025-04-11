FROM debian:trixie AS builder

WORKDIR /

ADD https://ziglang.org/download/0.14.0/zig-linux-x86_64-0.14.0.tar.xz ./zig.tar.xz

RUN apt-get update && apt-get install -y xz-utils

RUN tar -xvJf zig.tar.xz

RUN mv ./zig-* ./zig

ENV PATH="$PATH:/zig"

WORKDIR /app

RUN apt-get update && apt-get install -y --no-install-recommends \
    libasound2-dev \
    libx11-dev \
    libxrandr-dev \
    libxi-dev \
    libgl1-mesa-dev \
    libglu1-mesa-dev \
    libxcursor-dev \
    libxinerama-dev \
    libwayland-dev \
    libxkbcommon-dev \
    wayland-protocols \
 && rm -rf /var/lib/apt/lists/*

COPY ./raylib raylib/

RUN cd raylib && zig build install -Dlinux_display_backend=Wayland

COPY . .

RUN zig build

ENTRYPOINT [ "./zig-out/bin/zigeg" ]

