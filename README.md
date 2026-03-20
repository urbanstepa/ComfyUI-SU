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

---

## Quick Start

### 1. Clone this repo
```powershell
git clone https://github.com/YOUR_USERNAME/comfyui-3d-docker.git
cd comfyui-3d-docker
```

### 2. Edit docker-compose.yml — set your models path
Open `docker-compose.yml` and update the models volume to match your Windows path:
```yaml
volumes:
  - "D:/ComfyUI_installed_2/models:/models"
```
Note: Docker Desktop uses forward slashes even on Windows.

### 3. Build the image
```powershell
docker compose build
```
This will take **20-40 minutes** on first build — it compiles custom CUDA extensions from source.

### 4. Run
```powershell
docker compose up
```

ComfyUI will be available at: **http://localhost:8188**

---

## Configuration

### Custom launch arguments
Set `COMFYUI_ARGS` in `docker-compose.yml`:
```yaml
environment:
  - COMFYUI_ARGS=--listen 0.0.0.0 --port 8188 --highvram
```

Useful flags:
| Flag | Description |
|------|-------------|
| `--highvram` | Keep models in VRAM (RTX 3090 recommended) |
| `--lowvram` | Aggressive offloading for GPUs < 8GB |
| `--cpu` | CPU-only mode (slow) |
| `--disable-auto-launch` | Don't open browser automatically |

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

### Out of memory
Add `--lowvram` or `--medvram` to `COMFYUI_ARGS`.

### Models not found
Check that the volume path in `docker-compose.yml` uses forward slashes:
```yaml
- "D:/ComfyUI_installed_2/models:/models"  # correct
- "D:\ComfyUI_installed_2\models:/models"  # wrong
```

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
- Models mounted as a volume at runtime (not baked in)
- ComfyUI runs as root inside the container (simplifies permissions)
- Port 8188 exposed for the ComfyUI web UI and API
