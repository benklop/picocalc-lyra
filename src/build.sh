#!/bin/bash

# Build the image with the specified configuration
echo "Building image with picocalc_luckfox_lyra_buildroot_sdmmc_defconfig..."
./build.sh picocalc_luckfox_lyra_buildroot_sdmmc_defconfig

# Run the build process
echo "Running the build process..."
./build.sh lunch

# Check if build was successful
if [ $? -eq 0 ]; then
    echo "Build completed successfully!"
    
    # List the built images in their original location
    echo "Build artifacts available in rockdev/:"
    ls -la rockdev/
    
    echo "Build completed successfully! Images are available in rockdev/"
else
    echo "Build failed with exit code $?"
    exit 1
fi

