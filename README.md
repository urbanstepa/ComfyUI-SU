# ComfyUI 3D Docker

A Docker image for running ComfyUI with 3D generation support on Windows via Docker Desktop.

**Includes:**
- ComfyUI (latest)
- ComfyUI Manager
- comfyui-hunyuan3dwrapper (Hunyuan3D 2.x — 3D mesh + texture generation)
- ComfyUI-Direct3D-S2 (Direct3D sparse 3D generation)

**Stack:**
- CUDA 13.0
- Python 3.12
- PyTorch 2.10.0+cu130
- Ubuntu 22.04

---

## Prerequisites

1. **Docker Desktop** — https://www.docker.com/products/docker-desktop/
   - Enable WSL2 backend (Settings → General → Use WSL2)
   - Enable GPU support (Settings → Resources → WSL Integration)

2. **NVIDIA Container Toolkit** — install via WSL2:
   ```bash
   wsl
   distribution=$(. /etc/os-release;echo $ID$VERSION_ID)
   curl -s -L https://nvidia.github.io/nvidia-docker/gpgkey | sudo apt-key add -
   curl -s -L https://nvidia.github.io/nvidia-docker/$distribution/nvidia-docker.list | sudo tee /etc/apt/sources.list.d/nvidia-docker.list
   sudo apt-get update && sudo apt-get install -y nvidia-container-toolkit
   sudo systemctl restart docker
   ```

3. **Models** — your existing ComfyUI models on your Windows host (e.g. `D:\ComfyUI_installed_2\models`)

4. **WSL2 Memory Configuration** — by default WSL2 only uses 50% of system RAM. For ComfyUI with large models, create/edit `C:\Users\<you>\.wslconfig`:
   ```ini
   [wsl2]
   memory=24GB
   swap=16GB
   ```
   Then restart WSL: `wsl --shutdown` and restart Docker Desktop.

---

## Quick Start (Prebuilt Image — Recommended)

The prebuilt image has all CUDA extensions (custom_rasterizer, voxelize, torchsparse) **already compiled**, so containers start in seconds instead of waiting 1-2 hours for compilation.

### 1. Clone this repo
```powershell
git clone https://github.com/urbanstepa/comfyui-3d-docker.git
cd comfyui-3d-docker
```

### 2. Login to GitHub Container Registry
```powershell
echo YOUR_GITHUB_PAT | docker login ghcr.io -u YOUR_USERNAME --password-stdin
```
Your PAT needs `read:packages` scope. Create one at https://github.com/settings/tokens.

### 3. Edit docker-compose-prebuilt.yml — set your paths
Update volume paths to match your Windows setup:
```yaml
volumes:
  - "D:/ComfyUI_installed_2/models:/models"
  - "D:/ComfyUI_installed_2/output:/opt/ComfyUI/output"
  - "D:/ComfyUI_installed_2/input:/opt/ComfyUI/input"
  - "D:/ComfyUI_installed_2/user:/opt/ComfyUI/user"
```
Note: Docker Desktop uses forward slashes even on Windows.

### 4. Run
```powershell
docker compose -f docker-compose-prebuilt.yml up
```

ComfyUI will be available at: **http://localhost:8188**

---

## Quick Start (Build From Source)

If you prefer to build everything yourself instead of using the prebuilt image:

### 1. Edit docker-compose.yml — set your models path
```yaml
volumes:
  - "D:/ComfyUI_installed_2/models:/models"
```

### 2. Build the image
```powershell
docker compose build
```
This will take **20-40 minutes** on first build. CUDA extensions are compiled on first container startup (additional 1-2 hours).

### 3. Run
```powershell
docker compose up
```

---

## Multi-Drive Model Storage

If your models are spread across multiple drives, mount each location as a subfolder:

```yaml
volumes:
  - "D:/ComfyUI_installed_2/models:/models"
  - "E:/Models/diffusion_models:/models/diffusion_models/external"
  - "E:/Models/text_encoders:/models/text_encoders/external"
```

Models in `E:/Models/diffusion_models/` will appear under `diffusion_models/external/` in ComfyUI.

> **Note:** Windows NTFS symlinks that point across drives do **not** work through Docker bind mounts. Use separate volume mounts instead.

---

## Building the Prebuilt Image

The prebuilt image is created using `docker run` + `docker commit` (because `docker build` does not support `--gpus`). Each CUDA extension is built in a separate container to avoid OOM.

### Windows (PowerShell)
```powershell
# First build
.\build-prebuilt.ps1

# Resume from last successful step (if a step failed)
.\build-prebuilt.ps1 -Resume
```

### Linux / macOS / WSL
```bash
# First build
./build-prebuilt.sh

# Resume from last successful step
./build-prebuilt.sh --resume
```

### How it works

1. Pulls the base image from `ghcr.io/urbanstepa/comfyui-su:latest`
2. Builds each extension in a separate container with `MAX_JOBS=1` to prevent OOM:
   - **Step 1:** custom_rasterizer (Hunyuan3D texture generation)
   - **Step 2:** voxelize (Direct3D-S2 voxelization)
   - **Step 3:** torchsparse (sparse tensor operations)
3. After each step, commits the container as a new image and pushes to GitHub Container Registry
4. Each step gets a unique version tag (e.g. `20260321-1200.1`, `.2`, `.3`)
5. `latest` always points to the most recent successful step

### Versioning and Rollback

Each build step is tagged with a timestamp-based version:
```
ghcr.io/urbanstepa/comfyui-3d-prebuilt:20260321-1200.1  (custom_rasterizer)
ghcr.io/urbanstepa/comfyui-3d-prebuilt:20260321-1200.2  (+ voxelize)
ghcr.io/urbanstepa/comfyui-3d-prebuilt:20260321-1200.3  (+ torchsparse)
ghcr.io/urbanstepa/comfyui-3d-prebuilt:latest            (= most recent)
```

To rollback, change the image tag in `docker-compose-prebuilt.yml`:
```yaml
image: ghcr.io/urbanstepa/comfyui-3d-prebuilt:20260321-1200.2
```

List available local versions:
```powershell
docker images comfyui-3d-prebuilt --format "{{.Tag}}"
```

### Build Manifest

Each prebuilt image contains a manifest at `/opt/.prebuilt-manifest` recording what was built and when. View it with:
```powershell
docker run --rm --entrypoint /bin/cat ghcr.io/urbanstepa/comfyui-3d-prebuilt:latest /opt/.prebuilt-manifest
```

---

## Configuration

### Custom launch arguments
Set `COMFYUI_ARGS` in your compose file:
```yaml
environment:
  - COMFYUI_ARGS=--listen 0.0.0.0 --port 8188 --highvram
```

Useful flags:
| Flag | Description |
|------|-------------|
| `--highvram` | Keep models in VRAM (RTX 3090 recommended) |
| `--lowvram` | Aggressive offloading for GPUs < 8GB |
| `--force-fp32` | Force 32-bit precision (debugging) |
| `--force-fp16` | Force 16-bit precision |
| `--cpu` | CPU-only mode (slow) |

### Adding more custom nodes
Add install steps to the Dockerfile after the existing custom node sections:
```dockerfile
RUN git clone https://github.com/author/MyNode.git ${CUSTOM_NODES_PATH}/MyNode && \
    cd ${CUSTOM_NODES_PATH}/MyNode && \
    pip install -r requirements.txt
```

Then rebuild:
```powershell
docker compose build --no-cache
```

---

## Models

Models are mounted from your host at runtime — they are **not** baked into the image. This keeps the image size small and lets you manage models from Windows as usual.

The container expects this directory structure at `/models`:
```
/models/
├── checkpoints/
├── clip/
├── clip_vision/
├── controlnet/
├── diffusion_models/
├── loras/
├── text_encoders/
├── unet/
│   └── hunyuan3d-dit-v2-0-fp16.safetensors
└── vae/
```

### Hunyuan3D models
Download from HuggingFace and place in your Windows models directory:
```powershell
huggingface-cli download tencent/Hunyuan3D-2 --local-dir D:\ComfyUI_installed_2\models\unet\
```

---

## Troubleshooting

### GPU not detected
```powershell
# Test NVIDIA Container Toolkit
docker run --rm --gpus all nvidia/cuda:13.0.0-base-ubuntu22.04 nvidia-smi
```
If this fails, reinstall NVIDIA Container Toolkit in WSL2.

### CUBLAS_STATUS_INVALID_VALUE error
PyTorch's bundled cuBLAS library can be incompatible with certain NVIDIA driver versions. The fix is to preload the system cuBLAS instead. This is already configured in `docker-compose-prebuilt.yml`:
```yaml
environment:
  - LD_PRELOAD=/usr/local/cuda/lib64/libcublas.so.13.0.0.19:/usr/local/cuda/lib64/libcublasLt.so.13.0.0.19
```

To verify the fix works:
```powershell
docker exec -it comfyui-3d python3 -c "import torch; a = torch.randn(64,64).cuda(); print('matmul OK:', (a @ a).shape)"
```

### Out of memory (OOM / exit code 137)
1. Increase WSL2 memory in `C:\Users\<you>\.wslconfig`:
   ```ini
   [wsl2]
   memory=24GB
   swap=16GB
   ```
2. Restart WSL: `wsl --shutdown`, then restart Docker Desktop
3. Use `--lowvram` or `--medvram` in `COMFYUI_ARGS`

### CUDA extensions rebuilding on every startup
If using the prebuilt image and extensions are rebuilding, make sure:
1. You're using `docker-compose-prebuilt.yml` (not `docker-compose.yml`)
2. The compose file includes `entrypoint: ["/entrypoint.sh"]`
3. The image was built with the build script (not manually)

### Models not found
Check that volume paths use forward slashes:
```yaml
- "D:/ComfyUI_installed_2/models:/models"  # correct
- "D:\ComfyUI_installed_2\models:/models"  # wrong
```

### ComfyUI-Manager "invalid channel" warning
```
manager_core.InvalidChannel: https://raw.githubusercontent.com/ltdrdata/ComfyUI-Manager/main
```
This is harmless — ComfyUI-Manager is trying an outdated channel URL. It does not affect functionality.

### Rebuild from scratch
```powershell
docker compose down
docker image rm comfyui-3d:latest
docker compose build --no-cache
```

---

## Why Docker instead of native Windows?

Building CUDA extensions (custom_rasterizer, torchsparse, voxelize) on Windows requires fighting MSVC/nvcc compatibility issues — `__asm__` syntax differences, header conflicts, missing sparsehash libs, etc.

On Linux inside Docker, all of these build cleanly with GCC in a single `pip install .` command. The resulting image runs on Windows via Docker Desktop's WSL2 backend with full GPU passthrough.

---

## Architecture Notes

- Base image: `nvidia/cuda:13.0.0-devel-ubuntu22.04` (includes nvcc, CUDA headers)
- All CUDA extensions compiled at build time targeting `sm_75;sm_80;sm_86;sm_89;sm_90`
- Models mounted as volumes at runtime (not baked in)
- Supports multi-drive model storage via multiple volume mounts
- `LD_PRELOAD` used to override PyTorch's bundled cuBLAS with the system cuBLAS for driver compatibility
- ComfyUI runs as root inside the container (simplifies permissions)
- Port 8188 exposed for the ComfyUI web UI and API
- Prebuilt images pushed to GitHub Container Registry (`ghcr.io`) with per-step versioning
