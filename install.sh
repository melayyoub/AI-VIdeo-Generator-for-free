
---

## 🧰 `install.sh` (macOS/Linux)

```bash
#!/usr/bin/env bash
# Sam Ayoub — Wan 2.2 + ComfyUI installer (macOS/Linux)
set -euo pipefail

# ── Defaults (override via env or flags) ───────────────────────────────────────
CUDA="${CUDA:-cu121}"            # cu121 | cu118 | cpu
MODELS="${MODELS:-5b}"           # 5b | 14b | i2v | all
WITH_MANAGER="${WITH_MANAGER:-true}"
START="${START:-true}"
PORT="${PORT:-8188}"
LISTEN_ALL="${LISTEN_ALL:-false}"
BASE_PATH="${BASE_PATH:-$HOME/ComfyStack}"
HF_TOKEN="${HF_TOKEN:-}"

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
    *) echo "Unknown arg: $arg"; exit 2;;
  esac
done

# ── Run CLI ───────────────────────────────────────────────────────────────────
echo "[install.sh] Base: $BASE_PATH  CUDA: $CUDA  MODELS: $MODELS  Manager: $WITH_MANAGER  Start: $START  Port: $PORT  ListenAll: $LISTEN_ALL"

if [[ -n "$HF_TOKEN" ]]; then
  export HF_TOKEN
fi

WITH_MGR_FLAG=()
if [[ "$WITH_MANAGER" == "true" ]]; then WITH_MGR_FLAG+=(--with-manager); fi

START_FLAG=()
if [[ "$START" == "true" ]]; then START_FLAG+=(--start); fi

LISTEN_FLAG=()
if [[ "$LISTEN_ALL" == "true" ]]; then LISTEN_FLAG+=(--listen-all); fi

# Ensure python exists
if ! command -v python >/dev/null 2>&1; then
  echo "ERROR: 'python' not found in PATH. Please install Python 3.10–3.12."; exit 1
fi

# Install
python wan2_cli.py install \
  --cuda "$CUDA" \
  --path "$BASE_PATH" \
  "${WITH_MGR_FLAG[@]}" \
  --models "$MODELS" \
  "${START_FLAG[@]}" \
  --port "$PORT" \
  "${LISTEN_FLAG[@]}"

echo
echo "[install.sh] Done."
echo "ComfyUI root: $BASE_PATH/ComfyUI"
echo "React loader: $BASE_PATH/comfy-loader (if you run: python wan2_cli.py react --path \"$BASE_PATH\")"
echo "To start later: python wan2_cli.py start --path \"$BASE_PATH\" --port $PORT ${LISTEN_ALL:+--listen-all}"
