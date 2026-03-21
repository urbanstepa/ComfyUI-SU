# ComfyUI 3D Docker Image
# Includes: comfyui-hunyuan3dwrapper, ComfyUI-Direct3D-S2
# Base: CUDA 13.0 + Python 3.12 + torch 2.10.0+cu130
# Sources: github.com/urbanstepa

FROM nvidia/cuda:13.0.0-devel-ubuntu22.04

# Prevent interactive prompts during build
ENV DEBIAN_FRONTEND=noninteractive
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

# CUDA environment
ENV CUDA_HOME=/usr/local/cuda
ENV PATH=${CUDA_HOME}/bin:${PATH}
ENV LD_LIBRARY_PATH=${CUDA_HOME}/lib64:${LD_LIBRARY_PATH}

# ComfyUI paths
ENV COMFYUI_PATH=/opt/ComfyUI
ENV CUSTOM_NODES_PATH=${COMFYUI_PATH}/custom_nodes
ENV MODELS_PATH=/models

# GPU architecture — override at build time if needed: --build-arg TORCH_CUDA_ARCH_LIST="8.9"
ARG TORCH_CUDA_ARCH_LIST="7.5;8.0;8.6;8.9;9.0"
ENV TORCH_CUDA_ARCH_LIST=${TORCH_CUDA_ARCH_LIST}

# ─────────────────────────────────────────────
# System dependencies + Python 3.12 via deadsnakes PPA
# ─────────────────────────────────────────────
RUN apt-get update && apt-get install -y \
    software-properties-common \
    curl \
    && add-apt-repository ppa:deadsnakes/ppa -y \
    && apt-get update && apt-get install -y \
    python3.12 \
    python3.12-dev \
    python3.12-venv \
    git \
    git-lfs \
    wget \
    build-essential \
    ninja-build \
    libsparsehash-dev \
    libgl1 \
    libglib2.0-0 \
    libsm6 \
    libxext6 \
    libxrender-dev \
    libgomp1 \
    libopengl0 \
    && rm -rf /var/lib/apt/lists/*

# Set python3.12 as default, then install pip
RUN update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.12 1 && \
    update-alternatives --install /usr/bin/python python /usr/bin/python3.12 1 && \
    curl -sS https://bootstrap.pypa.io/get-pip.py | python3.12 && \
    python3.12 -m pip install --upgrade pip setuptools wheel

# ─────────────────────────────────────────────
# PyTorch 2.10.0 + CUDA 13.0
# ─────────────────────────────────────────────
RUN pip install torch==2.10.0+cu130 torchvision==0.25.0+cu130 torchaudio==2.10.0+cu130 \
    --index-url https://download.pytorch.org/whl/cu130

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
# Build custom_rasterizer (CUDA cross-compile, no GPU needed)
# ─────────────────────────────────────────────
RUN cd ${CUSTOM_NODES_PATH}/comfyui-hunyuan3dwrapper/hy3dgen/texgen/custom_rasterizer && \
    MAX_JOBS=1 python setup.py install && \
    touch /opt/.custom_rasterizer_built

# ─────────────────────────────────────────────
# ComfyUI-Direct3D-S2 — urbanstepa fork
# ─────────────────────────────────────────────
RUN git clone https://github.com/urbanstepa/ComfyUI-Direct3D-S2.git \
    ${CUSTOM_NODES_PATH}/ComfyUI-Direct3D-S2 && \
    cd ${CUSTOM_NODES_PATH}/ComfyUI-Direct3D-S2 && \
    pip install -r requirements.txt

# ─────────────────────────────────────────────
# Build voxelize (CUDA cross-compile, no GPU needed)
# ─────────────────────────────────────────────
RUN cd ${CUSTOM_NODES_PATH}/ComfyUI-Direct3D-S2/voxelize && \
    MAX_JOBS=1 python setup.py install && \
    touch /opt/.voxelize_built

# ─────────────────────────────────────────────
# Build torchsparse from source — urbanstepa fork
# (CUDA cross-compile, no GPU needed)
# ─────────────────────────────────────────────
RUN pip install rootpath backports.cached-property && \
    git clone https://github.com/urbanstepa/torchsparse.git /tmp/torchsparse && \
    cd /tmp/torchsparse && \
    MAX_JOBS=1 python setup.py install && \
    touch /opt/.torchsparse_built && \
    rm -rf /tmp/torchsparse

# ─────────────────────────────────────────────
# flash-attn — required by ComfyUI-Direct3D-S2 attention module
# ─────────────────────────────────────────────
RUN MAX_JOBS=1 pip install flash-attn --no-build-isolation && \
    touch /opt/.flash_attn_built

# ─────────────────────────────────────────────
# ComfyUI Essentials — image resize, remove bg, mask preview, etc.
# ─────────────────────────────────────────────
RUN git clone https://github.com/urbanstepa/ComfyUI_essentials.git \
    ${CUSTOM_NODES_PATH}/ComfyUI_essentials && \
    cd ${CUSTOM_NODES_PATH}/ComfyUI_essentials && \
    pip install -r requirements.txt && \
    pip install "rembg[gpu]" && \
    touch /opt/.comfyui_essentials_built

# ─────────────────────────────────────────────
# ComfyUI-Hunyuan3d-2-1 — Hunyuan3D v2.1 mesh export, decimation, transparency
# ─────────────────────────────────────────────
RUN git clone https://github.com/urbanstepa/ComfyUI-Hunyuan3d-2-1.git \
    ${CUSTOM_NODES_PATH}/ComfyUI-Hunyuan3d-2-1 && \
    cd ${CUSTOM_NODES_PATH}/ComfyUI-Hunyuan3d-2-1 && \
    pip install --ignore-installed -r requirements.txt && \
    touch /opt/.comfyui_hunyuan3d21_built

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
# Build manifest — record what was compiled
# ─────────────────────────────────────────────
RUN echo "custom_rasterizer | docker build" >> /opt/.prebuilt-manifest && \
    echo "voxelize | docker build" >> /opt/.prebuilt-manifest && \
    echo "torchsparse | docker build" >> /opt/.prebuilt-manifest && \
    echo "comfyui_essentials | docker build" >> /opt/.prebuilt-manifest && \
    echo "comfyui_hunyuan3d21 | docker build" >> /opt/.prebuilt-manifest

# ─────────────────────────────────────────────
# Entrypoint
# ─────────────────────────────────────────────
COPY scripts/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

WORKDIR ${COMFYUI_PATH}
EXPOSE 8188

ENTRYPOINT ["/entrypoint.sh"]
