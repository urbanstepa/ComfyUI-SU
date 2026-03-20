#!/bin/bash
# Builds the pre-compiled image locally (requires NVIDIA GPU).
# Run from the repo root: ./build-prebuilt.sh
#
# The resulting image (comfyui-3d-prebuilt:latest) has all CUDA extensions
# already compiled, so container startup is instant.

set -e

echo "Building pre-compiled ComfyUI image (GPU required)..."
echo "This will take several minutes on first build."
echo ""

docker build \
    --gpus all \
    -f Dockerfile.prebuilt \
    -t comfyui-3d-prebuilt:latest \
    .

echo ""
echo "Done! Run with:"
echo "  docker compose -f docker-compose-prebuilt.yml up"
