#!/bin/bash
# Builds the pre-compiled ComfyUI image locally (requires NVIDIA GPU).
# Run from the repo root: ./build-prebuilt.sh
#
# Uses docker run + commit because docker build does not support --gpus.
# Each extension is built in a separate container to avoid OOM.
# Each step gets its own tag (e.g. 20260320-1730.1, .2, .3).
#
# Flags:
#   --resume   Resume from last successful step (uses existing latest image)

set -e

TEMP_CONTAINER="comfyui-prebuilt-tmp"
LOCAL_IMAGE="comfyui-3d-prebuilt"
REGISTRY="ghcr.io/urbanstepa/comfyui-3d-prebuilt"
BASE_IMAGE="ghcr.io/urbanstepa/comfyui-su:latest"
BUILD_BASE="$(date +%Y%m%d-%H%M)"
STEP_NUM=0
RESUME=false

if [ "$1" = "--resume" ]; then
    RESUME=true
fi

# Pull base image (also verifies registry access)
echo "Pulling base image $BASE_IMAGE ..."
if ! docker pull "$BASE_IMAGE"; then
    echo "ERROR: Cannot pull base image. Make sure you are logged in:"
    echo "  echo YOUR_PAT | docker login ghcr.io -u urbanstepa --password-stdin"
    exit 1
fi
echo ""

# Check which stamps already exist in the resume image
BUILT_STAMPS=""
if [ "$RESUME" = true ]; then
    echo "Resuming from ${LOCAL_IMAGE}:latest ..."
    BUILT_STAMPS=$(docker run --rm --entrypoint /bin/bash "${LOCAL_IMAGE}:latest" -c \
        "ls /opt/.custom_rasterizer_built /opt/.voxelize_built /opt/.torchsparse_built /opt/.comfyui_essentials_built /opt/.comfyui_hunyuan3d21_built 2>/dev/null" 2>/dev/null || true)
    docker tag "${LOCAL_IMAGE}:latest" "${LOCAL_IMAGE}:${BUILD_BASE}.0"
    echo "Already built: $BUILT_STAMPS"
    echo ""
fi

echo "Building pre-compiled ComfyUI image (GPU required)..."
echo "Each extension is built separately to avoid OOM."
echo "Build base: $BUILD_BASE"
echo ""

build_step() {
    local step_name="$1"
    local stamp_file="$2"
    local from_image="$3"
    local script="$4"

    # Skip if already built (resume mode)
    if echo "$BUILT_STAMPS" | grep -q "$stamp_file"; then
        echo "=== $step_name already built, skipping ==="
        return
    fi

    STEP_NUM=$((STEP_NUM + 1))
    local step_tag="${BUILD_BASE}.${STEP_NUM}"

    echo ""
    echo "=== $step_name (tag: $step_tag) ==="

    docker rm "$TEMP_CONTAINER" 2>/dev/null || true

    # Append manifest entry after building
    local full_script="$script && echo '$step_name | tag $step_tag' >> /opt/.prebuilt-manifest"

    docker run --gpus all --entrypoint /bin/bash --name "$TEMP_CONTAINER" "$from_image" -c "$full_script"

    # Restore original entrypoint and clear CMD
    # (docker run --entrypoint overrides both, and docker commit preserves them)
    docker commit --change='ENTRYPOINT ["/entrypoint.sh"]' --change='CMD []' "$TEMP_CONTAINER" "$LOCAL_IMAGE:$step_tag"
    docker rm "$TEMP_CONTAINER"

    # Push with unique step tag + update latest
    docker tag "$LOCAL_IMAGE:$step_tag" "$REGISTRY:$step_tag"
    docker tag "$LOCAL_IMAGE:$step_tag" "$REGISTRY:latest"
    docker tag "$LOCAL_IMAGE:$step_tag" "$LOCAL_IMAGE:latest"
    echo ">>> Pushing $step_name to registry..."
    docker push "$REGISTRY:$step_tag"
    docker push "$REGISTRY:latest"

    # Show what's in the image now
    echo ""
    echo ">>> Pushed $REGISTRY:$step_tag"
    echo ">>> Manifest:"
    docker run --rm --entrypoint /bin/cat "$LOCAL_IMAGE:$step_tag" /opt/.prebuilt-manifest
    echo ""

    echo "=== $step_name done ==="
}

# Step 1: custom_rasterizer (from base image)
build_step "custom_rasterizer" "/opt/.custom_rasterizer_built" "$BASE_IMAGE" \
    "set -e && export MAX_JOBS=1 \
    && cd /opt/ComfyUI/custom_nodes/comfyui-hunyuan3dwrapper/hy3dgen/texgen/custom_rasterizer \
    && python setup.py install \
    && touch /opt/.custom_rasterizer_built"

# Step 2: voxelize (builds on top of step 1)
build_step "voxelize" "/opt/.voxelize_built" "$LOCAL_IMAGE:latest" \
    "set -e && export MAX_JOBS=1 \
    && cd /opt/ComfyUI/custom_nodes/ComfyUI-Direct3D-S2/voxelize \
    && python setup.py install \
    && touch /opt/.voxelize_built"

# Step 3: torchsparse (builds on top of step 2)
build_step "torchsparse" "/opt/.torchsparse_built" "$LOCAL_IMAGE:latest" \
    "set -e && export MAX_JOBS=1 \
    && rm -rf /tmp/torchsparse \
    && git clone https://github.com/urbanstepa/torchsparse.git /tmp/torchsparse \
    && cd /tmp/torchsparse && python setup.py install \
    && rm -rf /tmp/torchsparse \
    && touch /opt/.torchsparse_built"

# Step 4: ComfyUI_essentials — custom nodes (no GPU needed)
build_step "comfyui_essentials" "/opt/.comfyui_essentials_built" "$LOCAL_IMAGE:latest" \
    "set -e \
    && apt-get update && apt-get install -y libopengl0 && rm -rf /var/lib/apt/lists/* \
    && git clone https://github.com/urbanstepa/ComfyUI_essentials.git /opt/ComfyUI/custom_nodes/ComfyUI_essentials \
    && cd /opt/ComfyUI/custom_nodes/ComfyUI_essentials && pip install -r requirements.txt \
    && touch /opt/.comfyui_essentials_built"

# Step 5: ComfyUI-Hunyuan3d-2-1 — Hunyuan3D v2.1 nodes (no GPU needed)
build_step "comfyui_hunyuan3d21" "/opt/.comfyui_hunyuan3d21_built" "$LOCAL_IMAGE:latest" \
    "set -e \
    && git clone https://github.com/visualbruno/ComfyUI-Hunyuan3d-2-1.git /opt/ComfyUI/custom_nodes/ComfyUI-Hunyuan3d-2-1 \
    && cd /opt/ComfyUI/custom_nodes/ComfyUI-Hunyuan3d-2-1 && pip install -r requirements.txt \
    && touch /opt/.comfyui_hunyuan3d21_built"

echo ""
echo "All extensions built successfully!"
echo ""
echo "Done!"
echo "  Latest: $REGISTRY:latest"
echo ""
echo "Run with:"
echo "  docker compose -f docker-compose-prebuilt.yml up"
echo ""
echo "To rollback, edit docker-compose-prebuilt.yml image tag to a previous version."
echo "List available versions: docker images $LOCAL_IMAGE --format '{{.Tag}}'"
