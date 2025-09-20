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

```
# bash
pip install torch==2.5.1+cu121 torchvision==0.20.1+cu121 torchaudio==2.5.1+cu121 --index-url https://download.pytorch.org/whl/cu121

# From the folder containing install.sh + wan2_cli.py:
chmod +x install.sh

# Default (same folder), create fresh venv, start after install
./install.sh

# CPU-only, all models, do not auto-start
CUDA=cpu MODELS=all START=false ./install.sh

# If directory isn’t empty and you want to force same-folder clone:
FORCE_HERE=true ./install.sh

# Reuse existing .venv
REUSE_VENV=true ./install.sh
```
# Or override quickly:
CUDA=cpu MODELS=all START=true PORT=8188 WITH_MANAGER=true source ./install.sh

Verifying the Install

ComfyUI API:

curl http://127.0.0.1:8188/system_stats
curl http://127.0.0.1:8188/queue
```
```
# WIN/PowerShell
# Confirm the venv python & package are the ones used
.\.venv\Scripts\python.exe -c "import sys, importlib; print(sys.executable); print(importlib.util.find_spec('huggingface_hub') is not None)"

# From the folder containing install.ps1 + wan2_cli.py:
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
 # From E:\python-projects\custom-wan (where wan2_cli.py lives)
.\install.ps1 -Cuda cu121 -Models 5b -WithManager -Start
# This will create/refresh: E:\python-projects\custom-wan\ComfyUI and ComfyUI\.venv

# Either activate:
.\ComfyUI\.venv\Scripts\Activate.ps1
python .\ComfyUI\main.py --port 8188 --listen

# Or run directly:
.\ComfyUI\.venv\Scripts\python.exe .\ComfyUI\main.py --port 8188 --listen


## or 

# Activate the venv
.\.venv\Scripts\Activate.ps1

# Start ComfyUI (default port 8188, adjust if you want)
python wan2_cli.py start --path . --port 8188 --listen-all



```

Start later (no reinstall)

```powershell
# from your base path
.\ComfyUI\.venv\Scripts\python.exe .\ComfyUI\main.py --port 8188 --listen
# or via CLI:
py -3.11 .\wan2_cli.py start --path . --port 8188 --listen-all
```
```mac
./ComfyUI/.venv/bin/python ./ComfyUI/main.py --port 8188 --listen
# or via CLI:
python3 wan2_cli.py start --path . --port 8188 --listen-all

```

**


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

**

## RTX high end GPU better to use  wan2_cli_RTX.py

```

.\ComfyUI\.venv\Scripts\python.exe wan2_cli_RTX.py start --path . --port 8188


or 

.\ComfyUI\.venv\Scripts\activate
python wan2_cli_RTX.py start --path . --port 8188

```