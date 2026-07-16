#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
wan2_cli.py — ComfyUI + Wan 2.2 setup CLI (Subfolder Layout)

Layout (ALWAYS under <base>/ComfyUI):
  <base>/ComfyUI               # ComfyUI repo
  <base>/ComfyUI/.venv         # virtual environment
  <base>/ComfyUI/models/**     # models
"""

from __future__ import annotations

import argparse
import os
import platform
import shutil
import subprocess
import sys
import time
from pathlib import Path
from textwrap import dedent
from typing import Optional, List

APP_NAME = "wan2_cli"
DEFAULT_DIR = Path.cwd()  # default to current folder as base
COMFY_DIR = "ComfyUI"  # enforced subfolder for repo
VENV_DIR = ".venv"
DEFAULT_PORT = 8188

WAN_REPO = "Comfy-Org/Wan_2.2_ComfyUI_Repackaged"

DIFFUSION_FILES = {
    "5b": ["split_files/diffusion_models/wan2.2_ti2v_5B_fp16.safetensors"],
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


# ------------------------------ helpers ---------------------------------------


def log(msg: str) -> None:
    print(f"[{APP_NAME}] {msg}")


def is_windows() -> bool:
    return platform.system().lower().startswith("win")


def run(
    cmd: List[str],
    cwd: Optional[Path] = None,
    env: Optional[dict] = None,
    check: bool = True,
    dry: bool = False,
) -> int:
    shown_cwd = f" (cwd={cwd})" if cwd else ""
    log(("DRYRUN: " if dry else "") + " ".join(map(str, cmd)) + shown_cwd)
    if dry:
        return 0
    result = subprocess.run(cmd, cwd=str(cwd) if cwd else None, env=env)
    if check and result.returncode != 0:
        raise RuntimeError(f"Command failed: {' '.join(map(str, cmd))}")
    return result.returncode


def py_exec(venv_bin: Path) -> str:
    return str(venv_bin / ("python.exe" if is_windows() else "python"))


def base_python_command(py_ver: Optional[str] = None) -> List[str]:
    if is_windows() and py_ver:
        return ["py", f"-{py_ver}"]
    base_executable = getattr(sys, "_base_executable", None) or sys.executable
    return [str(Path(base_executable).resolve())]


def ensure_tools() -> None:
    for tool in ["git", "node", "npm", "ffmpeg"]:
        if shutil.which(tool) is None:
            log(f"WARNING: '{tool}' not found in PATH. Please install it.")


def ensure_base_dir(base: Path, dry: bool = False) -> None:
    if not base.exists():
        log(f"Creating {base}")
        if not dry:
            base.mkdir(parents=True, exist_ok=True)


def comfy_root(base: Path) -> Path:
    return base / COMFY_DIR


# --------------------------- clone ComfyUI (subfolder) ------------------------


def clone_comfy(base: Path, dry: bool = False) -> None:
    """
    Ensure ComfyUI exists at <base>/ComfyUI ONLY.
    - If <base>/ComfyUI doesn't exist -> clone there.
    - If exists and is a git repo -> git pull.
    - If exists, empty dir -> clone into '.' with cwd=comfy.
    - If exists and non-empty & not a repo -> raise a clear error.
    """
    comfy = comfy_root(base)
    if comfy.exists():
        if (comfy / ".git").exists():
            log("ComfyUI already cloned — pulling latest.")
            run(["git", "pull", "--ff-only"], cwd=comfy, dry=dry)
            return
        # not a repo: check if empty
        try:
            is_empty = next(comfy.iterdir(), None) is None
        except PermissionError:
            is_empty = False
        if is_empty:
            log("Empty ComfyUI/ dir — cloning into it.")
            run(
                ["git", "clone", "https://github.com/comfyanonymous/ComfyUI.git", "."],
                cwd=comfy,
                dry=dry,
            )
            return
        raise RuntimeError(
            f"'{comfy}' exists and is not a git repo. Delete it or choose a different --path."
        )
    # folder not present: clone into subfolder
    run(
        ["git", "clone", "https://github.com/comfyanonymous/ComfyUI.git", str(comfy)],
        dry=dry,
    )


# ------------------------------ venv handling ---------------------------------


def recreate_venv(base: Path, py_ver: Optional[str], dry: bool = False) -> Path:
    comfy = comfy_root(base)
    venv = comfy / VENV_DIR
    if venv.exists():
        log(f"Removing existing venv at {venv}")
        if not dry:
            if venv.name != VENV_DIR or venv.parent.resolve() != comfy.resolve():
                raise RuntimeError(
                    f"Refusing to remove an unexpected venv path: {venv}"
                )
            shutil.rmtree(venv)
    if not comfy.exists():
        log(f"Creating {comfy}")
        if not dry:
            comfy.mkdir(parents=True, exist_ok=True)
    run(base_python_command(py_ver) + ["-m", "venv", str(venv)], cwd=comfy, dry=dry)
    return venv


def ensure_venv(base: Path, py_ver: Optional[str], dry: bool = False) -> Path:
    comfy = comfy_root(base)
    venv = comfy / VENV_DIR
    bin_dir = venv / ("Scripts" if is_windows() else "bin")
    if bin_dir.exists():
        log("Venv exists — reusing.")
        return venv
    if not comfy.exists():
        log(f"Creating {comfy}")
        if not dry:
            comfy.mkdir(parents=True, exist_ok=True)
    run(base_python_command(py_ver) + ["-m", "venv", str(venv)], cwd=comfy, dry=dry)
    return venv


def pip(
    venv: Path, args: List[str], cwd: Optional[Path] = None, dry: bool = False
) -> int:
    pip_cmd = [
        py_exec(venv_bin=venv / ("Scripts" if is_windows() else "bin")),
        "-m",
        "pip",
        "install",
        "--no-cache-dir",
        "--retries",
        "10",
        "--resume-retries",
        "10",
        "--timeout",
        "120",
    ] + args
    for attempt in range(1, 4):
        code = run(pip_cmd, cwd=cwd, check=False, dry=dry)
        if code == 0:
            return 0
        if attempt < 3:
            delay = 5 * (2 ** (attempt - 1))
            log(f"pip attempt {attempt}/3 failed; retrying in {delay} seconds")
            time.sleep(delay)
    raise RuntimeError(f"pip failed after 3 attempts: {' '.join(pip_cmd)}")


def install_torch(venv: Path, cuda: str, dry: bool = False) -> None:
    idx_map = {
        "cu128": "https://download.pytorch.org/whl/cu128",
        "cu121": "https://download.pytorch.org/whl/cu121",
        "cu118": "https://download.pytorch.org/whl/cu118",
        "cpu": "https://download.pytorch.org/whl/cpu",
    }
    if cuda not in idx_map:
        raise ValueError("--cuda must be one of cu128|cu121|cu118|cpu")
    python = py_exec(venv_bin=venv / ("Scripts" if is_windows() else "bin"))
    run(
        [python, "-m", "pip", "install", "--upgrade", "pip", "setuptools", "wheel"],
        dry=dry,
    )
    pip(
        venv,
        ["torch", "torchvision", "torchaudio", "--index-url", idx_map[cuda]],
        dry=dry,
    )


# ------------------------------ requirements ----------------------------------


def ensure_model_dirs(base: Path, dry: bool = False) -> None:
    comfy = comfy_root(base)
    for p in [
        comfy / "models" / "diffusion_models",
        comfy / "models" / "vae",
        comfy / "models" / "text_encoders",
        comfy / "custom_nodes",
    ]:
        if not p.exists():
            log(f"Creating {p}")
            if not dry:
                p.mkdir(parents=True, exist_ok=True)


def install_comfy_requirements(
    venv: Path,
    base: Path,
    extra_requirements: Optional[Path] = None,
    dry: bool = False,
) -> None:
    """
    Install ComfyUI's supported requirements with normal dependency solving.
    A caller may explicitly add a reviewed requirements file; generated local
    environment snapshots are never consumed implicitly.
    """
    comfy = comfy_root(base)

    pip(venv, ["-r", "requirements.txt"], cwd=comfy, dry=dry)

    if extra_requirements is not None:
        reviewed_requirements = extra_requirements.expanduser().resolve()
        if not dry and not reviewed_requirements.is_file():
            raise FileNotFoundError(
                f"Extra requirements file does not exist: {reviewed_requirements}"
            )
        pip(venv, ["-r", str(reviewed_requirements)], cwd=comfy, dry=dry)


def install_manager(venv: Path, base: Path, dry: bool = False) -> None:
    comfy = comfy_root(base)
    npath = comfy / "custom_nodes" / "ComfyUI-Manager"
    if npath.exists():
        log("ComfyUI-Manager already present — skipping.")
        return
    npath.parent.mkdir(parents=True, exist_ok=True)
    run(
        [
            "git",
            "clone",
            "https://github.com/Comfy-Org/ComfyUI-Manager.git",
            str(npath),
        ],
        dry=dry,
    )


# ------------------------------- Hugging Face ----------------------------------


def install_hf_cli(venv: Path, dry: bool = False) -> None:
    # only the library is needed; we use the Python API (no external CLI launcher)
    pip(venv, ["huggingface_hub>=0.23"], dry=dry)


def hf_login(venv: Path, token: Optional[str], dry: bool = False) -> None:
    # No interactive login needed if HF_TOKEN is present.
    if token:
        pybin = py_exec(venv_bin=venv / ("Scripts" if is_windows() else "bin"))
        run(
            [
                pybin,
                "-c",
                "import os; from huggingface_hub import whoami; "
                "t=os.getenv('HF_TOKEN'); "
                "print('HF whoami:', whoami(token=t) if t else 'no token')",
            ],
            dry=dry,
            check=False,
        )
    else:
        log("No HF_TOKEN provided; if models are gated, set HF_TOKEN and rerun.")


def hf_download(
    venv: Path, repo_id: str, files: list[str], dest: Path, dry: bool = False
) -> None:
    pybin = py_exec(venv_bin=venv / ("Scripts" if is_windows() else "bin"))
    code = f"""
import os, pathlib
from huggingface_hub import hf_hub_download
dest = r'''{dest}'''
pathlib.Path(dest).mkdir(parents=True, exist_ok=True)
repo = r'''{repo_id}'''
files = {files!r}
tok = os.getenv('HF_TOKEN')
for f in files:
    path = hf_hub_download(repo_id=repo, filename=f, local_dir=dest,
                           local_dir_use_symlinks=False, token=tok)
    print(path)
"""
    run([pybin, "-c", code], dry=dry)


def download_models(venv: Path, base: Path, which: str, dry: bool = False) -> None:
    comfy = comfy_root(base)
    models_root = comfy / "models"
    dm = models_root / "diffusion_models"
    vae = models_root / "vae"
    te = models_root / "text_encoders"

    if which == "5b":
        selected = DIFFUSION_FILES["5b"]
    elif which == "14b":
        selected = DIFFUSION_FILES["14b"]
    elif which == "i2v":
        selected = DIFFUSION_FILES["i2v"]
    elif which == "all":
        selected = (
            DIFFUSION_FILES["5b"] + DIFFUSION_FILES["14b"] + DIFFUSION_FILES["i2v"]
        )
    else:
        raise ValueError("--models must be one of 5b|14b|i2v|all")

    install_hf_cli(venv, dry=dry)
    token = os.environ.get("HF_TOKEN")
    hf_login(venv, token=token, dry=dry)

    hf_download(venv, WAN_REPO, selected, dm, dry=dry)
    hf_download(venv, WAN_REPO, VAE_FILES, vae, dry=dry)
    hf_download(venv, WAN_REPO, TEXT_ENCODERS, te, dry=dry)


# -------------------------------- React loader --------------------------------


def make_react(
    base: Path, app_name: str, comfy_url: str, dry: bool = False
) -> Path | None:
    target = base / app_name
    if target.exists():
        log(f"React app '{app_name}' already exists — skipping scaffold.")
        return target
    run(
        ["npm", "create", "vite@latest", app_name, "--", "--template", "react-ts"],
        cwd=base,
        dry=dry,
    )
    run(["npm", "i"], cwd=target, dry=dry)
    run(["npm", "i", "axios"], cwd=target, dry=dry)
    # .env
    env_path = target / ".env"
    content = f"VITE_COMFY_BASE_URL={comfy_url}\n"
    if not dry:
        env_path.write_text(content, encoding="utf-8")
    log(f"Wrote {env_path}")
    # Minimal status UI
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


# --------------------------------- run ComfyUI --------------------------------
def start_comfy(
    venv: Path, base: Path, port: int, listen_all: bool, dry: bool = False
) -> None:
    # Ensure environment variables for PyTorch
    os.environ["PYTORCH_CUDA_ALLOC_CONF"] = "expandable_segments:True"

    comfy = comfy_root(base)
    pybin = py_exec(venv_bin=(venv / ("Scripts" if is_windows() else "bin")))

    args = [pybin, "main.py", "--port", str(port)]
    if listen_all:
        args += ["--listen"]

    log(f"Starting ComfyUI on port {port} with GPU only...")
    run(args, cwd=comfy, dry=dry, check=False)
    log("ComfyUI process exited.")


# ------------------------------------- CLI ------------------------------------


def main() -> None:
    parser = argparse.ArgumentParser(
        prog=APP_NAME, description="ComfyUI + Wan 2.2 setup CLI (Subfolder Layout)."
    )
    sub = parser.add_subparsers(dest="cmd", required=True)

    common = argparse.ArgumentParser(add_help=False)
    common.add_argument(
        "--path",
        type=Path,
        default=DEFAULT_DIR,
        help=f"Base directory (default: {DEFAULT_DIR})",
    )
    common.add_argument(
        "--dry-run", action="store_true", help="Print commands, don’t execute"
    )
    common.add_argument(
        "--verbose", action="store_true", help="(Reserved) Verbose logging"
    )

    p_install = sub.add_parser(
        "install",
        parents=[common],
        help="Full install into <base>/ComfyUI (fresh venv by default).",
    )
    p_install.add_argument(
        "--python",
        dest="pyver",
        default=None,
        help="Python launcher version (Windows), e.g. 3.11",
    )
    p_install.add_argument(
        "--cuda",
        choices=["cu128", "cu121", "cu118", "cpu"],
        required=True,
        help="Torch build",
    )
    p_install.add_argument(
        "--with-manager", action="store_true", help="Install ComfyUI-Manager"
    )
    p_install.add_argument(
        "--models",
        choices=["5b", "14b", "i2v", "all"],
        default=None,
        help="Wan 2.2 model set",
    )
    p_install.add_argument(
        "--hf-token", default=None, help="Hugging Face token (optional)"
    )
    p_install.add_argument(
        "--start", action="store_true", help="Start ComfyUI when done"
    )
    p_install.add_argument(
        "--port", type=int, default=DEFAULT_PORT, help=f"Port (default {DEFAULT_PORT})"
    )
    p_install.add_argument("--listen-all", action="store_true", help="Bind 0.0.0.0")
    p_install.add_argument(
        "--reuse-venv",
        action="store_true",
        help="Reuse existing .venv instead of recreating",
    )
    p_install.add_argument(
        "--extra-requirements",
        type=Path,
        default=None,
        help="Optional reviewed requirements file; no local snapshot is loaded by default",
    )

    p_models = sub.add_parser(
        "models", parents=[common], help="Download/refresh Wan 2.2 models (uses venv)."
    )
    p_models.add_argument(
        "--models", choices=["5b", "14b", "i2v", "all"], required=True
    )
    p_models.add_argument(
        "--hf-token", default=None, help="Hugging Face token (optional)"
    )

    p_react = sub.add_parser(
        "react", parents=[common], help="Create a React loader app beside ComfyUI."
    )
    p_react.add_argument("--name", default="comfy-loader", help="App folder name")
    p_react.add_argument(
        "--url", default=f"http://127.0.0.1:{DEFAULT_PORT}", help="Comfy base URL"
    )

    p_start = sub.add_parser(
        "start", parents=[common], help="Run ComfyUI from the local venv."
    )
    p_start.add_argument("--port", type=int, default=DEFAULT_PORT)
    p_start.add_argument("--listen-all", action="store_true")

    args = parser.parse_args()
    dry = args.dry_run

    if args.cmd in ("install", "models") and args.hf_token:
        os.environ["HF_TOKEN"] = args.hf_token

    ensure_tools()

    base: Path = args.path.expanduser().resolve()
    ensure_base_dir(base, dry=dry)

    if args.cmd == "install":
        # 1) Ensure ComfyUI code exists in subfolder
        clone_comfy(base, dry=dry)
        ensure_model_dirs(base, dry=dry)

        # 2) Venv (fresh by default)
        if args.reuse_venv:
            venv = ensure_venv(base, args.pyver, dry=dry)
        else:
            venv = recreate_venv(base, args.pyver, dry=dry)

        # 3) Python deps
        install_torch(venv, args.cuda, dry=dry)
        install_comfy_requirements(
            venv,
            base,
            extra_requirements=args.extra_requirements,
            dry=dry,
        )
        if args.with_manager:
            install_manager(venv, base, dry=dry)

        python = py_exec(venv_bin=venv / ("Scripts" if is_windows() else "bin"))
        run([python, "-m", "pip", "check"], cwd=comfy_root(base), dry=dry)

        # 4) Models (optional)
        if args.models:
            download_models(venv, base, args.models, dry=dry)

        # 5) Done / maybe start
        act = (
            str(venv / "Scripts" / "Activate.ps1")
            if is_windows()
            else f"source {venv}/bin/activate"
        )
        log(f"Done. To activate venv manually: {act}")
        if args.start:
            start_comfy(venv, base, args.port, args.listen_all, dry=dry)

    elif args.cmd == "models":
        venv = ensure_venv(base, py_ver=None, dry=dry)
        download_models(venv, base, args.models, dry=dry)
        log("Models downloaded.")

    elif args.cmd == "react":
        target = make_react(base, args.name, args.url, dry=dry)
        if target:
            log(f"React app created at: {target}")
            log("Run it with: npm run dev (inside the app directory)")

    elif args.cmd == "start":
        venv = comfy_root(base) / VENV_DIR
        start_comfy(venv, base, args.port, args.listen_all, dry=dry)


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        log("Interrupted by user.")
    except Exception as e:
        log(f"ERROR: {e}")
        sys.exit(1)
