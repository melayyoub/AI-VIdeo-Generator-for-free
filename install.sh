#!/usr/bin/env bash
# Sam Ayoub — Wan 2.2 + ComfyUI installer (macOS/Linux)
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

CUDA="${CUDA:-cu121}"
MODELS="${MODELS:-5b}"
WITH_MANAGER="${WITH_MANAGER:-true}"
START="${START:-true}"
PORT="${PORT:-8188}"
LISTEN_ALL="${LISTEN_ALL:-false}"
BASE_PATH="${BASE_PATH:-$SCRIPT_DIR}"   # repo will be $BASE_PATH/ComfyUI
HF_TOKEN="${HF_TOKEN:-}"
REUSE_VENV="${REUSE_VENV:-false}"

for arg in "$@"; do
  case $arg in
    --cuda=*) CUDA="${arg#*=}";;
    --models=*) MODELS="${arg#*=}";;
    --with-manager=*) WITH_MANAGER="${arg#*=}";;
    --start=*) START="${arg#*=}";;
    --port=*) PORT="${arg#*=}";;
    --listen-all=*) LISTEN_ALL="${arg#*=}";;
    --path=*) BASE_PATH="${arg#*=}";;
    --reuse-venv=*) REUSE_VENV="${arg#*=}";;
    *) echo "Unknown arg: $arg"; exit 2;;
  esac
done

echo "[install.sh] Base: $BASE_PATH  CUDA: $CUDA  MODELS: $MODELS  Manager: $WITH_MANAGER  Start: $START  Port: $PORT  ListenAll: $LISTEN_ALL  ReuseVenv: $REUSE_VENV"

if command -v python3 >/dev/null 2>&1; then PY=python3
elif command -v python >/dev/null 2>&1; then PY=python
else echo "ERROR: Python 3.10–3.12 not found."; exit 1; fi

[[ -n "$HF_TOKEN" ]] && export HF_TOKEN

WITH_MGR_FLAG=(); [[ "$WITH_MANAGER" == "true" ]] && WITH_MGR_FLAG+=(--with-manager)
START_FLAG=();    [[ "$START" == "true" ]] && START_FLAG+=(--start)
LISTEN_FLAG=();   [[ "$LISTEN_ALL" == "true" ]] && LISTEN_FLAG+=(--listen-all)
REUSE_FLAG=();    [[ "$REUSE_VENV" == "true" ]] && REUSE_FLAG+=(--reuse-venv)

"$PY" "$SCRIPT_DIR/wan2_cli.py" install \
  --cuda "$CUDA" \
  --path "$BASE_PATH" \
  --models "$MODELS" \
  --port "$PORT" \
  "${WITH_MGR_FLAG[@]}" \
  "${START_FLAG[@]}" \
  "${LISTEN_FLAG[@]}" \
  "${REUSE_FLAG[@]}"

echo
echo "[install.sh] Done."
echo "Root: $BASE_PATH"
echo "ComfyUI: $BASE_PATH/ComfyUI"
echo "Venv: $BASE_PATH/ComfyUI/.venv"
echo "Start later: $PY \"$SCRIPT_DIR/wan2_cli.py\" start --path \"$BASE_PATH\" --port $PORT ${LISTEN_ALL:+--listen-all}"
