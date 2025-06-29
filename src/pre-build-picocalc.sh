#!/bin/bash -e

# Get the WiFi drivers
git clone https://github.com/kelebek333/rtl8188fu

cd rtl8188fu
patch -p1 < /opt/Lyra-SDK/rtl8188fu.patch

make

# Copy the WiFi drivers to the buildroot overlay
cd ..
mkdir -p buildroot/board/rockchip/rk3506/picocalc-overlay/usr/lib/firmware/rtlwifi
mkdir -p buildroot/board/rockchip/rk3506/picocalc-overlay/usr/lib/modules/

cp -f rtl8188fu/rtl8188fu.ko buildroot/board/rockchip/rk3506/picocalc-overlay/usr/lib/modules/
cp -f rtl8188fu/firmware/rtl8188fufw.bin buildroot/board/rockchip/rk3506/picocalc-overlay/usr/lib/firmware/rtlwifi/
