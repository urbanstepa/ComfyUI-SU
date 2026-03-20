# Builds the pre-compiled ComfyUI image locally (requires NVIDIA GPU).
# Run from the repo root: .\build-prebuilt.ps1

$ErrorActionPreference = "Stop"

Write-Host "Building pre-compiled ComfyUI image (GPU required)..."
Write-Host "This will take several minutes on first build."
Write-Host ""

docker build `
    --gpus all `
    -f Dockerfile.prebuilt `
    -t comfyui-3d-prebuilt:latest `
    .

Write-Host ""
Write-Host "Done! Run with:"
Write-Host "  docker compose -f docker-compose-prebuilt.yml up"
