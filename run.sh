#!/usr/bin/env bash
set -Eeuo pipefail

echo "[1/5] Prepare model directory"

# =========================
# Config
# =========================

MODEL_DIR="${MODEL_DIR:-/tmp/models}"

HF_REPO="${HF_REPO:-HauhauCS/Qwen3.6-27B-Uncensored-HauhauCS-Balanced}"
HF_FILE="${HF_FILE:-Qwen3.6-27B-Uncensored-HauhauCS-Balanced-Q5_K_P.gguf}"

MODEL_PATH="${MODEL_PATH:-${MODEL_DIR}/${HF_FILE}}"

HOST="${HOST:-0.0.0.0}"
PORT="${PORT:-8080}"
API_KEY="${API_KEY:-r}"

CTX_SIZE="${CTX_SIZE:-32768}"
BATCH_SIZE="${BATCH_SIZE:-1024}"
UBATCH_SIZE="${UBATCH_SIZE:-512}"
N_GPU_LAYERS="${N_GPU_LAYERS:-99}"

CACHE_TYPE_K="${CACHE_TYPE_K:-q8_0}"
CACHE_TYPE_V="${CACHE_TYPE_V:-q8_0}"

ALIAS="${ALIAS:-qwen3.6-27b-balanced-q5kp-no-thinking}"

mkdir -p "${MODEL_DIR}"

# =========================
# Download model
# =========================

echo "[2/5] Download GGUF from Hugging Face if missing"

if [ -s "${MODEL_PATH}" ]; then
  echo "Model already exists: ${MODEL_PATH}"
else
  echo "Downloading:"
  echo "  repo: ${HF_REPO}"
  echo "  file: ${HF_FILE}"
  echo "  dest: ${MODEL_PATH}"

  if command -v huggingface-cli >/dev/null 2>&1; then
    if [ -n "${HF_TOKEN:-}" ]; then
      huggingface-cli download "${HF_REPO}" "${HF_FILE}" \
        --local-dir "${MODEL_DIR}" \
        --local-dir-use-symlinks False \
        --token "${HF_TOKEN}"
    else
      echo "Warning: HF_TOKEN is not set. Download may be slower or rate-limited."
      huggingface-cli download "${HF_REPO}" "${HF_FILE}" \
        --local-dir "${MODEL_DIR}" \
        --local-dir-use-symlinks False
    fi
  elif command -v curl >/dev/null 2>&1; then
    URL="https://huggingface.co/${HF_REPO}/resolve/main/${HF_FILE}"

    if [ -n "${HF_TOKEN:-}" ]; then
      curl -L --fail --retry 5 --retry-delay 5 -C - \
        -H "Authorization: Bearer ${HF_TOKEN}" \
        -o "${MODEL_PATH}" \
        "${URL}"
    else
      echo "Warning: HF_TOKEN is not set. Download may be slower or rate-limited."
      curl -L --fail --retry 5 --retry-delay 5 -C - \
        -o "${MODEL_PATH}" \
        "${URL}"
    fi
  else
    echo "ERROR: neither huggingface-cli nor curl found."
    exit 1
  fi
fi

# =========================
# Check downloaded file
# =========================

echo "[3/5] Check downloaded file"

if [ ! -s "${MODEL_PATH}" ]; then
  echo "ERROR: model file not found or empty:"
  echo "${MODEL_PATH}"
  echo "Files in ${MODEL_DIR}:"
  ls -lah "${MODEL_DIR}" || true
  exit 1
fi

ls -lh "${MODEL_PATH}"

MODEL_SIZE_BYTES="$(stat -c%s "${MODEL_PATH}" 2>/dev/null || echo 0)"
if [ "${MODEL_SIZE_BYTES}" -lt 1000000000 ]; then
  echo "ERROR: model file is too small. Download may be broken."
  echo "size bytes: ${MODEL_SIZE_BYTES}"
  exit 1
fi

# =========================
# Find llama-server
# =========================

echo "[4/5] Find llama-server"

LLAMA_SERVER=""

if command -v llama-server >/dev/null 2>&1; then
  LLAMA_SERVER="$(command -v llama-server)"
fi

if [ -z "${LLAMA_SERVER}" ] && [ -x /app/llama-server ]; then
  LLAMA_SERVER="/app/llama-server"
fi

if [ -z "${LLAMA_SERVER}" ] && [ -x /usr/local/bin/llama-server ]; then
  LLAMA_SERVER="/usr/local/bin/llama-server"
fi

if [ -z "${LLAMA_SERVER}" ] && [ -x /llama-server ]; then
  LLAMA_SERVER="/llama-server"
fi

if [ -z "${LLAMA_SERVER}" ] && [ -x /opt/llama.cpp/build/bin/llama-server ]; then
  LLAMA_SERVER="/opt/llama.cpp/build/bin/llama-server"
fi

if [ -z "${LLAMA_SERVER}" ]; then
  echo "ERROR: llama-server not found."
  echo "Searching common filesystem locations..."
  find / -type f -name "llama-server" 2>/dev/null | head -50 || true
  exit 1
fi

echo "Using llama-server: ${LLAMA_SERVER}"

# =========================
# Build args safely
# =========================

HELP_TEXT="$("${LLAMA_SERVER}" --help 2>&1 || true)"

has_flag() {
  echo "${HELP_TEXT}" | grep -q -- "$1"
}

ARGS=(
  -m "${MODEL_PATH}"
  --host "${HOST}"
  --port "${PORT}"
  --api-key "${API_KEY}"
  -ngl "${N_GPU_LAYERS}"
  -c "${CTX_SIZE}"
  -b "${BATCH_SIZE}"
  -ub "${UBATCH_SIZE}"
)

if has_flag "--alias"; then
  ARGS+=(--alias "${ALIAS}")
fi

if has_flag "--cont-batching"; then
  ARGS+=(--cont-batching)
fi

if has_flag "--flash-attn"; then
  ARGS+=(--flash-attn on)
elif has_flag "-fa"; then
  ARGS+=(-fa)
fi

if has_flag "--cache-type-k"; then
  ARGS+=(--cache-type-k "${CACHE_TYPE_K}")
elif has_flag "-ctk"; then
  ARGS+=(-ctk "${CACHE_TYPE_K}")
fi

if has_flag "--cache-type-v"; then
  ARGS+=(--cache-type-v "${CACHE_TYPE_V}")
elif has_flag "-ctv"; then
  ARGS+=(-ctv "${CACHE_TYPE_V}")
fi

if has_flag "--jinja"; then
  ARGS+=(--jinja)
fi

if has_flag "--no-mmproj"; then
  ARGS+=(--no-mmproj)
fi

if has_flag "--reasoning"; then
  ARGS+=(--reasoning off)
fi

if has_flag "--chat-template-kwargs"; then
  ARGS+=(--chat-template-kwargs '{"enable_thinking":false}')
fi

# mmap絡みでPod環境によって詰まる場合を避ける
if has_flag "--no-mmap"; then
  ARGS+=(--no-mmap)
fi

# =========================
# Start server
# =========================

echo "[5/5] Start llama-server"
echo "Host: ${HOST}"
echo "Port: ${PORT}"
echo "API key: ${API_KEY}"
echo "Context: ${CTX_SIZE}"
echo "Batch: ${BATCH_SIZE}"
echo "UBatch: ${UBATCH_SIZE}"
echo "Model: ${MODEL_PATH}"
echo "Command:"
printf ' %q' "${LLAMA_SERVER}" "${ARGS[@]}"
echo

exec "${LLAMA_SERVER}" "${ARGS[@]}"
