FROM pytorch/pytorch:2.7.0-cuda12.8-cudnn9-devel
ENV DEBIAN_FRONTEND=noninteractive \
    PYTHONUNBUFFERED=1 \
    PYTHONIOENCODING=UTF-8
RUN rm -f /etc/apt/apt.conf.d/docker-clean && echo 'Binary::apt::APT::Keep-Downloaded-Packages "true";' > /etc/apt/apt.conf.d/keep-cache
RUN --mount=type=cache,target=/var/cache/apt --mount=type=cache,target=/var/lib/apt apt update &&\
    apt install -y \
    git \
    libcairo2-dev \
    ffmpeg \
    libtcmalloc-minimal4 \
    libmimalloc2.0 \
    gifsicle \
    libimage-exiftool-perl \
    sox \
    libportaudio2
RUN useradd -m -u 10000 sd
RUN --mount=type=cache,target=/home/sd/.cache chown 10000:10000 /home/sd/.cache
USER 10000:10000
WORKDIR /app
RUN --mount=type=cache,target=/home/sd/.cache python -m pip install packaging wheel
#RUN --mount=type=cache,target=/home/sd/.cache MAX_JOBS=10 python -m pip install --no-build-isolation flash-attn
COPY requirements.txt /app/
RUN --mount=type=cache,target=/home/sd/.cache python -m pip install -r /app/requirements.txt

WORKDIR /build
RUN git clone https://github.com/thu-ml/SageAttention.git
WORKDIR /build/SageAttention
ENV TORCH_CUDA_ARCH_LIST=12.0
RUN sed -i "/compute_capabilities = set()/a compute_capabilities = {\"$TORCH_CUDA_ARCH_LIST\"}" setup.py
RUN --mount=type=cache,target=/home/sd/.cache python -m pip install git+https://github.com/aredden/torch-cublas-hgemm.git . --no-build-isolation

COPY custom_nodes/ComfyUI-MochiWrapper/requirements.txt /app/mochi_reqs.txt
RUN --mount=type=cache,target=/home/sd/.cache python -m pip install --no-build-isolation -r /app/mochi_reqs.txt
COPY custom_nodes/ComfyUI-LTXVideo/requirements.txt /app/ltx.txt
RUN --mount=type=cache,target=/home/sd/.cache python -m pip install -r /app/ltx.txt
COPY vhs_reqs.txt kj_reqs.txt misc_reqs.txt cogv_reqs.txt /app/
RUN --mount=type=cache,target=/home/sd/.cache python -m pip install -r /app/vhs_reqs.txt -r /app/kj_reqs.txt -r /app/misc_reqs.txt -r /app/cogv_reqs.txt
#RUN --mount=type=cache,target=/home/sd/.cache python -m pip install --no-build-isolation git+https://github.com/aredden/torch-cublas-hgemm.git git+https://github.com/thu-ml/SageAttention.git@dcc405e192f86e14fb66997a2f44b6b8df91f339 peft
RUN --mount=type=cache,target=/home/sd/.cache python -m pip install peft
COPY custom_nodes/ComfyUI_VLM_nodes/requirements.txt /app/vlm_reqs.txt
COPY custom_nodes/ComfyUI_VLM_nodes/cpp_agent_req.txt /app/cppagent_reqs.txt
RUN --mount=type=cache,target=/home/sd/.cache --mount=type=bind,source=deps,target=/deps python -m pip install /deps/flash_attn-2.8.2+cu12torch2.7cxx11abiTRUE-cp311-cp311-linux_x86_64.whl
COPY custom_nodes/ComfyUI-HunyuanVideoWrapper/requirements.txt /app/hy_reqs.txt
RUN --mount=type=cache,target=/home/sd/.cache python -m pip install -r /app/hy_reqs.txt torchao descript-audio-codec
COPY custom_nodes/ComfyUI-MMAudio/requirements.txt /app/mma_reqs.txt
RUN --mount=type=cache,target=/home/sd/.cache python -m pip install -r /app/mma_reqs.txt
#COPY custom_nodes/EasyAnimate/requirements.txt /app/ea_reqs.txt
RUN --mount=type=cache,target=/home/sd/.cache python -m pip install albumentations pywavelets func_timeout gradio
COPY custom_nodes/ComfyUI-FramePackWrapper/requirements.txt /app/fpw_reqs.txt
RUN --mount=type=cache,target=/home/sd/.cache python -m pip install -r /app/fpw_reqs.txt
RUN --mount=type=cache,target=/home/sd/.cache python -m pip install comfy-cli
COPY custom_nodes/ComfyUI_ACE-Step/requirements.txt /app/as_reqs.txt
COPY custom_nodes/ComfyUI_AudioTools/requirements.txt /app/at_reqs.txt
RUN --mount=type=cache,target=/home/sd/.cache python -m pip install -r /app/at_reqs.txt -r /app/as_reqs.txt sounddevice
RUN --mount=type=cache,target=/home/sd/.cache python -m pip install -r /app/vlm_reqs.txt -r /app/cppagent_reqs.txt
RUN --mount=type=cache,target=/home/sd/.cache python -m pip install flashy lightning openunmix lameenc
COPY custom_nodes/ComfyUI_Fill-ChatterBox/requirements.txt /app/chb_reqs.txt
RUN --mount=type=cache,target=/home/sd/.cache python -m pip install -r /app/chb_reqs.txt resemble-perth rotary_embedding_torch
RUN mkdir -p /home/sd/.cache
ENTRYPOINT ["/app/entrypoint.sh", "--listen"]
CMD ["--use-sage-attention", "--preview-method", "latent2rgb"]
