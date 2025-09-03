#!/usr/bin/env bash
# Sam Ayoub — Wan 2.2 + ComfyUI installer (macOS/Linux)
set -euo pipefail

# Determine script dir (same-location layout by default)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── Defaults (override via env or flags) ───────────────────────────────────────
CUDA="${CUDA:-cu121}"            # cu121 | cu118 | cpu
MODELS="${MODELS:-5b}"           # 5b | 14b | i2v | all
WITH_MANAGER="${WITH_MANAGER:-true}"
START="${START:-true}"
PORT="${PORT:-8188}"
LISTEN_ALL="${LISTEN_ALL:-false}"
BASE_PATH="${BASE_PATH:-$SCRIPT_DIR}"
HF_TOKEN="${HF_TOKEN:-}"
FORCE_HERE="${FORCE_HERE:-false}"
REUSE_VENV="${REUSE_VENV:-false}"

# parse simple --key=value overrides if desired
for arg in "$@"; do
  case $arg in
    --cuda=*) CUDA="${arg#*=}";;
    --models=*) MODELS="${arg#*=}";;
    --with-manager=*) WITH_MANAGER="${arg#*=}";;
    --start=*) START="${arg#*=}";;
    --port=*) PORT="${arg#*=}";;
    --listen-all=*) LISTEN_ALL="${arg#*=}";;
    --path=*) BASE_PATH="${arg#*=}";;
    --force-here=*) FORCE_HERE="${arg#*=}";;
    --reuse-venv=*) REUSE_VENV="${arg#*=}";;
    *) echo "Unknown arg: $arg"; exit 2;;
  esac
done

echo "[install.sh] Base: $BASE_PATH  CUDA: $CUDA  MODELS: $MODELS  Manager: $WITH_MANAGER  Start: $START  Port: $PORT  ListenAll: $LISTEN_ALL  ForceHere: $FORCE_HERE  ReuseVenv: $REUSE_VENV"

# Choose python executable
if command -v python3 >/dev/null 2>&1; then
  PY=python3
elif command -v python >/dev/null 2>&1; then
  PY=python
else
  echo "ERROR: Python 3.10–3.12 not found in PATH."; exit 1
fi

# Token (optional)
if [[ -n "$HF_TOKEN" ]]; then
  export HF_TOKEN
fi

WITH_MGR_FLAG=()
[[ "$WITH_MANAGER" == "true" ]] && WITH_MGR_FLAG+=(--with-manager)

START_FLAG=()
[[ "$START" == "true" ]] && START_FLAG+=(--start)

LISTEN_FLAG=()
[[ "$LISTEN_ALL" == "true" ]] && LISTEN_FLAG+=(--listen-all)

FORCE_FLAG=()
[[ "$FORCE_HERE" == "true" ]] && FORCE_FLAG+=(--force-here)

REUSE_FLAG=()
[[ "$REUSE_VENV" == "true" ]] && REUSE_FLAG+=(--reuse-venv)

# Install
"$PY" "$SCRIPT_DIR/wan2_cli.py" install \
  --cuda "$CUDA" \
  --path "$BASE_PATH" \
  --models "$MODELS" \
  --port "$PORT" \
  "${WITH_MGR_FLAG[@]}" \
  "${START_FLAG[@]}" \
  "${LISTEN_FLAG[@]}" \
  "${FORCE_FLAG[@]}" \
  "${REUSE_FLAG[@]}"

echo
echo "[install.sh] Done."
echo "Root: $BASE_PATH"
echo "Venv: $BASE_PATH/.venv"
echo "To start later: $PY \"$SCRIPT_DIR/wan2_cli.py\" start --path \"$BASE_PATH\" --port $PORT ${LISTEN_ALL:+--listen-all}"
