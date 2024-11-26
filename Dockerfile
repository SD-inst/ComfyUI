FROM nvidia/cuda:12.1.0-cudnn8-devel-ubuntu22.04
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
RUN --mount=type=cache,target=/root/.cache python -m pip install --extra-index-url https://download.pytorch.org/whl/cu121 -U -r /app/requirements.txt
COPY custom_nodes/ComfyUI-MochiWrapper/requirements.txt /app/mochi_reqs.txt
RUN --mount=type=cache,target=/root/.cache python -m pip install --extra-index-url https://download.pytorch.org/whl/cu121 --no-build-isolation -U -r /app/mochi_reqs.txt
#COPY flash_attn.tar.gz /usr/local/lib/python3.10/dist-packages
#RUN cd /usr/local/lib/python3.10/dist-packages && tar xf flash_attn.tar.gz && rm flash_attn.tar.gz
#RUN --mount=type=cache,target=/root/.cache python -m pip install --extra-index-url https://download.pytorch.org/whl/cu121 -U torch torchvision torchaudio
COPY svd_reqs.txt vhs_reqs.txt dyncr_reqs.txt kj_reqs.txt fint_reqs.txt misc_reqs.txt cogv_reqs.txt /app/
RUN --mount=type=cache,target=/root/.cache python -m pip install --extra-index-url https://download.pytorch.org/whl/cu121 -U -r /app/vhs_reqs.txt -r /app/dyncr_reqs.txt -r /app/kj_reqs.txt -r /app/fint_reqs.txt -r /app/misc_reqs.txt -r /app/cogv_reqs.txt
COPY custom_nodes/ComfyUI-PyramidFlowWrapper/requirements.txt /app/pyrf_reqs.txt
RUN --mount=type=cache,target=/root/.cache python -m pip install --extra-index-url https://download.pytorch.org/whl/cu121 -U -r /app/pyrf_reqs.txt
RUN --mount=type=cache,target=/root/.cache --mount=type=bind,source=./onediff,target=/app/onediff,rw --mount=type=bind,source=deps,target=/app/onediff/deps cd onediff && pip install -e . && cd deps && python3 -m pip install *.whl
ENV TORCH_CUDA_ARCH_LIST=8.6
RUN --mount=type=cache,target=/root/.cache python -m pip install git+https://github.com/aredden/torch-cublas-hgemm.git sageattention peft
USER 10000:10000
ENTRYPOINT ["python", "main.py"]
CMD ["--listen", "--disable-smart-memory"]
