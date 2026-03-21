# ComfyUI 3D Docker

A Docker image for running ComfyUI with 3D generation support on Windows via Docker Desktop.

**Includes:**
- ComfyUI (latest)
- ComfyUI Manager
- comfyui-hunyuan3dwrapper (Hunyuan3D 2.x — 3D mesh + texture generation)
- ComfyUI-Direct3D-S2 (Direct3D sparse 3D generation)
- ComfyUI_essentials (image resize, background removal, masks)
- ComfyUI-Hunyuan3d-2-1 (Hunyuan3D v2.1 mesh export, decimation)

**Stack:**
- CUDA 13.0
- Python 3.12
- PyTorch 2.10.0+cu130
- Ubuntu 22.04

**All CUDA extensions (custom_rasterizer, voxelize, torchsparse) are compiled at image build time** — containers start in seconds.

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

## Quick Start

### 1. Clone this repo
```powershell
git clone https://github.com/urbanstepa/ComfyUI-SU.git
cd ComfyUI-SU
```

### 2. Edit docker-compose.yml — set your paths
Update volume paths to match your Windows setup:
```yaml
volumes:
  - "D:/ComfyUI_installed_2/models:/models"
  - "D:/ComfyUI_installed_2/output:/opt/ComfyUI/output"
  - "D:/ComfyUI_installed_2/input:/opt/ComfyUI/input"
  - "D:/ComfyUI_installed_2/user:/opt/ComfyUI/user"
```
Note: Docker Desktop uses forward slashes even on Windows.

### 3. Run
```powershell
docker compose up
```

ComfyUI will be available at: **http://localhost:8188**

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

## Image Versioning

The CI workflow automatically tags each image with:
- `latest` — always the most recent build
- `main` — latest from the main branch
- `20260321-1430` — date-based tag for each build
- `sha-abc1234` — commit SHA tag for exact traceability
- `v1.0.0` — semver tags (when you create a git tag)

To use a specific version:
```yaml
image: ghcr.io/urbanstepa/comfyui-su:20260321-1430
```

List available versions:
```powershell
docker images ghcr.io/urbanstepa/comfyui-su --format "{{.Tag}}"
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
PyTorch's bundled cuBLAS library can be incompatible with certain NVIDIA driver versions. The fix is to preload the system cuBLAS instead. This is already configured in `docker-compose.yml`:
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

### pymeshlab "Unknown format for load: ply"
The container needs `libopengl0` for pymeshlab's PLY plugin. This is installed in the Dockerfile. If you get this error on an older image, update to the latest.

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
docker image rm ghcr.io/urbanstepa/comfyui-su:latest
docker compose build --no-cache
```

---

## Why Docker instead of native Windows?

Building CUDA extensions (custom_rasterizer, torchsparse, voxelize) on Windows requires fighting MSVC/nvcc compatibility issues — `__asm__` syntax differences, header conflicts, missing sparsehash libs, etc.

On Linux inside Docker, all of these build cleanly with GCC in a single `pip install .` command. The resulting image runs on Windows via Docker Desktop's WSL2 backend with full GPU passthrough.

---

## Architecture Notes

- Base image: `nvidia/cuda:13.0.0-devel-ubuntu22.04` (includes nvcc, CUDA headers)
- All CUDA extensions compiled at image build time targeting `sm_75;sm_80;sm_86;sm_89;sm_90`
- Models mounted as volumes at runtime (not baked in)
- Supports multi-drive model storage via multiple volume mounts
- `LD_PRELOAD` used to override PyTorch's bundled cuBLAS with the system cuBLAS for driver compatibility
- ComfyUI runs as root inside the container (simplifies permissions)
- Port 8188 exposed for the ComfyUI web UI and API
- CI builds via GitHub Actions with automatic date/SHA versioning
