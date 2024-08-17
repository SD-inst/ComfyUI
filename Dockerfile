FROM nvidia/cuda:12.1.0-cudnn8-runtime-ubuntu22.04
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
    libimage-exiftool-perl
RUN useradd -m -u 10000 sd
RUN --mount=type=cache,target=/root/.cache python -m pip install --upgrade pip wheel
WORKDIR /app
COPY requirements.txt /app/
RUN --mount=type=cache,target=/root/.cache python -m pip install --extra-index-url https://download.pytorch.org/whl/cu121 -U -r /app/requirements.txt
COPY svd_reqs.txt vhs_reqs.txt dyncr_reqs.txt kj_reqs.txt fint_reqs.txt bnb_reqs.txt cogv_reqs.txt /app/
RUN --mount=type=cache,target=/root/.cache python -m pip install --extra-index-url https://download.pytorch.org/whl/cu121 -U -r /app/svd_reqs.txt -r /app/vhs_reqs.txt -r /app/dyncr_reqs.txt -r /app/kj_reqs.txt -r /app/fint_reqs.txt -r /app/bnb_reqs.txt -r /app/cogv_reqs.txt
RUN --mount=type=cache,target=/root/.cache --mount=type=bind,source=./onediff,target=/app/onediff,rw cd onediff && pip install -e . && python3 -m pip install --pre oneflow scikit-image -f https://oneflow-pro.oss-cn-beijing.aliyuncs.com/branch/community/cu121
USER 10000:10000
ENTRYPOINT ["python", "main.py"]
CMD ["--listen", "--disable-smart-memory"]
