#!/bin/bash

# If arguments are provided, pass them to the SDK build script
if [ $# -gt 0 ]; then
    echo "Running SDK build.sh with arguments: $@"
    ./build.sh "$@"
    exit $?
fi

# Default: run the initial configuration and full build
# Build the image with the specified configuration
echo "Building image with picocalc_luckfox_lyra_buildroot_sdmmc_defconfig..."
./build.sh picocalc_luckfox_lyra_buildroot_sdmmc_defconfig

# Run the build process
echo "Running the build process..."
./build.sh

# Check if build was successful
if [ $? -eq 0 ]; then
    echo "Build completed successfully!"
else
    echo "Build failed with exit code $?"
    exit 1
fi

