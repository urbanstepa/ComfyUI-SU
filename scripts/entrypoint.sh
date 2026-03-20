#!/bin/bash
set -e

echo "================================================"
echo "  ComfyUI 3D - Starting up"
echo "================================================"

# Print GPU info
nvidia-smi --query-gpu=name,memory.total --format=csv,noheader 2>/dev/null || echo "GPU info unavailable"

# Default args
ARGS="--listen 0.0.0.0 --port 8188"

# Append any extra args from environment
if [ -n "$COMFYUI_ARGS" ]; then
    ARGS="$COMFYUI_ARGS"
fi

# Append any extra args passed to container
if [ $# -gt 0 ]; then
    ARGS="$ARGS $@"
fi

echo "Starting ComfyUI with args: $ARGS"
echo "Models directory: $(ls /models 2>/dev/null | head -5 || echo 'empty or not mounted')"
echo "================================================"

exec python main.py $ARGS
