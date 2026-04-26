FROM nvidia/cuda:12.4.1-devel-ubuntu22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV MODEL_DIR=/tmp/models
ENV HF_HOME=/tmp/hf_home
ENV MODEL_REPO=HauhauCS/Qwen3.6-27B-Uncensored-HauhauCS-Balanced
ENV MODEL_FILE=Qwen3.6-27B-Uncensored-HauhauCS-Balanced-Q5_K_P.gguf

RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    cmake \
    build-essential \
    ca-certificates \
    curl \
    wget \
    python3 \
    python3-pip \
    libcurl4-openssl-dev \
    && rm -rf /var/lib/apt/lists/*

RUN python3 -m pip install --no-cache-dir -U "huggingface_hub[cli]" hf_xet

WORKDIR /opt

RUN git clone --depth 1 https://github.com/ggml-org/llama.cpp.git && \
    cmake -S /opt/llama.cpp -B /opt/llama.cpp/build \
      -DGGML_CUDA=ON \
      -DGGML_CURL=ON \
      -DCMAKE_BUILD_TYPE=Release && \
    cmake --build /opt/llama.cpp/build --config Release -j"$(nproc)" && \
    strip /opt/llama.cpp/build/bin/llama-server || true

COPY run.sh /run.sh
RUN chmod +x /run.sh

EXPOSE 8000

ENTRYPOINT ["/run.sh"]
