FROM ghcr.io/ggml-org/llama.cpp:server-cuda

ENV DEBIAN_FRONTEND=noninteractive \
    MODEL_DIR=/tmp/models \
    HF_HOME=/tmp/hf_home \
    HF_REPO=HauhauCS/Qwen3.6-27B-Uncensored-HauhauCS-Balanced \
    HF_FILE=Qwen3.6-27B-Uncensored-HauhauCS-Balanced-Q5_K_P.gguf \
    MODEL_REPO=HauhauCS/Qwen3.6-27B-Uncensored-HauhauCS-Balanced \
    MODEL_FILE=Qwen3.6-27B-Uncensored-HauhauCS-Balanced-Q5_K_P.gguf \
    HOST=0.0.0.0 \
    PORT=8080 \
    API_KEY=r \
    PATH="/opt/venv/bin:${PATH}"

USER root

RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
      bash \
      ca-certificates \
      curl \
      wget \
      python3 \
      python3-pip \
      python3-venv \
      coreutils \
      findutils; \
    rm -rf /var/lib/apt/lists/*; \
    python3 -m venv /opt/venv; \
    /opt/venv/bin/pip install --no-cache-dir -U pip; \
    /opt/venv/bin/pip install --no-cache-dir -U "huggingface_hub[cli]" hf_xet; \
    command -v llama-server || true; \
    find / -type f -name 'llama-server' 2>/dev/null | head -20 || true

COPY run.sh /run.sh
RUN chmod +x /run.sh

EXPOSE 8080

ENTRYPOINT ["/run.sh"]
