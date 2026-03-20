# Builds the pre-compiled ComfyUI image locally (requires NVIDIA GPU).
# Run from the repo root: .\build-prebuilt.ps1
#
# Uses docker run + commit because docker build does not support --gpus.

$TempContainer = "comfyui-prebuilt-tmp"
$TargetImage   = "comfyui-3d-prebuilt:latest"
$BaseImage     = "ghcr.io/urbanstepa/comfyui-su:latest"

Write-Host "Building pre-compiled ComfyUI image (GPU required)..."
Write-Host "This will take several minutes on first build."
Write-Host ""

# Clean up any leftover temp container from a previous failed run
docker rm $TempContainer 2>$null

$buildScript =
    "set -e && export MAX_JOBS=1" +
    " && echo '>>> Building custom_rasterizer (MAX_JOBS=1 to avoid OOM)...'" +
    " && cd /opt/ComfyUI/custom_nodes/comfyui-hunyuan3dwrapper/hy3dgen/texgen/custom_rasterizer" +
    " && python setup.py install && touch /opt/.custom_rasterizer_built" +
    " && echo '>>> Building voxelize...'" +
    " && cd /opt/ComfyUI/custom_nodes/ComfyUI-Direct3D-S2/voxelize" +
    " && python setup.py install && touch /opt/.voxelize_built" +
    " && echo '>>> Building torchsparse...'" +
    " && rm -rf /tmp/torchsparse" +
    " && git clone https://github.com/urbanstepa/torchsparse.git /tmp/torchsparse" +
    " && cd /tmp/torchsparse && python setup.py install && rm -rf /tmp/torchsparse" +
    " && touch /opt/.torchsparse_built" +
    " && echo '>>> All CUDA extensions built successfully!'"

docker run --gpus all --name $TempContainer $BaseImage /bin/bash -c $buildScript

if ($LASTEXITCODE -ne 0) {
    docker rm $TempContainer 2>$null
    Write-Error "Extension build failed - see output above."
    exit 1
}

Write-Host ""
Write-Host "Committing image as $TargetImage ..."
docker commit $TempContainer $TargetImage
docker rm $TempContainer

Write-Host ""
Write-Host "Done! Run with:"
Write-Host "  docker compose -f docker-compose-prebuilt.yml up"
