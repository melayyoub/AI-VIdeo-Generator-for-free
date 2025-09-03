#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
wan2_cli.py — ComfyUI + Wan 2.2 setup CLI
Copyright (c) 2025 Sam Ayoub
License: MIT

This tool bootstraps ComfyUI + Wan 2.2 models, optional React loader app,
and can launch ComfyUI. Works on Linux/macOS (bash) and Windows (PowerShell).

Usage examples:
  # Linux/macOS
  python wan2_cli.py install --cuda cu121 --models 5b --with-manager --start
  python wan2_cli.py install --cuda cpu --models 14b --react --path ~/ComfyStack
  python wan2_cli.py models --models all
  python wan2_cli.py start --port 8188

  # Windows (PowerShell)
  py -3.11 wan2_cli.py install --cuda cu118 --models i2v --with-manager --start
  py -3.11 wan2_cli.py react --name comfy-loader

Notes:
  * Requires: Python 3.10–3.12, git, node + npm, and ffmpeg installed.
  * For Hugging Face gated models, set HF token either via --hf-token or env HF_TOKEN.
"""

import argparse
import os
import platform
import shutil
import subprocess
import sys
from pathlib import Path
from textwrap import dedent

APP_NAME = "wan2_cli"
DEFAULT_DIR = Path.home() / "ComfyStack"
COMFY_DIR = "ComfyUI"
VENV_DIR = ".venv"
DEFAULT_PORT = 8188

WAN_REPO = "Comfy-Org/Wan_2.2_ComfyUI_Repackaged"

DIFFUSION_FILES = {
    "5b": [
        "split_files/diffusion_models/wan2.2_ti2v_5B_fp16.safetensors",
    ],
    "14b": [
        "split_files/diffusion_models/wan2.2_t2v_high_noise_14B_fp8_scaled.safetensors",
        "split_files/diffusion_models/wan2.2_t2v_low_noise_14B_fp8_scaled.safetensors",
    ],
    "i2v": [
        "split_files/diffusion_models/wan2.2_i2v_high_noise_14B_fp8_scaled.safetensors",
        "split_files/diffusion_models/wan2.2_i2v_low_noise_14B_fp8_scaled.safetensors",
    ],
}
VAE_FILES = [
    "split_files/vae/wan_2.1_vae.safetensors",
    "split_files/vae/wan2.2_vae.safetensors",
]
TEXT_ENCODERS = [
    "split_files/text_encoders/umt5_xxl_fp8_e4m3fn_scaled.safetensors",
]

def log(msg: str):
    print(f"[{APP_NAME}] {msg}")

def run(cmd, cwd=None, env=None, check=True, dry=False):
    log(("DRYRUN: " if dry else "") + " ".join(cmd))
    if dry:
        return 0
    result = subprocess.run(cmd, cwd=str(cwd) if cwd else None, env=env)
    if check and result.returncode != 0:
        raise RuntimeError(f"Command failed: {' '.join(cmd)}")
    return result.returncode

def is_windows():
    return platform.system().lower().startswith("win")

def py_exec(py_ver=None, venv_bin: Path | None = None):
    if venv_bin:
        return str(venv_bin / ("python.exe" if is_windows() else "python"))
    if is_windows():
        return "py" + (f"-{py_ver}" if py_ver else "")
    return "python"  # on posix

def ensure_tools():
    for tool in ["git", "node", "npm", "ffmpeg"]:
        if shutil.which(tool) is None:
            log(f"WARNING: '{tool}' not found in PATH. Please install it.")

def create_dirs(base: Path, dry=False):
    for p in [
        base,
        base / COMFY_DIR,
        base / COMFY_DIR / "models" / "diffusion_models",
        base / COMFY_DIR / "models" / "vae",
        base / COMFY_DIR / "models" / "text_encoders",
        base / COMFY_DIR / "custom_nodes",
    ]:
        if not p.exists():
            log(f"Creating {p}")
            if not dry:
                p.mkdir(parents=True, exist_ok=True)

def create_venv(base: Path, py_ver: str | None, dry=False):
    comfy = base / COMFY_DIR
    venv = comfy / VENV_DIR
    if (venv / ("Scripts" if is_windows() else "bin")).exists():
        log("Venv already exists — skipping.")
        return venv
    cmd = [py_exec(py_ver), "-m", "venv", str(venv)]
    run(cmd, cwd=comfy, dry=dry)
    return venv

def pip(venv: Path, args: list[str], cwd: Path | None = None, dry=False):
    pip_cmd = [py_exec(venv_bin=venv / ("Scripts" if is_windows() else "bin")), "-m", "pip"] + args
    return run(pip_cmd, cwd=cwd, dry=dry)

def activate_hint(venv: Path) -> str:
    if is_windows():
        return str(venv / "Scripts" / "Activate.ps1")
    return f"source {venv}/bin/activate"

def install_torch(venv: Path, cuda: str, dry=False):
    idx_map = {
        "cu121": "https://download.pytorch.org/whl/cu121",
        "cu118": "https://download.pytorch.org/whl/cu118",
        "cpu":   "https://download.pytorch.org/whl/cpu",
    }
    if cuda not in idx_map:
        raise ValueError("--cuda must be one of cu121|cu118|cpu")
    pip(venv, ["install", "-U", "pip", "setuptools", "wheel"], dry=dry)
    pip(venv, ["install", "torch", "torchvision", "torchaudio", "--index-url", idx_map[cuda]], dry=dry)

def clone_comfy(base: Path, dry=False):
    comfy = base / COMFY_DIR
    if (comfy / ".git").exists():
        log("ComfyUI already cloned — pulling latest.")
        run(["git", "pull", "--ff-only"], cwd=comfy, dry=dry)
    else:
        run(["git", "clone", "https://github.com/comfyanonymous/ComfyUI.git", str(comfy)], dry=dry)

def install_comfy_requirements(venv: Path, base: Path, dry=False):
    comfy = base / COMFY_DIR
    pip(venv, ["install", "-r", "requirements.txt"], cwd=comfy, dry=dry)

def install_manager(venv: Path, base: Path, dry=False):
    npath = base / COMFY_DIR / "custom_nodes" / "ComfyUI-Manager"
    if npath.exists():
        log("ComfyUI-Manager already present — skipping.")
        return
    run(["git", "clone", "https://github.com/Comfy-Org/ComfyUI-Manager.git", str(npath)], dry=dry)

def install_hf_cli(venv: Path, dry=False):
    pip(venv, ["install", "huggingface_hub[cli]"], dry=dry)

def hf_login(venv: Path, token: str | None, dry=False):
    if token:
        env = os.environ.copy()
        env["HF_TOKEN"] = token
        run([py_exec(venv_bin=venv / ("Scripts" if is_windows() else "bin")), "-m", "huggingface_hub", "whoami"], env=env, dry=dry, check=False)
        return
    # Interactive login
    run(["huggingface-cli", "login"], dry=dry)

def hf_download(venv: Path, repo_id: str, files: list[str], dest: Path, dry=False):
    for f in files:
        run(["huggingface-cli", "download", repo_id, f, "--local-dir", str(dest)], dry=dry)

def download_models(venv: Path, base: Path, which: str, dry=False):
    comfy = base / COMFY_DIR
    models_root = comfy / "models"
    dm = models_root / "diffusion_models"
    vae = models_root / "vae"
    te = models_root / "text_encoders"

    selected = []
    if which == "5b":
        selected = DIFFUSION_FILES["5b"]
    elif which == "14b":
        selected = DIFFUSION_FILES["14b"]
    elif which == "i2v":
        selected = DIFFUSION_FILES["i2v"]
    elif which == "all":
        selected = DIFFUSION_FILES["5b"] + DIFFUSION_FILES["14b"] + DIFFUSION_FILES["i2v"]
    else:
        raise ValueError("--models must be one of 5b|14b|i2v|all")

    install_hf_cli(venv, dry=dry)
    # Try non-interactive if HF_TOKEN is set; otherwise login prompt
    if not os.environ.get("HF_TOKEN"):
        log("Tip: export HF_TOKEN to avoid interactive login when models are gated.")
    hf_login(venv, token=os.environ.get("HF_TOKEN"), dry=dry)

    hf_download(venv, WAN_REPO, selected, dm, dry=dry)
    hf_download(venv, WAN_REPO, VAE_FILES, vae, dry=dry)
    hf_download(venv, WAN_REPO, TEXT_ENCODERS, te, dry=dry)

def make_react(base: Path, app_name: str, comfy_url: str, dry=False):
    target = base / app_name
    if target.exists():
        log(f"React app '{app_name}' already exists — skipping scaffold.")
        return target
    run(["npm", "create", "vite@latest", app_name, "--", "--template", "react-ts"], cwd=base, dry=dry)
    run(["npm", "i"], cwd=target, dry=dry)
    run(["npm", "i", "axios"], cwd=target, dry=dry)
    # write .env
    env_path = target / ".env"
    content = f"VITE_COMFY_BASE_URL={comfy_url}\n"
    if not dry:
        env_path.write_text(content, encoding="utf-8")
    log(f"Wrote {env_path}")

    # Replace App.tsx with loader
    app_tsx = target / "src" / "App.tsx"
    loader = dedent("""
        import { useEffect, useState } from "react";
        const API = import.meta.env.VITE_COMFY_BASE_URL ?? "http://127.0.0.1:8188";
        type Stats = Record<string, any> | null;

        export default function App() {
          const [ready, setReady] = useState(false);
          const [stats, setStats] = useState<Stats>(null);
          useEffect(() => {
            const id = setInterval(async () => {
              try {
                const r = await fetch(`${API}/system_stats`);
                if (r.ok) { setStats(await r.json()); setReady(true); clearInterval(id); }
              } catch {}
            }, 1000);
            return () => clearInterval(id);
          }, []);
          return (
            <div style={{fontFamily:"system-ui",padding:24}}>
              <h1>ComfyUI Loader</h1>
              {!ready ? <p>Starting ComfyUI…</p> : <pre>{JSON.stringify(stats, null, 2)}</pre>}
            </div>
          );
        }
    """).strip()
    if not dry:
        app_tsx.write_text(loader, encoding="utf-8")
    log(f"Wrote loader UI to {app_tsx}")
    return target

def start_comfy(venv: Path, base: Path, port: int, listen_all: bool, dry=False):
    comfy = base / COMFY_DIR
    pybin = py_exec(venv_bin=venv / ("Scripts" if is_windows() else "bin"))
    args = [pybin, "main.py", "--port", str(port)]
    if listen_all:
        args += ["--listen"]
    log(f"Starting ComfyUI on port {port}...")
    run(args, cwd=comfy, dry=dry, check=False)
    log("ComfyUI process exited.")

def main():
    parser = argparse.ArgumentParser(prog=APP_NAME, description="ComfyUI + Wan 2.2 setup CLI (© 2025 Sam Ayoub, MIT).")
    sub = parser.add_subparsers(dest="cmd", required=True)

    common = argparse.ArgumentParser(add_help=False)
    common.add_argument("--path", type=Path, default=DEFAULT_DIR, help=f"Base directory (default: {DEFAULT_DIR})")
    common.add_argument("--dry-run", action="store_true", help="Print commands without executing")
    common.add_argument("--verbose", action="store_true", help="(Reserved) Verbose logging")

    # install
    p_install = sub.add_parser("install", parents=[common], help="Full install: venv + torch + ComfyUI (+manager opt).")
    p_install.add_argument("--python", dest="pyver", default=None, help="Python launcher version (Windows only), e.g. 3.11")
    p_install.add_argument("--cuda", choices=["cu121", "cu118", "cpu"], required=True, help="Torch build to install")
    p_install.add_argument("--with-manager", action="store_true", help="Install ComfyUI-Manager")
    p_install.add_argument("--models", choices=["5b", "14b", "i2v", "all"], default=None, help="Download Wan 2.2 model set")
    p_install.add_argument("--hf-token", default=None, help="Hugging Face token (if needed)")
    p_install.add_argument("--start", action="store_true", help="Start ComfyUI when done")
    p_install.add_argument("--port", type=int, default=DEFAULT_PORT, help=f"ComfyUI port (default {DEFAULT_PORT})")
    p_install.add_argument("--listen-all", action="store_true", help="Bind 0.0.0.0 (remote access)")

    # models only
    p_models = sub.add_parser("models", parents=[common], help="Download/refresh Wan 2.2 model files.")
    p_models.add_argument("--models", choices=["5b", "14b", "i2v", "all"], required=True)
    p_models.add_argument("--hf-token", default=None, help="Hugging Face token (if needed)")

    # react
    p_react = sub.add_parser("react", parents=[common], help="Create a React loader app.")
    p_react.add_argument("--name", default="comfy-loader", help="Folder/app name (default comfy-loader)")
    p_react.add_argument("--url", default=f"http://127.0.0.1:{DEFAULT_PORT}", help="Comfy base URL for the app")

    # start
    p_start = sub.add_parser("start", parents=[common], help="Run ComfyUI.")
    p_start.add_argument("--port", type=int, default=DEFAULT_PORT)
    p_start.add_argument("--listen-all", action="store_true")

    args = parser.parse_args()
    dry = args.dry_run

    if args.cmd in ("install", "models") and args.hf_token:
        os.environ["HF_TOKEN"] = args.hf_token

    ensure_tools()

    base: Path = args.path.expanduser().resolve()
    create_dirs(base, dry=dry)

    if args.cmd == "install":
        clone_comfy(base, dry=dry)
        venv = create_venv(base, args.pyver, dry=dry)
        install_torch(venv, args.cuda, dry=dry)
        install_comfy_requirements(venv, base, dry=dry)
        if args.with_manager:
            install_manager(venv, base, dry=dry)
        if args.models:
            download_models(venv, base, args.models, dry=dry)
        log(f"Done. To activate venv: {activate_hint(venv)}")
        if args.start:
            start_comfy(venv, base, args.port, args.listen_all, dry=dry)

    elif args.cmd == "models":
        venv = base / COMFY_DIR / VENV_DIR
        download_models(venv, base, args.models, dry=dry)
        log("Models downloaded.")

    elif args.cmd == "react":
        target = make_react(base, args.name, args.url, dry=dry)
        if target:
            log(f"React app created at: {target}")
            log("Run it with: npm run dev (inside the app directory)")

    elif args.cmd == "start":
        venv = base / COMFY_DIR / VENV_DIR
        start_comfy(venv, base, args.port, args.listen_all, dry=dry)

if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        log("Interrupted by user.")
    except Exception as e:
        log(f"ERROR: {e}")
        sys.exit(1)
