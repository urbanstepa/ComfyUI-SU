#!/bin/bash
set -e

echo "================================================"
echo "  ComfyUI 3D - Starting up"
echo "================================================"

# Print GPU info
nvidia-smi --query-gpu=name,memory.total --format=csv,noheader 2>/dev/null || echo "GPU info unavailable"

# ─────────────────────────────────────────────
# Build CUDA extensions on first run
# ─────────────────────────────────────────────
RASTERIZER_STAMP="/opt/.custom_rasterizer_built"
if [ ! -f "$RASTERIZER_STAMP" ]; then
    echo ">>> First run: building custom_rasterizer..."
    cd /opt/ComfyUI/custom_nodes/comfyui-hunyuan3dwrapper/hy3dgen/texgen/custom_rasterizer
    pip install . && touch "$RASTERIZER_STAMP" && echo ">>> custom_rasterizer built successfully"
    cd /opt/ComfyUI
else
    echo ">>> custom_rasterizer already built, skipping"
fi

VOXELIZE_STAMP="/opt/.voxelize_built"
if [ ! -f "$VOXELIZE_STAMP" ]; then
    echo ">>> First run: building voxelize..."
    cd /opt/ComfyUI/custom_nodes/ComfyUI-Direct3D-S2/voxelize
    pip install . && touch "$VOXELIZE_STAMP" && echo ">>> voxelize built successfully"
    cd /opt/ComfyUI
else
    echo ">>> voxelize already built, skipping"
fi

TORCHSPARSE_STAMP="/opt/.torchsparse_built"
if [ ! -f "$TORCHSPARSE_STAMP" ]; then
    echo ">>> First run: building torchsparse..."
    git clone https://github.com/urbanstepa/torchsparse.git /tmp/torchsparse
    cd /tmp/torchsparse
    pip install . && touch "$TORCHSPARSE_STAMP" && echo ">>> torchsparse built successfully"
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
