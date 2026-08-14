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

from wan2_cli_args import port_number


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


PIP_NETWORK_OPTIONS = ["--retries", "10", "--timeout", "120"]

BACKEND_PROBES = {
    "directml": (
        "import sys, torch_directml; "
        "sys.exit(0 if torch_directml.is_available() else 1)"
    ),
    "cuda": "import sys, torch; sys.exit(0 if torch.version.cuda else 1)",
}


def run_checked(command: list[str]) -> None:
    printable = " ".join(command)
    print(f"[wan2_cli] > {printable}")
    if subprocess.call(command) != 0:
        raise SystemExit(f"Command failed: {printable}")


def venv_python_path(venv_dir: Path) -> Path:
    if os.name == "nt":
        return venv_dir / "Scripts" / "python.exe"
    return venv_dir / "bin" / "python"


def python_provides_backend(python_path: Path, backend: str) -> bool:
    probe = [str(python_path), "-c", BACKEND_PROBES[backend]]
    return subprocess.call(probe) == 0


def installed_versions(python_path: Path, packages: list[str]) -> list[str]:
    code = (
        "import importlib.metadata, sys\n"
        "for name in sys.argv[1:]:\n"
        "    print(name + '==' + importlib.metadata.version(name))\n"
    )
    result = subprocess.run(
        [str(python_path), "-c", code, *packages],
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        raise SystemExit(
            "Unable to read installed package versions: " + result.stderr.strip()
        )
    return result.stdout.split()


def ensure_backend_venv(backend: str, comfyui_dir: Path) -> Path:
    """Return a Python that provides `backend`, provisioning a venv on demand.

    CUDA and DirectML torch builds cannot share one environment, so each
    backend gets a sibling venv next to the primary one. Selecting a device
    the current environment does not provide creates and provisions that
    sibling once; later selections reuse it.
    """
    venv_dir = comfyui_dir / f".venv-{backend}"
    python_path = venv_python_path(venv_dir)
    if python_path.exists() and python_provides_backend(python_path, backend):
        return python_path

    print(f"[wan2_cli] Provisioning the {backend} environment at {venv_dir}")
    if not python_path.exists():
        run_checked([sys.executable, "-m", "venv", str(venv_dir)])
    pip = [str(python_path), "-m", "pip", "install", *PIP_NETWORK_OPTIONS]
    run_checked([*pip, "--upgrade", "pip", "setuptools<82", "wheel"])
    if backend == "directml":
        # Install torch-directml on its own first so the resolver honors its
        # exact torch/torchvision pins instead of backtracking to an older
        # plugin build to satisfy unrelated newer packages.
        run_checked([*pip, "--upgrade", "torch-directml", "onnxruntime-directml"])
        pins = installed_versions(
            python_path, ["torch", "torchvision", "torch-directml"]
        )
    else:
        cuda_build = os.getenv("CUSTOM_WAN_TORCH_CUDA", "").strip() or "cu128"
        run_checked(
            [
                *pip,
                "--upgrade",
                "torch",
                "torchvision",
                "torchaudio",
                "--index-url",
                f"https://download.pytorch.org/whl/{cuda_build}",
            ]
        )
        run_checked([*pip, "--upgrade", "onnxruntime-gpu"])
        pins = installed_versions(python_path, ["torch", "torchvision", "torchaudio"])

    # Every later install is constrained to the pinned torch stack. Without
    # this, an unpinned custom-node requirement (for example a package that
    # needs a newer torch) silently replaces the backend's torch build and
    # breaks it.
    constraints_path = venv_dir / "pip-constraints.txt"
    constraints_path.write_text("\n".join(pins) + "\n", encoding="utf-8")
    constrained_pip = [*pip, "-c", str(constraints_path)]
    if backend == "directml":
        # Pin torchaudio to the torch version explicitly: a bare "torchaudio"
        # is "already satisfied" by a stale mismatched install and stays put.
        torch_pin = next(pin for pin in pins if pin.startswith("torch=="))
        run_checked([*constrained_pip, "torchaudio" + torch_pin.removeprefix("torch")])
        pins = installed_versions(
            python_path, ["torch", "torchvision", "torchaudio", "torch-directml"]
        )
        constraints_path.write_text("\n".join(pins) + "\n", encoding="utf-8")

    requirements = comfyui_dir / "requirements.txt"
    if requirements.exists():
        run_checked([*constrained_pip, "-r", str(requirements)])
    for node_requirements in sorted(
        (comfyui_dir / "custom_nodes").glob("*/requirements.txt")
    ):
        if subprocess.call([*constrained_pip, "-r", str(node_requirements)]) != 0:
            print(
                "[wan2_cli] WARNING: node requirements skipped (incompatible "
                f"with the pinned torch stack): {node_requirements}"
            )
    if not python_provides_backend(python_path, backend):
        raise SystemExit(
            f"Provisioning finished, but the {backend} backend still does not "
            f"work in {python_path}. Delete {venv_dir} and select the device "
            "again to rebuild it."
        )
    return python_path


def resolve_checkout_path(configured: str, root: Path) -> Path:
    if not configured:
        return (root / "ComfyUI").resolve()
    path = Path(configured).expanduser()
    if path.is_absolute():
        return path.resolve()
    return (root / path).resolve()


def main() -> None:
    parser = argparse.ArgumentParser(description="Start the local ComfyUI backend.")
    parser.add_argument("command", choices=["start"])
    parser.add_argument("--path", default=str(Path(__file__).resolve().parent))
    parser.add_argument(
        "--host", default=os.getenv("CUSTOM_WAN_COMFYUI_HOST", "127.0.0.1")
    )
    parser.add_argument(
        "--port",
        type=port_number,
        default=os.getenv("CUSTOM_WAN_COMFYUI_PORT", "8188"),
        help="TCP port (1-65535; default: 8188)",
    )
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

    directml_ready = False
    try:
        importlib.import_module("torch_directml")

        directml_ready = True
    except Exception:
        directml_ready = False
    gpu_ready = cuda_available()
    rocm_ready = rocm_available()

    launch_python = Path(sys.executable)
    device_arguments: list[str] = []
    if args.device == "directml":
        if not directml_ready:
            launch_python = ensure_backend_venv("directml", comfyui_dir)
        device_arguments = ["--directml"]
    elif args.device == "gpu":
        if not gpu_ready:
            launch_python = ensure_backend_venv("cuda", comfyui_dir)
            cuda_probe = (
                "import sys, torch; sys.exit(0 if torch.cuda.is_available() else 1)"
            )
            if subprocess.call([str(launch_python), "-c", cuda_probe]) != 0:
                raise SystemExit(
                    f"gpu was requested, but CUDA is unavailable in {launch_python}. "
                    "Check the NVIDIA driver, or set CUSTOM_WAN_TORCH_CUDA to a "
                    "matching build and delete that environment to provision it "
                    "again."
                )
    elif args.device == "rocm":
        if not gpu_ready:
            raise SystemExit(
                "rocm was requested, but torch.cuda.is_available() is false."
            )
    elif args.device == "cpu":
        device_arguments = ["--cpu"]
    elif gpu_ready:  # auto
        pass
    elif directml_ready:
        device_arguments = ["--directml"]
    else:
        device_arguments = ["--cpu"]

    command = [str(launch_python), str(main_py), "--port", str(args.port)]
    if args.listen_all:
        command.extend(["--listen", "0.0.0.0"])
    elif args.host:
        command.extend(["--listen", str(args.host)])
    command.extend(device_arguments)
    extra_args = os.getenv("CUSTOM_WAN_COMFYUI_ARGS", "").strip()
    if extra_args:
        command.extend(shlex.split(extra_args))
    elif rocm_ready:
        command.append("--use-pytorch-cross-attention")
    raise SystemExit(subprocess.call(command, cwd=str(comfyui_dir)))


if __name__ == "__main__":
    main()
