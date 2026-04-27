#!/usr/bin/env bash
set -euo pipefail

echo "[1/5] Find llama-server"

SERVER_BIN="/app/llama-server"

if [ ! -x "${SERVER_BIN}" ]; then
  SERVER_BIN="$(command -v llama-server || true)"
fi

if [ -z "${SERVER_BIN}" ] || [ ! -x "${SERVER_BIN}" ]; then
  echo "llama-server not found"
  find / -maxdepth 4 -type f -name "llama-server" 2>/dev/null || true
  exit 1
fi

echo "Using llama-server: ${SERVER_BIN}"
"${SERVER_BIN}" --help | head -n 5 || true

echo "[2/5] Prepare model directory"
mkdir -p "${MODEL_DIR}"

echo "[3/5] Download GGUF from Hugging Face"
python3 - <<'PY'
from huggingface_hub import hf_hub_download
import os

hf_hub_download(
    repo_id=os.environ["MODEL_REPO"],
    filename=os.environ["MODEL_FILE"],
    local_dir=os.environ["MODEL_DIR"],
    token=os.environ.get("HF_TOKEN") or None
)
PY

echo "[4/5] Check downloaded file"
ls -lh "${MODEL_DIR}/${MODEL_FILE}"

echo "[5/5] Start llama-server"
exec "${SERVER_BIN}" \
  -m "${MODEL_DIR}/${MODEL_FILE}" \
  --host 0.0.0.0 \
  --port 8000 \
  --api-key r \
  -c 32768 \
  -ngl 99
