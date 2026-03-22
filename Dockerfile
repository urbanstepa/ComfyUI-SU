# ──────────────────────────────────────────────────────────────────────────────
# ComfyUI-SU Final Image
#
# Built on top of the base image which has all dependencies pre-installed.
# This layer only clones repos and copies config — builds in ~2 minutes.
#
# Base image: ghcr.io/urbanstepa/comfyui-su-base:latest
#   (built from Dockerfile.base via the "Build Base Image" workflow)
# ──────────────────────────────────────────────────────────────────────────────

ARG BASE_IMAGE=ghcr.io/urbanstepa/comfyui-su-base:latest
FROM ${BASE_IMAGE}

# ─────────────────────────────────────────────
# ComfyUI — urbanstepa fork
# ─────────────────────────────────────────────
RUN git clone https://github.com/urbanstepa/ComfyUI.git ${COMFYUI_PATH}

# ─────────────────────────────────────────────
# ComfyUI Manager — urbanstepa fork
# ─────────────────────────────────────────────
RUN git clone https://github.com/urbanstepa/ComfyUI-Manager.git \
    ${CUSTOM_NODES_PATH}/ComfyUI-Manager

# ─────────────────────────────────────────────
# comfyui-hunyuan3dwrapper — urbanstepa fork
# ─────────────────────────────────────────────
RUN git clone https://github.com/urbanstepa/ComfyUI-Hunyuan3DWrapper.git \
    ${CUSTOM_NODES_PATH}/comfyui-hunyuan3dwrapper

# ─────────────────────────────────────────────
# ComfyUI-Direct3D-S2 — urbanstepa fork
# ─────────────────────────────────────────────
RUN git clone https://github.com/urbanstepa/ComfyUI-Direct3D-S2.git \
    ${CUSTOM_NODES_PATH}/ComfyUI-Direct3D-S2

# ─────────────────────────────────────────────
# ComfyUI Essentials — image resize, remove bg, mask preview, etc.
# ─────────────────────────────────────────────
RUN git clone https://github.com/urbanstepa/ComfyUI_essentials.git \
    ${CUSTOM_NODES_PATH}/ComfyUI_essentials

# ─────────────────────────────────────────────
# ComfyUI-Hunyuan3d-2-1 — Hunyuan3D v2.1 mesh export, decimation, transparency
# ─────────────────────────────────────────────
RUN git clone https://github.com/urbanstepa/ComfyUI-Hunyuan3d-2-1.git \
    ${CUSTOM_NODES_PATH}/ComfyUI-Hunyuan3d-2-1

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
