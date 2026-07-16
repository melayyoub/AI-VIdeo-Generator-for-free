#!/usr/bin/env python3
"""Small launcher shim for the platform-managed ComfyUI checkout."""

from __future__ import annotations

import argparse
import importlib
import os
import shlex
import subprocess
import sys
from pathlib import Path


def cuda_available() -> bool:
    try:
        import torch

        return bool(torch.cuda.is_available())
    except Exception:
        return False


def rocm_available() -> bool:
    try:
        import torch

        return bool(torch.cuda.is_available() and getattr(torch.version, "hip", None))
    except Exception:
        return False


def resolve_checkout_path(configured: str, root: Path) -> Path:
    if not configured:
        return root / "ComfyUI"
    path = Path(configured).expanduser()
    if path.is_absolute():
        return path.resolve()
    candidates = [
        root.parent.parent / path,
        root / path,
        Path.cwd() / path,
    ]
    for candidate in candidates:
        if (candidate / "main.py").exists():
            return candidate.resolve()
    return candidates[0].resolve()


def main() -> None:
    parser = argparse.ArgumentParser(description="Start the local ComfyUI backend.")
    parser.add_argument("command", choices=["start"])
    parser.add_argument("--path", default=str(Path(__file__).resolve().parent))
    parser.add_argument(
        "--host", default=os.getenv("CUSTOM_WAN_COMFYUI_HOST", "127.0.0.1")
    )
    parser.add_argument("--port", default=os.getenv("CUSTOM_WAN_COMFYUI_PORT", "8188"))
    parser.add_argument("--listen-all", action="store_true")
    parser.add_argument(
        "--device",
        choices=["auto", "cpu", "gpu", "rocm", "directml"],
        default=os.getenv("CUSTOM_WAN_COMFYUI_DEVICE", "auto").strip().lower()
        or "auto",
    )
    args = parser.parse_args()

    root = Path(args.path).expanduser().resolve()
    configured_checkout = (
        os.getenv("CUSTOM_WAN_COMFYUI_CHECKOUT", "").strip()
        or os.getenv("CUSTOM_WAN_DOCKER_COMFYUI_CHECKOUT", "").strip()
    )
    comfyui_dir = resolve_checkout_path(configured_checkout, root)
    main_py = comfyui_dir / "main.py"
    if not main_py.exists():
        raise SystemExit(f"ComfyUI main.py was not found at {main_py}")

    hf_home = root / "hf_cache"
    os.environ.setdefault("HF_HOME", str(hf_home))
    os.environ.setdefault("HF_HUB_CACHE", str(hf_home / "hub"))
    os.environ.setdefault("TRANSFORMERS_CACHE", str(hf_home / "transformers"))

    command = [sys.executable, str(main_py), "--port", str(args.port)]
    if args.listen_all:
        command.extend(["--listen", "0.0.0.0"])
    elif args.host:
        command.extend(["--listen", str(args.host)])
    directml_ready = False
    try:
        importlib.import_module("torch_directml")

        directml_ready = True
    except Exception:
        directml_ready = False
    gpu_ready = cuda_available()
    rocm_ready = rocm_available()
    if args.device in {"gpu", "rocm"} and not gpu_ready:
        raise SystemExit(
            f"{args.device} was requested, but torch.cuda.is_available() is false."
        )
    if args.device in {"gpu", "rocm"} or (args.device == "auto" and gpu_ready):
        pass
    elif args.device == "directml" or (args.device == "auto" and directml_ready):
        command.append("--directml")
    elif args.device == "cpu" or args.device == "auto":
        command.append("--cpu")
    extra_args = os.getenv("CUSTOM_WAN_COMFYUI_ARGS", "").strip()
    if extra_args:
        command.extend(shlex.split(extra_args))
    elif rocm_ready:
        command.append("--use-pytorch-cross-attention")
    raise SystemExit(subprocess.call(command, cwd=str(comfyui_dir)))


if __name__ == "__main__":
    main()
