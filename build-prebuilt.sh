#!/bin/bash
# Builds the pre-compiled ComfyUI image locally (requires NVIDIA GPU).
# Run from the repo root: ./build-prebuilt.sh
#
# Uses docker run + commit because docker build does not support --gpus.

set -e

TEMP_CONTAINER="comfyui-prebuilt-tmp"
TARGET_IMAGE="comfyui-3d-prebuilt:latest"
BASE_IMAGE="ghcr.io/urbanstepa/comfyui-su:latest"

echo "Building pre-compiled ComfyUI image (GPU required)..."
echo "This will take several minutes on first build."
echo ""

# Clean up any leftover temp container from a previous failed run
docker rm "$TEMP_CONTAINER" 2>/dev/null || true

docker run --gpus all --name "$TEMP_CONTAINER" "$BASE_IMAGE" /bin/bash -c "
    set -e
    echo '>>> Building custom_rasterizer...'
    cd /opt/ComfyUI/custom_nodes/comfyui-hunyuan3dwrapper/hy3dgen/texgen/custom_rasterizer
    python setup.py install && touch /opt/.custom_rasterizer_built

    echo '>>> Building voxelize...'
    cd /opt/ComfyUI/custom_nodes/ComfyUI-Direct3D-S2/voxelize
    python setup.py install && touch /opt/.voxelize_built

    echo '>>> Building torchsparse...'
    git clone https://github.com/urbanstepa/torchsparse.git /tmp/torchsparse
    cd /tmp/torchsparse && python setup.py install && rm -rf /tmp/torchsparse
    touch /opt/.torchsparse_built

    echo '>>> All CUDA extensions built successfully!'
"

echo ""
echo "Committing image as $TARGET_IMAGE ..."
docker commit "$TEMP_CONTAINER" "$TARGET_IMAGE"
docker rm "$TEMP_CONTAINER"

echo ""
echo "Done! Run with:"
echo "  docker compose -f docker-compose-prebuilt.yml up"
