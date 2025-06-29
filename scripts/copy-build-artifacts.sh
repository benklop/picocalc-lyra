#!/bin/bash -e

# Script to manually copy build artifacts from Docker container and dereference symlinks
# 
# This script is necessary because:
# 1. Podman doesn't support the `docker cp -L` flag to dereference symlinks
# 2. Build artifacts (like update.img, boot.img, etc.) are often symlinks to versioned files
# 3. We need the actual files, not the symlinks, for the build artifacts to be usable
# 4. The container has already stopped by the time we want to copy files out
#
# The script works by:
# 1. Copying all files (including symlinks) from the container
# 2. Finding symlinks in the copied files 
# 3. Reading each symlink target and copying the actual target file from the container
# 4. Replacing the symlink with the real file
#
# Usage: ./copy-build-artifacts.sh <container_name> [source_path] [dest_path]

CONTAINER_NAME="${1:-picocalc-lyra-build-1751167066}"
SOURCE_PATH="${2:-/opt/Lyra-SDK/output/firmware}"
DEST_PATH="${3:-$(pwd)/output}"

echo "Copying build artifacts from container: $CONTAINER_NAME"
echo "Source path: $SOURCE_PATH"
echo "Destination path: $DEST_PATH"

# Create destination directory
mkdir -p "$DEST_PATH"

# First, copy everything as-is (including symlinks)
echo "Step 1: Copying all files (including symlinks)..."
if ! docker cp "$CONTAINER_NAME:$SOURCE_PATH/." "$DEST_PATH/" 2>/dev/null; then
    echo "Failed to copy files from $SOURCE_PATH"
    echo "This could mean the directory doesn't exist or the container is not accessible"
    exit 1
fi

# Now find all symlinks and dereference them
echo "Step 2: Finding and dereferencing symlinks..."
find "$DEST_PATH" -type l | while read -r symlink; do
    echo "Processing symlink: $symlink"
    
    # Get the relative path from the destination
    rel_path="${symlink#$DEST_PATH/}"
    
    # Read the symlink target directly from the copied symlink
    target=$(readlink "$symlink" 2>/dev/null || echo "")
    
    if [ -n "$target" ]; then
        echo "  Symlink target: $target"
        
        # If target is relative, make it relative to the source directory
        if [[ "$target" != /* ]]; then
            # Get the directory of the symlink
            symlink_dir=$(dirname "$SOURCE_PATH/$rel_path")
            full_target="$symlink_dir/$target"
        else
            full_target="$target"
        fi
        
        # Normalize the path to resolve any .. directory traversals
        # Use Python to properly resolve the path since it handles .. correctly
        normalized_target=$(python3 -c "import os.path; print(os.path.normpath('$full_target'))" 2>/dev/null || echo "$full_target")
        
        echo "  Full target path: $full_target"
        echo "  Normalized path: $normalized_target"
        
        # Remove the symlink and try to copy the actual file
        rm "$symlink"
        
        echo "  Copying actual file..."
        if docker cp "$CONTAINER_NAME:$normalized_target" "$symlink" 2>/dev/null; then
            echo "  Successfully copied $normalized_target"
        else
            echo "  Warning: Failed to copy $normalized_target (file may not exist or be accessible)"
            # Restore the symlink if copy failed
            ln -s "$target" "$symlink" 2>/dev/null || echo "  Could not restore symlink"
        fi
    else
        echo "  Warning: Could not read symlink target"
    fi
done

echo ""
echo "Copy completed! Files are now available in: $DEST_PATH"
echo "Listing copied files:"
ls -la "$DEST_PATH"
