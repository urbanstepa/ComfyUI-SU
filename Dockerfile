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
    && rm -rf /var/lib/apt/lists/*

# Set python3.12 as default, then install pip
RUN update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.12 1 && \
    update-alternatives --install /usr/bin/python python /usr/bin/python3.12 1 && \
    curl -sS https://bootstrap.pypa.io/get-pip.py | python3.12 && \
    python3.12 -m pip install --upgrade pip setuptools wheel

# ─────────────────────────────────────────────
# PyTorch 2.10.0 + CUDA 13.0
# ─────────────────────────────────────────────
RUN pip install torch==2.10.0 torchvision torchaudio \
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
RUN git clone https://github.com/urbanstepa/ComfyUI-HunyuanVideoWrapper.git \
    ${CUSTOM_NODES_PATH}/comfyui-hunyuan3dwrapper && \
    cd ${CUSTOM_NODES_PATH}/comfyui-hunyuan3dwrapper && \
    pip install -r requirements.txt

# Build custom_rasterizer from source (Linux — no MSVC needed)
ENV TORCH_CUDA_ARCH_LIST="7.5;8.0;8.6;8.9;9.0"
RUN cd ${CUSTOM_NODES_PATH}/comfyui-hunyuan3dwrapper/hy3dgen/texgen/custom_rasterizer && \
    pip install .

# ─────────────────────────────────────────────
# ComfyUI-Direct3D-S2 — urbanstepa fork
# ─────────────────────────────────────────────
RUN git clone https://github.com/urbanstepa/ComfyUI-Direct3D-S2.git \
    ${CUSTOM_NODES_PATH}/ComfyUI-Direct3D-S2 && \
    cd ${CUSTOM_NODES_PATH}/ComfyUI-Direct3D-S2 && \
    pip install -r requirements.txt

# Build torchsparse from source — urbanstepa fork
RUN git clone https://github.com/urbanstepa/torchsparse.git /tmp/torchsparse && \
    cd /tmp/torchsparse && \
    pip install . && \
    rm -rf /tmp/torchsparse

# Build voxelize extension
RUN cd ${CUSTOM_NODES_PATH}/ComfyUI-Direct3D-S2/voxelize && \
    pip install .

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
