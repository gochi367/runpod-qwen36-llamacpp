FROM ghcr.io/ggml-org/llama.cpp:server-cuda

ENV MODEL_DIR=/tmp/models
ENV HF_HOME=/tmp/hf_home
ENV MODEL_REPO=HauhauCS/Qwen3.6-27B-Uncensored-HauhauCS-Balanced
ENV MODEL_FILE=Qwen3.6-27B-Uncensored-HauhauCS-Balanced-Q5_K_P.gguf

USER root

RUN apt-get update && apt-get install -y --no-install-recommends \
    python3 \
    python3-pip \
    ca-certificates \
    curl \
    && rm -rf /var/lib/apt/lists/*

RUN python3 -m pip install --no-cache-dir -U "huggingface_hub[cli]" hf_xet

COPY run.sh /run.sh
RUN chmod +x /run.sh

EXPOSE 8000

ENTRYPOINT ["/run.sh"]
