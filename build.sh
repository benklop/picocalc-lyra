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

# Copy build artifacts using our specialized script
echo "Copying build artifacts from container..."
if ./scripts/copy-build-artifacts.sh "$CONTAINER_NAME"; then
    echo ""
    echo "Build completed! Built images are available in the ./output directory:"
    ls -la "$(pwd)/output/"
    echo ""
    if [ -f "$(pwd)/output/update.img" ]; then
        echo "The main image file is: ./output/update.img"
    fi
    echo "Individual components are also available (boot.img, rootfs.img, etc.)"
else
    echo "Failed to copy build artifacts from container"
    echo "You can manually copy them using: ./scripts/copy-build-artifacts.sh $CONTAINER_NAME"
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