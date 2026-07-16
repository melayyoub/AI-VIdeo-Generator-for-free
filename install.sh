#!/usr/bin/env bash
# Wan 2.2 + ComfyUI installer for macOS and Linux.
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
DRY_RUN="${DRY_RUN:-false}"
EXTRA_REQUIREMENTS="${EXTRA_REQUIREMENTS:-}"

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
    --dry-run=*) DRY_RUN="${arg#*=}";;
    --extra-requirements=*) EXTRA_REQUIREMENTS="${arg#*=}";;
    *) echo "Unknown arg: $arg"; exit 2;;
  esac
done

case "$CUDA" in cu128|cu121|cu118|cpu) ;; *) echo "ERROR: CUDA must be cu128, cu121, cu118, or cpu."; exit 2;; esac
case "$MODELS" in 5b|14b|i2v|all) ;; *) echo "ERROR: MODELS must be 5b, 14b, i2v, or all."; exit 2;; esac
for boolean_name in WITH_MANAGER START LISTEN_ALL REUSE_VENV DRY_RUN; do
  boolean_value="${!boolean_name}"
  case "$boolean_value" in true|false) ;; *) echo "ERROR: $boolean_name must be true or false."; exit 2;; esac
done
[[ "$PORT" =~ ^[0-9]+$ ]] && (( PORT >= 1 && PORT <= 65535 )) || { echo "ERROR: PORT must be between 1 and 65535."; exit 2; }

echo "[install.sh] Base: $BASE_PATH  CUDA: $CUDA  MODELS: $MODELS  Manager: $WITH_MANAGER  Start: $START  Port: $PORT  ListenAll: $LISTEN_ALL  ReuseVenv: $REUSE_VENV  DryRun: $DRY_RUN"

if command -v python3 >/dev/null 2>&1; then PY=python3
elif command -v python >/dev/null 2>&1; then PY=python
else echo "ERROR: Python 3.10–3.12 not found."; exit 1; fi

[[ -n "$HF_TOKEN" ]] && export HF_TOKEN

WITH_MGR_FLAG=(); [[ "$WITH_MANAGER" == "true" ]] && WITH_MGR_FLAG+=(--with-manager)
START_FLAG=();    [[ "$START" == "true" ]] && START_FLAG+=(--start)
LISTEN_FLAG=();   [[ "$LISTEN_ALL" == "true" ]] && LISTEN_FLAG+=(--listen-all)
REUSE_FLAG=();    [[ "$REUSE_VENV" == "true" ]] && REUSE_FLAG+=(--reuse-venv)
DRY_RUN_FLAG=();  [[ "$DRY_RUN" == "true" ]] && DRY_RUN_FLAG+=(--dry-run)
EXTRA_REQUIREMENTS_FLAG=(); [[ -n "$EXTRA_REQUIREMENTS" ]] && EXTRA_REQUIREMENTS_FLAG+=(--extra-requirements "$EXTRA_REQUIREMENTS")

"$PY" "$SCRIPT_DIR/wan2_cli_RTX.py" install \
  --cuda "$CUDA" \
  --path "$BASE_PATH" \
  --models "$MODELS" \
  --port "$PORT" \
  "${WITH_MGR_FLAG[@]}" \
  "${START_FLAG[@]}" \
  "${LISTEN_FLAG[@]}" \
  "${REUSE_FLAG[@]}" \
  "${DRY_RUN_FLAG[@]}" \
  "${EXTRA_REQUIREMENTS_FLAG[@]}"

echo
echo "[install.sh] Done."
echo "Root: $BASE_PATH"
echo "ComfyUI: $BASE_PATH/ComfyUI"
echo "Venv: $BASE_PATH/ComfyUI/.venv"
START_LATER=("$PY" "$SCRIPT_DIR/wan2_cli.py" start --path "$BASE_PATH" --port "$PORT")
[[ "$LISTEN_ALL" == "true" ]] && START_LATER+=(--listen-all)
printf 'Start later:'
printf ' %q' "${START_LATER[@]}"
printf '\n'
