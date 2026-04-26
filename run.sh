#!/usr/bin/env bash
set -euo pipefail

echo "[1/4] Prepare model directory"
mkdir -p "${MODEL_DIR}"

echo "[2/4] Download GGUF from Hugging Face"
python3 - <<'PY'
from huggingface_hub import hf_hub_download
import os

repo_id = os.environ["MODEL_REPO"]
filename = os.environ["MODEL_FILE"]
local_dir = os.environ["MODEL_DIR"]
token = os.environ.get("HF_TOKEN") or None

hf_hub_download(
    repo_id=repo_id,
    filename=filename,
    local_dir=local_dir,
    token=token
)
PY

echo "[3/4] Check downloaded file"
ls -lh "${MODEL_DIR}/${MODEL_FILE}"

echo "[4/4] Start llama-server"
exec /opt/llama.cpp/build/bin/llama-server \
  -m "${MODEL_DIR}/${MODEL_FILE}" \
  --alias qwen36-balanced \
  --host 0.0.0.0 \
  --port 8000 \
  --api-key r \
  --jinja \
  --chat-template-kwargs '{"enable_thinking":false}' \
  -c 32768 \
  -ngl 99 \
  --flash-attn on \
  --cont-batching \
  -b 1024 \
  -ub 512 \
  --temp 0.7 \
  --top-p 0.80 \
  --top-k 20 \
  --min-p 0.0 \
  --presence-penalty 1.5 \
  --repeat-penalty 1.0
