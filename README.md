# Wan 2.2 + ComfyUI Bootstrap CLI
**Author:** Sam Ayoub  
**License:** MIT — © 2025 Sam Ayoub

A clean, cross-platform installer + launcher for **ComfyUI + Wan 2.2**, with optional **ComfyUI-Manager** and **React Loader UI**.  
Includes both Windows PowerShell and macOS/Linux setup support.

---

## ✨ Features

- 🔧 **One-shot environment setup** (venv + PyTorch + ComfyUI)
- 🎛️ Supports **CUDA 12.8 / 12.5 / 12.4 / 12.1 / 11.8** and **CPU**
- ⬇️ Automated **Wan 2.2 model downloads**:
  - `5b` (T→V base)
  - `14b` high/low noise (cinematic long shots)
  - `i2v` (Image → Video motion)
  - or **`all`**
- 🧩 Optional **ComfyUI-Manager** for nodes/plugins
- ⚛️ Optional **React Loader UI** (Vite + TypeScript)
- 🌐 Bind to `0.0.0.0` for LAN/remote system access
- ♻️ Idempotent: re-run safely, only updates what's needed
- 💻 Works on **Windows, macOS, and Linux**

---

## 📂 Project Layout

<your-directory>/
│ README.md
│ wan2_cli.py # Main CLI
│ install.ps1 # Windows installer wrapper
│ install.sh # macOS/Linux installer wrapper
│
└─ ComfyUI/ # Auto-created on install
├─ .venv/ # Virtual environment
├─ main.py
├─ requirements.txt
└─ models/
├─ diffusion_models/
├─ vae/
└─ text_encoders/
└─ custom_nodes/
└─ ComfyUI-Manager/ # Optional
└─ comfy-loader/ # Optional React Loader UI



---

## 🖥️ Requirements

| Requirement | Notes |
|------------|-------|
| **Python 3.10 recommended** | (3.11 ok • **avoid 3.12** for now) |
| Git | Required |
| Node.js + npm | Only for React loader |
| ffmpeg | Required for video workflows |
| NVIDIA GPU (optional) | For CUDA acceleration |
| `HF_TOKEN` (optional) | Required for gated Wan model repos |

---

## 🚀 Quick Start — Windows (PowerShell)

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass

# From folder where wan2_cli.py is located:
.\install.ps1 -Cuda cu121 -Models all -WithManager -Start -PyVersion 3.10

or: 

.\install.ps1 -Cuda cu128 -Models all -WithManager -Start -PyVersion 3.10

<your-directory>/
│ README.md
│ wan2_cli.py # Main CLI
│ install.ps1 # Windows installer wrapper
│ install.sh # macOS/Linux installer wrapper
│
└─ ComfyUI/ # Auto-created on install
├─ .venv/ # Virtual environment
├─ main.py
├─ requirements.txt
└─ models/
├─ diffusion_models/
├─ vae/
└─ text_encoders/
└─ custom_nodes/
└─ ComfyUI-Manager/ # Optional
└─ comfy-loader/ # Optional React Loader UI

This creates:

ComfyUI/
ComfyUI/.venv/
models/

Start ComfyUI later:
.\ComfyUI\.venv\Scripts\python.exe .\ComfyUI\main.py --port 8188 --listen

Or via the CLI:
py -3.10 .\wan2_cli.py start --path . --port 8188 --listen-all


🚀 Quick Start — macOS / Linux
chmod +x install.sh
./install.sh

Example overrides:
CUDA=cpu MODELS=all START=false ./install.sh
REUSE_VENV=true ./install.sh
PORT=9000 START=true WITH_MANAGER=true ./install.sh

✅ Verify Install
curl http://127.0.0.1:8188/system_stats


Open UI:

http://127.0.0.1:8188

⚛️ React Loader UI (Optional)
cd comfy-loader
npm install
npm run dev

🎮 Parameter Reference (CLI)
Bash Variable	PowerShell Arg	Description
CUDA	-Cuda	cu128, cu125, cu124, cu121, cu118, cpu
MODELS	-Models	5b, 14b, i2v, all
WITH_MANAGER	-WithManager	Install ComfyUI-Manager
START	-Start	Start after setup
PORT	-Port	Default: 8188
LISTEN_ALL	-ListenAll	Bind to 0.0.0.0
(Windows only)	-PyVersion	Set Python version (e.g., 3.10)
🔥 RTX High-End GPU Users (4090 / 5090 / A6000)
.\ComfyUI\.venv\Scripts\python.exe wan2_cli_RTX.py start --path . --port 8188


or:

.\ComfyUI\.venv\Scripts\activate
python wan2_cli.py start --path . --port 8188




🏁 Done

You now have a clean, structured, consistent Wan 2.2 + ComfyUI environment,
ready for cinematic video generation.