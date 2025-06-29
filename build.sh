#!/bin/bash -e

# Build script for PicoCalc Lyra Docker container
# This script builds a Docker image that can compile a custom BuildRoot Linux image
# for the LuckFox Lyra, tailored to run on the ClockworkPi PicoCalc.

# Create output directory for build artifacts
mkdir -p "$(pwd)/output"
mkdir -p "$(pwd)/.ccache"

# Build the Docker image
echo "Building Docker image..."
docker build -t picocalc-lyra-builder .

# Run the Docker container 
echo "Running build container..."

# Run the container with a name so we can copy files out later
CONTAINER_NAME="picocalc-lyra-build-$(date +%s)"

# Pass any arguments to the container entrypoint
if [ $# -gt 0 ]; then
    docker run --name "$CONTAINER_NAME" \
        -v "$(pwd)/.ccache:/home/build/.ccache:Z" \
        picocalc-lyra-builder "$@"
else
    docker run --name "$CONTAINER_NAME" \
        -v "$(pwd)/.ccache:/home/build/.ccache:Z" \
        picocalc-lyra-builder
fi

# Copy the built images from the container to the host
echo "Copying built images from container..."
if docker exec "$CONTAINER_NAME" test -d /opt/Lyra-SDK/rockdev 2>/dev/null; then
    docker cp "$CONTAINER_NAME:/opt/Lyra-SDK/rockdev/." "$(pwd)/output/" 2>/dev/null || echo "No files to copy from rockdev directory"

    echo ""
    echo "Build completed! Built images are available in the ./output directory:"
    ls -la "$(pwd)/output/"
    echo ""
    echo "The main image file is: ./output/update.img"
    echo "Individual components are also available (boot.img, rootfs.img, etc.)"
else
    echo "No rockdev directory found in container - this is normal for partial builds"
fi

# Check if 'clean' argument was provided
if [[ "$*" == *"clean"* ]]; then
    echo "Cleaning up: removing container..."
    docker rm "$CONTAINER_NAME"
else
    echo ""
    echo "The build container ($CONTAINER_NAME) has NOT been deleted. You can re-enter it for incremental builds:"
    echo "  docker start -ai $CONTAINER_NAME"
    echo "Or copy more files out as needed."
    echo ""
    echo "To clean up the container later, run: docker rm $CONTAINER_NAME"
fi