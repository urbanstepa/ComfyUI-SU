# ──────────────────────────────────────────────────────────────────────────────
# ComfyUI-SU Final Image
#
# Built on top of the base image (CUDA + Python + PyTorch).
# This layer:
#   - Clones all custom nodes and installs their pip deps
#   - Installs pre-built CUDA wheels (no compilation)
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
# ComfyUI Manager — urbanstepa fork
# ─────────────────────────────────────────────
# Patch: ComfyUI-Manager channel_url mismatch
#   The Manager's config.ini defaults channel_url to the old ltdrdata GitHub URL,
#   but channels.list now points to Comfy-Org. The old URL fails valid_channels
#   validation, causing: "An invalid channel was used: __https://...ltdrdata...__"
#   Fix: pre-create config.ini with channel_url = default (resolves via channels.list).
RUN git clone https://github.com/urbanstepa/ComfyUI-Manager.git \
    ${CUSTOM_NODES_PATH}/ComfyUI-Manager && \
    cd ${CUSTOM_NODES_PATH}/ComfyUI-Manager && \
    pip install -r requirements.txt && \
    mkdir -p /opt/ComfyUI/user/__manager && \
    printf '[default]\nchannel_url = default\n' > /opt/ComfyUI/user/__manager/config.ini

# ─────────────────────────────────────────────
# comfyui-hunyuan3dwrapper — urbanstepa fork
# ─────────────────────────────────────────────
RUN git clone https://github.com/urbanstepa/ComfyUI-Hunyuan3DWrapper.git \
    ${CUSTOM_NODES_PATH}/comfyui-hunyuan3dwrapper && \
    cd ${CUSTOM_NODES_PATH}/comfyui-hunyuan3dwrapper && \
    pip install -r requirements.txt

# ─────────────────────────────────────────────
# ComfyUI-Direct3D-S2 — urbanstepa fork
# ─────────────────────────────────────────────
# Patch: direct3d_s2/utils/rembg.py — BiRefNet dtype mismatch
#   The BiRefNet background removal model (ZhengPeng7/BiRefNet) is loaded via
#   transformers AutoModelForImageSegmentation which defaults to fp16 weights.
#   However, the input tensor from torchvision transforms is always float32.
#   This causes: RuntimeError: Input type (float) and bias type (c10::Half) should be the same
#   at the first Conv2d layer (patch_embed.proj).
#   Fix: cast input_images to match the model's parameter dtype before inference.
RUN git clone https://github.com/urbanstepa/ComfyUI-Direct3D-S2.git \
    ${CUSTOM_NODES_PATH}/ComfyUI-Direct3D-S2 && \
    cd ${CUSTOM_NODES_PATH}/ComfyUI-Direct3D-S2 && \
    pip install -r requirements.txt && \
    sed -i 's/input_images = transform_image(image).unsqueeze(0).to(self.device)/input_images = transform_image(image).unsqueeze(0).to(device=self.device, dtype=next(self.birefnet_model.parameters()).dtype)/' \
    direct3d_s2/utils/rembg.py

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
# torchsparse runtime deps
# ─────────────────────────────────────────────
RUN pip install rootpath backports.cached-property

# ─────────────────────────────────────────────
# Re-pin PyTorch cu130 (requirements.txt may have downgraded to cu128)
# ─────────────────────────────────────────────
RUN pip install torch==2.10.0+cu130 torchvision==0.25.0+cu130 torchaudio==2.10.0+cu130 \
    --index-url https://download.pytorch.org/whl/cu130

# ─────────────────────────────────────────────
# Install CUDA wheels (no compilation)
# ─────────────────────────────────────────────
RUN if [ -n "${CUSTOM_RASTERIZER_WHEEL_URL}" ]; then \
      echo "Installing custom_rasterizer wheel" && \
      pip install "${CUSTOM_RASTERIZER_WHEEL_URL}"; \
    else echo "⚠ CUSTOM_RASTERIZER_WHEEL_URL not set — skipping"; fi

RUN if [ -n "${VOXELIZE_WHEEL_URL}" ]; then \
      echo "Installing voxelize wheel" && \
      pip install "${VOXELIZE_WHEEL_URL}"; \
    else echo "⚠ VOXELIZE_WHEEL_URL not set — skipping"; fi

RUN if [ -n "${TORCHSPARSE_WHEEL_URL}" ]; then \
      echo "Installing torchsparse wheel" && \
      pip install "${TORCHSPARSE_WHEEL_URL}"; \
    else echo "⚠ TORCHSPARSE_WHEEL_URL not set — skipping"; fi

RUN if [ -n "${FLASH_ATTN_WHEEL_URL}" ]; then \
      echo "Installing flash-attn wheel" && \
      pip install "${FLASH_ATTN_WHEEL_URL}"; \
    else echo "⚠ FLASH_ATTN_WHEEL_URL not set — skipping"; fi

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
