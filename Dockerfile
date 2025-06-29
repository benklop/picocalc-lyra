# Use Ubuntu 22.04 as the base image
FROM ubuntu:22.04

# Set environment variables to avoid interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive

# Update and install required dependencies
RUN apt-get update && apt-get install -y git ssh make gcc libssl-dev \
    liblz4-tool expect expect-dev g++ patchelf chrpath gawk texinfo chrpath \
    diffstat binfmt-support qemu-user-static live-build bison flex fakeroot \
    cmake gcc-multilib g++-multilib unzip device-tree-compiler ncurses-dev \
    libgucharmap-2-90-dev bzip2 expat gpgv2 cpp-aarch64-linux-gnu libgmp-dev \
    libmpc-dev bc python-is-python3 python2 rsync curl file ccache util-linux \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Configure the required python2 environment
RUN update-alternatives --install /usr/bin/python python /usr/bin/python2 1 \
    && update-alternatives --install /usr/bin/python python /usr/bin/python3 2 \
    && update-alternatives --set python /usr/bin/python2

RUN mkdir -p /opt/Lyra-SDK

# Copy the build script and make it executable (do this as root before switching users)
COPY ./src/picocalc-build.sh /opt/Lyra-SDK/picocalc-build.sh
RUN chmod +x /opt/Lyra-SDK/picocalc-build.sh

# Create and use a build user
RUN useradd -m build
RUN chown -R build:build /opt/Lyra-SDK

# Set up ccache for faster builds
RUN mkdir -p /home/build/.ccache
RUN chown -R build:build /home/build/.ccache
RUN chmod 755 /home/build/.ccache

# Set resource limits to prevent fork bombs
RUN echo "build soft nproc 65536" >> /etc/security/limits.conf && \
    echo "build hard nproc 65536" >> /etc/security/limits.conf

USER build

# Configure ccache
ENV CCACHE_DIR=/home/build/.ccache
ENV CCACHE_MAXSIZE=2G
ENV CCACHE_SLOPPINESS=pch_defines,time_macros
ENV CCACHE_COMPRESS=true
ENV CCACHE_COMPRESSLEVEL=6
ENV CCACHE_MAXFILES=1000000
ENV PATH="/usr/lib/ccache:$PATH"

# Set conservative parallel build options to avoid resource exhaustion
# Use half of available cores to leave plenty of headroom for nested builds
ENV MAKEFLAGS="-j$(($(nproc) / 2))"
ENV NINJA_STATUS="[%f/%t] "

# Copy and unpack the Luckfox Lyra SDK
WORKDIR /opt/Lyra-SDK
COPY ./Luckfox_Lyra_SDK*.tar.gz /opt/Lyra-SDK/
RUN tar -xzf *.tar.gz && rm Luckfox_Lyra_SDK*.tar.gz


# Set up the environment for the SDK
RUN .repo/repo/repo sync -l
RUN git clone https://github.com/nekocharm/picocalc-luckfox-lyra.git
RUN mkdir buildroot/package/retroarch/libretro-dosboxpure \
    && mkdir kernel-6.1/sound/pwm

# Patch a few things as suggested by https://github.com/cjstoddard/PicoCalc-uf2/blob/main/Luckfox-Lyra/Build%20your%20own%20image.md
RUN cp picocalc-luckfox-lyra/src/device/rockchip/.chips/rk3506/* device/rockchip/.chips/rk3506/

# In the future copy in config and other files from this repo
RUN sed -i 's/BR2_PACKAGE_LIBRETRO_DOSBOXPURE=y/# BR2_PACKAGE_LIBRETRO_DOSBOXPURE=y/g' picocalc-luckfox-lyra/src/buildroot/configs/rockchip_rk3506_picocalc_luckfox_defconfig \
    && sed -i 's/BR2_PACKAGE_RETROARCH=y/# BR2_PACKAGE_RETROARCH=y/g' picocalc-luckfox-lyra/src/buildroot/configs/rockchip_rk3506_picocalc_luckfox_defconfig

# Copy kernel configuration changes from this repo
COPY ./src/picocalc-rk3506-rtc.config /opt/Lyra-SDK/kernel-6.1/arch/arm/configs/picocalc-rk3506-rtc.config
COPY ./src/picocalc-rk3506-rtl8188fu.config /opt/Lyra-SDK/kernel-6.1/arch/arm/configs/picocalc-rk3506-rtl8188fu.config
COPY ./src/picocalc-rk3506g-luckfox-lyra.dts /opt/Lyra-SDK/picocalc-luckfox-lyra/kernel-6.1/arch/arm/boot/dts/picocalc-rk3506g-luckfox-lyra.dts

RUN cd picocalc-luckfox-lyra \
    && ./prepare.sh \
    && cd ..

# Make changes needed for Docker compatibility
RUN sed -i 's/btrfs/btrfs | overlay/' device/rockchip/common/scripts/check-sdk.sh
COPY ./src/picocalc_luckfox_lyra_buildroot_sdmmc_defconfig device/rockchip/.chips/rk3506/picocalc_luckfox_lyra_buildroot_sdmmc_defconfig

# Additions from this repo
RUN echo 'BR2_ROOTFS_PRE_BUILD_SCRIPT="board/rockchip/rk3506/pre-build-picocalc.sh"' >> /opt/Lyra-SDK/buildroot/configs/rockchip_rk3506_picocalc_luckfox_defconfig
COPY ./src/pre-build-picocalc.sh /opt/Lyra-SDK/buildroot/board/rockchip/rk3506/pre-build-picocalc.sh

# Copy BuildRoot optimizations
COPY ./src/buildroot-optimizations.config /opt/Lyra-SDK/buildroot-optimizations.config
COPY ./src/rtl8188fu.patch /opt/Lyra-SDK/rtl8188fu.patch

# Set the build script as the entrypoint
ENTRYPOINT ["/opt/Lyra-SDK/picocalc-build.sh"]