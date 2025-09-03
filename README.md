# Wan 2.2 + ComfyUI Bootstrap CLI
**Author:** Sam Ayoub  
**Copyright:** © 2025 Sam Ayoub  
**License:** MIT

A clean, cross-platform setup for **ComfyUI + Wan 2.2** with an optional **React loader**.  
Includes a single-file CLI (`wan2_cli.py`) and one-command installers for macOS/Linux and Windows PowerShell.

---

## ✨ Features

- 🔧 One-shot install: venv, **PyTorch** (CUDA 12.1 / 11.8 / CPU), **ComfyUI**, optional **ComfyUI-Manager**
- ⬇️ Automated **Wan 2.2** model downloads (5B, 14B, I2V, or **all**)
- ⚛️ Optional **React loader** (Vite + TS) that waits for ComfyUI to be ready
- 🚀 Start ComfyUI on any port; bind to `0.0.0.0` for LAN/remote
- 🧰 Idempotent: re-runs safely; skips what’s already done
- 🖥️ Cross-platform: macOS/Linux (bash) and Windows (PowerShell)

---

## 🧱 Project Layout

**
<your-dir>/
wan2_cli.py # The main CLI (Python, MIT license)
install.sh # macOS/Linux installer wrapper
install.ps1 # Windows PowerShell installer wrapper
README.md # This file
(after install)
ComfyStack/
ComfyUI/
.venv/ # Virtual environment
models/
diffusion_models/
vae/
text_encoders/
custom_nodes/
ComfyUI-Manager/ (optional)
comfy-loader/ # Optional React loader app
**


---

## 🖥️ Prerequisites

- **Python** 3.10–3.12
- **Git**
- **Node.js** + **npm**
- **ffmpeg**
- (Windows only) recent **NVIDIA driver** if using CUDA wheels
- (Optional) **Hugging Face token** `HF_TOKEN` if model access is gated

---

## 🚀 Quick Start (macOS/Linux)

```bash
# Make scripts executable (first time only):
chmod +x install.sh

# Run with defaults (CUDA 12.1, 5B models, install Manager, start ComfyUI on 8188)
source ./install.sh

# Or override quickly:
CUDA=cpu MODELS=all START=true PORT=8188 WITH_MANAGER=true source ./install.sh

Verifying the Install

ComfyUI API:

curl http://127.0.0.1:8188/system_stats
curl http://127.0.0.1:8188/queue


React loader (if created):
cd ComfyStack/comfy-loader && npm run dev and open the printed URL.

| Variable (bash)  | Parameter (PS) | Meaning                               |
| ---------------- | -------------- | ------------------------------------- |
| `CUDA`           | `-Cuda`        | `cu121`, `cu118`, or `cpu`            |
| `MODELS`         | `-Models`      | `5b`, `14b`, `i2v`, or `all`          |
| `WITH_MANAGER`   | `-WithManager` | `true`/`false`                        |
| `START`          | `-Start`       | `true`/`false`                        |
| `PORT`           | `-Port`        | Port number (default `8188`)          |
| `LISTEN_ALL`     | `-ListenAll`   | `true`/`false`                        |
| `BASE_PATH`      | `-BasePath`    | Install root (default `~/ComfyStack`) |
| *(Windows only)* | `-PyVersion`   | Python launcher version, e.g. `3.11`  |



