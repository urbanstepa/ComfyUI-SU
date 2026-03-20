#!/bin/bash
set -e

echo "================================================"
echo "  ComfyUI 3D - Starting up"
echo "================================================"

# Print GPU info
nvidia-smi --query-gpu=name,memory.total --format=csv,noheader 2>/dev/null || echo "GPU info unavailable"

# Show prebuilt manifest if present
if [ -f /opt/.prebuilt-manifest ]; then
    echo "Prebuilt extensions:"
    sed 's/^/  /' /opt/.prebuilt-manifest
fi

# ─────────────────────────────────────────────
# Build CUDA extensions on first run
# Uses setup.py directly to avoid pip's isolated build env
# which doesn't have access to the system torch
# ─────────────────────────────────────────────
export MAX_JOBS="${MAX_JOBS:-1}"   # Limit parallel compilations to avoid OOM

RASTERIZER_STAMP="/opt/.custom_rasterizer_built"
if [ ! -f "$RASTERIZER_STAMP" ]; then
    echo ">>> First run: building custom_rasterizer..."
    cd /opt/ComfyUI/custom_nodes/comfyui-hunyuan3dwrapper/hy3dgen/texgen/custom_rasterizer
    python setup.py install && touch "$RASTERIZER_STAMP" && echo ">>> custom_rasterizer built successfully" \
        || echo ">>> custom_rasterizer build failed - texture generation will be unavailable"
    cd /opt/ComfyUI
else
    echo ">>> custom_rasterizer already built, skipping"
fi

VOXELIZE_STAMP="/opt/.voxelize_built"
if [ ! -f "$VOXELIZE_STAMP" ]; then
    echo ">>> First run: building voxelize..."
    cd /opt/ComfyUI/custom_nodes/ComfyUI-Direct3D-S2/voxelize
    python setup.py install && touch "$VOXELIZE_STAMP" && echo ">>> voxelize built successfully" \
        || echo ">>> voxelize build failed - Direct3D-S2 voxelization will be unavailable"
    cd /opt/ComfyUI
else
    echo ">>> voxelize already built, skipping"
fi

TORCHSPARSE_STAMP="/opt/.torchsparse_built"
if [ ! -f "$TORCHSPARSE_STAMP" ]; then
    echo ">>> First run: building torchsparse..."
    rm -rf /tmp/torchsparse
    git clone https://github.com/urbanstepa/torchsparse.git /tmp/torchsparse
    cd /tmp/torchsparse
    python setup.py install && touch "$TORCHSPARSE_STAMP" && echo ">>> torchsparse built successfully" \
        || echo ">>> torchsparse build failed - Direct3D-S2 will be unavailable"
    rm -rf /tmp/torchsparse
    cd /opt/ComfyUI
else
    echo ">>> torchsparse already built, skipping"
fi

# ─────────────────────────────────────────────
# Start ComfyUI
# ─────────────────────────────────────────────
ARGS="--listen 0.0.0.0 --port 8188"
if [ -n "$COMFYUI_ARGS" ]; then
    ARGS="$COMFYUI_ARGS"
fi
if [ $# -gt 0 ]; then
    ARGS="$ARGS $@"
fi

echo "Starting ComfyUI with args: $ARGS"
echo "================================================"

exec python main.py $ARGS
