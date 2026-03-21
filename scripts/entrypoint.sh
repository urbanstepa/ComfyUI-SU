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
# Check CUDA extensions (compiled at image build time)
# ─────────────────────────────────────────────
for ext in custom_rasterizer voxelize torchsparse; do
    if [ -f "/opt/.${ext}_built" ]; then
        echo ">>> ${ext}: ready"
    else
        echo ">>> WARNING: ${ext} not compiled in this image"
    fi
done

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
