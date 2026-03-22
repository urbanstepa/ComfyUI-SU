# ──────────────────────────────────────────────────────────────────────────────
# ComfyUI-SU Final Image
#
# Built on top of the base image (CUDA + Python + PyTorch).
# This layer installs:
#   - ComfyUI and all custom nodes (git clone + pip install requirements)
#   - Pre-built CUDA wheels (custom_rasterizer, voxelize, torchsparse, flash-attn)
#   - Config and entrypoint
# ──────────────────────────────────────────────────────────────────────────────

ARG BASE_IMAGE=ghcr.io/urbanstepa/comfyui-su-base:latest
FROM ${BASE_IMAGE}

# ─────────────────────────────────────────────
# Pre-built CUDA wheel URLs (from cuda-wheels release)
# Leave empty to compile from source (slower fallback).
# ─────────────────────────────────────────────
ARG CUSTOM_RASTERIZER_WHEEL_URL=""
ARG VOXELIZE_WHEEL_URL=""
ARG TORCHSPARSE_WHEEL_URL=""
ARG FLASH_ATTN_WHEEL_URL="https://github.com/mjun0812/flash-attention-prebuild-wheels/releases/download/v0.9.0/flash_attn-2.8.3%2Bcu130torch2.10-cp312-cp312-linux_x86_64.whl"

# GPU architecture (only needed if compiling from source)
ARG TORCH_CUDA_ARCH_LIST="7.5;8.0;8.6;8.9;9.0"
ENV TORCH_CUDA_ARCH_LIST=${TORCH_CUDA_ARCH_LIST}

# ─────────────────────────────────────────────
# ComfyUI — urbanstepa fork
# ─────────────────────────────────────────────
RUN git clone https://github.com/urbanstepa/ComfyUI.git ${COMFYUI_PATH} && \
    cd ${COMFYUI_PATH} && \
    pip install -r requirements.txt

# ─────────────────────────────────────────────
# ComfyUI Manager — urbanstepa fork
# ─────────────────────────────────────────────
RUN git clone https://github.com/urbanstepa/ComfyUI-Manager.git \
    ${CUSTOM_NODES_PATH}/ComfyUI-Manager && \
    cd ${CUSTOM_NODES_PATH}/ComfyUI-Manager && \
    pip install -r requirements.txt

# ─────────────────────────────────────────────
# comfyui-hunyuan3dwrapper — urbanstepa fork
# ─────────────────────────────────────────────
RUN git clone https://github.com/urbanstepa/ComfyUI-Hunyuan3DWrapper.git \
    ${CUSTOM_NODES_PATH}/comfyui-hunyuan3dwrapper && \
    cd ${CUSTOM_NODES_PATH}/comfyui-hunyuan3dwrapper && \
    pip install -r requirements.txt

# ─────────────────────────────────────────────
# custom_rasterizer — wheel or compile from source
# ─────────────────────────────────────────────
RUN if [ -n "${CUSTOM_RASTERIZER_WHEEL_URL}" ]; then \
      echo "Installing custom_rasterizer from pre-built wheel" && \
      pip install "${CUSTOM_RASTERIZER_WHEEL_URL}"; \
    else \
      echo "Compiling custom_rasterizer from source (slow)" && \
      cd ${CUSTOM_NODES_PATH}/comfyui-hunyuan3dwrapper/hy3dgen/texgen/custom_rasterizer && \
      FORCE_CUDA=1 MAX_JOBS=1 python setup.py install; \
    fi

# ─────────────────────────────────────────────
# ComfyUI-Direct3D-S2 — urbanstepa fork
# ─────────────────────────────────────────────
RUN git clone https://github.com/urbanstepa/ComfyUI-Direct3D-S2.git \
    ${CUSTOM_NODES_PATH}/ComfyUI-Direct3D-S2 && \
    cd ${CUSTOM_NODES_PATH}/ComfyUI-Direct3D-S2 && \
    pip install -r requirements.txt

# ─────────────────────────────────────────────
# voxelize — wheel or compile from source
# ─────────────────────────────────────────────
RUN if [ -n "${VOXELIZE_WHEEL_URL}" ]; then \
      echo "Installing voxelize from pre-built wheel" && \
      pip install "${VOXELIZE_WHEEL_URL}"; \
    else \
      echo "Compiling voxelize from source (slow)" && \
      cd ${CUSTOM_NODES_PATH}/ComfyUI-Direct3D-S2/voxelize && \
      FORCE_CUDA=1 MAX_JOBS=1 python setup.py install; \
    fi

# ─────────────────────────────────────────────
# torchsparse — wheel or compile from source
# ─────────────────────────────────────────────
RUN pip install rootpath backports.cached-property && \
    if [ -n "${TORCHSPARSE_WHEEL_URL}" ]; then \
      echo "Installing torchsparse from pre-built wheel" && \
      pip install "${TORCHSPARSE_WHEEL_URL}"; \
    else \
      echo "Compiling torchsparse from source (slow)" && \
      git clone https://github.com/urbanstepa/torchsparse.git /tmp/torchsparse && \
      cd /tmp/torchsparse && \
      FORCE_CUDA=1 MAX_JOBS=1 python setup.py install && \
      rm -rf /tmp/torchsparse; \
    fi

# ─────────────────────────────────────────────
# Re-pin PyTorch cu130 (requirements.txt may have downgraded to cu128)
# ─────────────────────────────────────────────
RUN pip install torch==2.10.0+cu130 torchvision==0.25.0+cu130 torchaudio==2.10.0+cu130 \
    --index-url https://download.pytorch.org/whl/cu130

# ─────────────────────────────────────────────
# flash-attn — pre-built wheel
# ─────────────────────────────────────────────
RUN if [ -n "${FLASH_ATTN_WHEEL_URL}" ]; then \
      pip install "${FLASH_ATTN_WHEEL_URL}"; \
    fi

# ─────────────────────────────────────────────
# ComfyUI Essentials — image resize, remove bg, mask preview, etc.
# ─────────────────────────────────────────────
RUN git clone https://github.com/urbanstepa/ComfyUI_essentials.git \
    ${CUSTOM_NODES_PATH}/ComfyUI_essentials && \
    cd ${CUSTOM_NODES_PATH}/ComfyUI_essentials && \
    pip install -r requirements.txt && \
    pip install "rembg[gpu]"

# ─────────────────────────────────────────────
# ComfyUI-Hunyuan3d-2-1 — Hunyuan3D v2.1 mesh export, decimation, transparency
# ─────────────────────────────────────────────
RUN git clone https://github.com/urbanstepa/ComfyUI-Hunyuan3d-2-1.git \
    ${CUSTOM_NODES_PATH}/ComfyUI-Hunyuan3d-2-1 && \
    cd ${CUSTOM_NODES_PATH}/ComfyUI-Hunyuan3d-2-1 && \
    pip install -r requirements.txt

# ─────────────────────────────────────────────
# Final PyTorch re-pin (safety net after all requirements.txt)
# ─────────────────────────────────────────────
RUN pip install torch==2.10.0+cu130 torchvision==0.25.0+cu130 torchaudio==2.10.0+cu130 \
    --index-url https://download.pytorch.org/whl/cu130

# ─────────────────────────────────────────────
# Model directory (mounted at runtime)
# ─────────────────────────────────────────────
RUN mkdir -p ${MODELS_PATH} && \
    mkdir -p ${COMFYUI_PATH}/user && \
    mkdir -p ${COMFYUI_PATH}/output && \
    mkdir -p ${COMFYUI_PATH}/input

# Symlink models directory into ComfyUI
RUN ln -sf ${MODELS_PATH} ${COMFYUI_PATH}/models

# ─────────────────────────────────────────────
# Extra model paths config
# ─────────────────────────────────────────────
COPY config/extra_model_paths.yaml ${COMFYUI_PATH}/extra_model_paths.yaml

# ─────────────────────────────────────────────
# Entrypoint
# ─────────────────────────────────────────────
COPY scripts/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

WORKDIR ${COMFYUI_PATH}
EXPOSE 8188

ENTRYPOINT ["/entrypoint.sh"]
