# ──────────────────────────────────────────────────────────────────────────────
# ComfyUI-SU Final Image
#
# Built on top of the base image which already has:
#   - CUDA + Python + PyTorch
#   - ComfyUI + all custom nodes cloned with pip deps installed
#
# This layer only:
#   - Installs pre-built CUDA wheels (fast pip install, no compilation)
#   - Copies config and entrypoint
# ──────────────────────────────────────────────────────────────────────────────

ARG BASE_IMAGE=ghcr.io/urbanstepa/comfyui-su-base:latest
FROM ${BASE_IMAGE}

# ─────────────────────────────────────────────
# Pre-built CUDA wheel URLs (from cuda-wheels release)
# ─────────────────────────────────────────────
ARG CUSTOM_RASTERIZER_WHEEL_URL=""
ARG VOXELIZE_WHEEL_URL=""
ARG TORCHSPARSE_WHEEL_URL=""
ARG FLASH_ATTN_WHEEL_URL="https://github.com/mjun0812/flash-attention-prebuild-wheels/releases/download/v0.9.0/flash_attn-2.8.3%2Bcu130torch2.10-cp312-cp312-linux_x86_64.whl"

# ─────────────────────────────────────────────
# Install CUDA wheels
# ─────────────────────────────────────────────
RUN if [ -n "${CUSTOM_RASTERIZER_WHEEL_URL}" ]; then \
      echo "Installing custom_rasterizer wheel" && \
      pip install "${CUSTOM_RASTERIZER_WHEEL_URL}"; \
    else \
      echo "⚠ CUSTOM_RASTERIZER_WHEEL_URL not set — skipping"; \
    fi

RUN if [ -n "${VOXELIZE_WHEEL_URL}" ]; then \
      echo "Installing voxelize wheel" && \
      pip install "${VOXELIZE_WHEEL_URL}"; \
    else \
      echo "⚠ VOXELIZE_WHEEL_URL not set — skipping"; \
    fi

RUN if [ -n "${TORCHSPARSE_WHEEL_URL}" ]; then \
      echo "Installing torchsparse wheel" && \
      pip install "${TORCHSPARSE_WHEEL_URL}"; \
    else \
      echo "⚠ TORCHSPARSE_WHEEL_URL not set — skipping"; \
    fi

RUN if [ -n "${FLASH_ATTN_WHEEL_URL}" ]; then \
      echo "Installing flash-attn wheel" && \
      pip install "${FLASH_ATTN_WHEEL_URL}"; \
    else \
      echo "⚠ FLASH_ATTN_WHEEL_URL not set — skipping"; \
    fi

# ─────────────────────────────────────────────
# Final PyTorch re-pin (safety net)
# ─────────────────────────────────────────────
RUN pip install torch==2.10.0+cu130 torchvision==0.25.0+cu130 torchaudio==2.10.0+cu130 \
    --index-url https://download.pytorch.org/whl/cu130

# ─────────────────────────────────────────────
# Config + Entrypoint
# ─────────────────────────────────────────────
COPY config/extra_model_paths.yaml ${COMFYUI_PATH}/extra_model_paths.yaml
COPY scripts/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

WORKDIR ${COMFYUI_PATH}
EXPOSE 8188

ENTRYPOINT ["/entrypoint.sh"]
