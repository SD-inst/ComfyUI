FROM nvidia/cuda:12.4.1-cudnn-devel-ubuntu22.04
ENV DEBIAN_FRONTEND=noninteractive \
    PYTHONUNBUFFERED=1 \
    PYTHONIOENCODING=UTF-8
RUN rm -f /etc/apt/apt.conf.d/docker-clean && echo 'Binary::apt::APT::Keep-Downloaded-Packages "true";' > /etc/apt/apt.conf.d/keep-cache
RUN --mount=type=cache,target=/var/cache/apt --mount=type=cache,target=/var/lib/apt apt update &&\
    apt install -y \
    wget \
    git \
    pkg-config \
    libcairo2-dev \
    python3 \
    python3-pip \
    python-is-python3 \
    ffmpeg \
    libnvrtc11.2 \
    libtcmalloc-minimal4 \
    libmimalloc2.0 \
    gifsicle \
    ninja-build \
    libimage-exiftool-perl
RUN useradd -m -u 10000 sd
RUN --mount=type=cache,target=/root/.cache python -m pip install --upgrade pip wheel
WORKDIR /app
COPY requirements.txt /app/
RUN --mount=type=cache,target=/root/.cache python -m pip install --extra-index-url https://download.pytorch.org/whl/cu124 -U -r /app/requirements.txt
COPY custom_nodes/ComfyUI-MochiWrapper/requirements.txt /app/mochi_reqs.txt
RUN --mount=type=cache,target=/root/.cache python -m pip install --extra-index-url https://download.pytorch.org/whl/cu124 --no-build-isolation -U -r /app/mochi_reqs.txt
COPY custom_nodes/ComfyUI-LTXVideo/requirements.txt /app/ltx.txt
RUN --mount=type=cache,target=/root/.cache python -m pip install -r /app/ltx.txt
COPY svd_reqs.txt vhs_reqs.txt dyncr_reqs.txt kj_reqs.txt fint_reqs.txt misc_reqs.txt cogv_reqs.txt /app/
RUN --mount=type=cache,target=/root/.cache python -m pip install --extra-index-url https://download.pytorch.org/whl/cu124 -U -r /app/vhs_reqs.txt -r /app/dyncr_reqs.txt -r /app/kj_reqs.txt -r /app/fint_reqs.txt -r /app/misc_reqs.txt -r /app/cogv_reqs.txt
COPY custom_nodes/ComfyUI-PyramidFlowWrapper/requirements.txt /app/pyrf_reqs.txt
RUN --mount=type=cache,target=/root/.cache python -m pip install --extra-index-url https://download.pytorch.org/whl/cu124 -U -r /app/pyrf_reqs.txt
RUN --mount=type=cache,target=/root/.cache --mount=type=bind,source=deps,target=/app/deps cd deps && python3 -m pip install llama_cpp_python-0.2.90-cp310-cp310-linux_x86_64.whl flash_attn-2.7.0.post2+cu12torch2.5cxx11abiFALSE-cp310-cp310-linux_x86_64.whl
ENV TORCH_CUDA_ARCH_LIST=8.6
RUN --mount=type=cache,target=/root/.cache python -m pip install git+https://github.com/aredden/torch-cublas-hgemm.git git+https://github.com/thu-ml/SageAttention.git peft
COPY custom_nodes/ComfyUI_VLM_nodes/requirements.txt /app/vlm_reqs.txt
COPY custom_nodes/ComfyUI_VLM_nodes/cpp_agent_req.txt /app/cppagent_reqs.txt
RUN --mount=type=cache,target=/root/.cache python -m pip install --extra-index-url https://download.pytorch.org/whl/cu124 -r /app/vlm_reqs.txt -r /app/cppagent_reqs.txt
COPY custom_nodes/ComfyUI-HunyuanVideoWrapper/requirements.txt /app/hy_reqs.txt
RUN --mount=type=cache,target=/root/.cache python -m pip install --extra-index-url https://download.pytorch.org/whl/cu124 -r /app/hy_reqs.txt torchao
COPY custom_nodes/ComfyUI-MMAudio/requirements.txt /app/mma_reqs.txt
RUN --mount=type=cache,target=/root/.cache python -m pip install --extra-index-url https://download.pytorch.org/whl/cu124 -r /app/mma_reqs.txt
COPY custom_nodes/EasyAnimate/requirements.txt /app/ea_reqs.txt
RUN --mount=type=cache,target=/root/.cache python -m pip install --extra-index-url https://download.pytorch.org/whl/cu124 -r /app/ea_reqs.txt
RUN mkdir /home/sd/.cache && chown 10000:10000 /home/sd/.cache
USER 10000:10000
ENTRYPOINT ["python", "main.py"]
CMD ["--listen", "--disable-smart-memory"]
