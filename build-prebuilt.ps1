# Builds the pre-compiled ComfyUI image locally (requires NVIDIA GPU).
# Run from the repo root: .\build-prebuilt.ps1
#
# Uses docker run + commit because docker build does not support --gpus.
# Each extension is built in a separate container to avoid OOM.
#
# Flags:
#   -Resume    Resume from last successful step (uses existing latest image)
#
# Tagging: each step gets its own tag (e.g. 20260320-1730.1, .2, .3)
# and "latest" always points to the most recent step. To rollback:
#   docker compose -f docker-compose-prebuilt.yml up  (uses latest)
#   # or edit the image tag in docker-compose-prebuilt.yml to a specific version

param(
    [switch]$Resume
)

$TempContainer = "comfyui-prebuilt-tmp"
$LocalImage    = "comfyui-3d-prebuilt"
$Registry      = "ghcr.io/urbanstepa/comfyui-3d-prebuilt"
$BaseImage     = "ghcr.io/urbanstepa/comfyui-su:latest"
$BuildBase     = Get-Date -Format "yyyyMMdd-HHmm"
$StepNum       = 0

# Pull base image (also verifies registry access)
Write-Host "Pulling base image $BaseImage ..."
docker pull $BaseImage
if ($LASTEXITCODE -ne 0) {
    Write-Error "Cannot pull base image. Make sure you are logged in:"
    Write-Host "  echo YOUR_PAT | docker login ghcr.io -u urbanstepa --password-stdin"
    exit 1
}
Write-Host ""

# Check which stamps already exist in the resume image
$builtStamps = @()
if ($Resume) {
    Write-Host "Resuming from ${LocalImage}:latest ..."
    # Check which stamps exist in the current latest image
    $stamps = docker run --rm --entrypoint /bin/bash "${LocalImage}:latest" -c "ls /opt/.custom_rasterizer_built /opt/.voxelize_built /opt/.torchsparse_built 2>/dev/null" 2>$null
    if ($stamps) { $builtStamps = $stamps -split "`n" }
    # Re-tag latest with new build tag so steps chain correctly
    docker tag "${LocalImage}:latest" "${LocalImage}:${BuildBase}.0"
    Write-Host "Already built: $($builtStamps -join ', ')"
    Write-Host ""
}

Write-Host "Building pre-compiled ComfyUI image (GPU required)..."
Write-Host "Each extension is built separately to avoid OOM."
Write-Host "Build base: $BuildBase"
Write-Host ""

# Helper: run a build step, commit the image, clean up
function Build-Step {
    param([string]$StepName, [string]$StampFile, [string]$FromImage, [string]$Script)

    # Skip if already built (resume mode)
    if ($builtStamps -contains $StampFile) {
        Write-Host "=== $StepName already built, skipping ==="
        return
    }

    $script:StepNum++
    $stepTag = "${BuildBase}.${script:StepNum}"

    Write-Host ""
    Write-Host "=== $StepName (tag: $stepTag) ==="

    # Clean up any leftover container
    docker rm $TempContainer 2>$null | Out-Null

    # Append manifest entry after building
    $manifestLine = "${StepName} | tag ${stepTag}"
    $fullScript = $Script + " && echo '${manifestLine}' >> /opt/.prebuilt-manifest"

    docker run --gpus all --entrypoint /bin/bash --name $TempContainer $FromImage -c $fullScript

    if ($LASTEXITCODE -ne 0) {
        docker rm $TempContainer 2>$null | Out-Null
        Write-Error "$StepName failed - see output above."
        Write-Host ""
        Write-Host "To retry this step, run: .\build-prebuilt.ps1 -Resume"
        exit 1
    }

    # Commit as intermediate image, clean up container
    docker commit $TempContainer "${LocalImage}:${stepTag}"
    docker rm $TempContainer | Out-Null

    # Push with unique step tag + update latest
    docker tag "${LocalImage}:${stepTag}" "${Registry}:${stepTag}"
    docker tag "${LocalImage}:${stepTag}" "${Registry}:latest"
    docker tag "${LocalImage}:${stepTag}" "${LocalImage}:latest"
    Write-Host ">>> Pushing ${StepName} to registry..."
    docker push "${Registry}:${stepTag}"
    docker push "${Registry}:latest"

    # Show what's in the image now
    Write-Host ""
    Write-Host ">>> Pushed ${Registry}:${stepTag}"
    Write-Host ">>> Manifest:"
    docker run --rm --entrypoint /bin/cat "${LocalImage}:${stepTag}" /opt/.prebuilt-manifest
    Write-Host ""

    Write-Host "=== $StepName done ==="
}

# Step 1: custom_rasterizer (from base image)
Build-Step "custom_rasterizer" "/opt/.custom_rasterizer_built" $BaseImage (
    "set -e && export MAX_JOBS=1" +
    " && cd /opt/ComfyUI/custom_nodes/comfyui-hunyuan3dwrapper/hy3dgen/texgen/custom_rasterizer" +
    " && python setup.py install" +
    " && touch /opt/.custom_rasterizer_built"
)

# Step 2: voxelize (builds on top of step 1)
Build-Step "voxelize" "/opt/.voxelize_built" "${LocalImage}:latest" (
    "set -e && export MAX_JOBS=1" +
    " && cd /opt/ComfyUI/custom_nodes/ComfyUI-Direct3D-S2/voxelize" +
    " && python setup.py install" +
    " && touch /opt/.voxelize_built"
)

# Step 3: torchsparse (builds on top of step 2)
Build-Step "torchsparse" "/opt/.torchsparse_built" "${LocalImage}:latest" (
    "set -e && export MAX_JOBS=1" +
    " && rm -rf /tmp/torchsparse" +
    " && git clone https://github.com/urbanstepa/torchsparse.git /tmp/torchsparse" +
    " && cd /tmp/torchsparse && python setup.py install" +
    " && rm -rf /tmp/torchsparse" +
    " && touch /opt/.torchsparse_built"
)

Write-Host ""
Write-Host "All CUDA extensions built successfully!"
Write-Host ""
Write-Host "Done!"
Write-Host "  Latest: ${Registry}:latest"
Write-Host ""
Write-Host "Run with:"
Write-Host "  docker compose -f docker-compose-prebuilt.yml up"
Write-Host ""
Write-Host "To rollback, edit docker-compose-prebuilt.yml image tag to a previous version."
Write-Host "List available versions: docker images $LocalImage --format '{{.Tag}}'"
