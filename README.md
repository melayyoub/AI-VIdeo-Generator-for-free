# OpenVideo Studio

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Project page](https://github.com/melayyoub/openvideo-studio/actions/workflows/pages.yml/badge.svg)](https://melayyoub.github.io/openvideo-studio/)

**OpenVideo Studio** is a ready-to-use, local-first ComfyUI distribution for AI
video on Windows, Linux, and macOS. One command produces a working studio: an
isolated Python environment, the PyTorch backend you select (NVIDIA CUDA, AMD
DirectML on Windows, or CPU), a
curated custom-node stack (LTX-Video, VideoHelperSuite, KJNodes) at pinned
commits, optional ComfyUI Manager, and official ComfyUI-packaged Wan 2.2
text-to-video and image-to-video model files.

This repository is designed for creators and developers who want a repeatable
local AI video setup without sending prompts, source images, or generated media
to an application server operated by this project.

**Project website:** [comfyui.reallexi.io](https://comfyui.reallexi.io/) provides
the full installation guide, architecture and publication diagrams, security
boundaries, model provenance notes, troubleshooting, and contributor workflow.
A self-contained deep-detail reference page is also published from `site/` at
[melayyoub.github.io/openvideo-studio](https://melayyoub.github.io/openvideo-studio/).

## Highlights

- Windows PowerShell and Bash installation paths
- CUDA 12.8, CUDA 12.1, CUDA 11.8, AMD DirectML (Windows), and CPU PyTorch
  backends, with install-time GPU detection and per-backend environments
  provisioned on demand at launch
- Wan 2.2 5B, 14B text-to-video, and 14B image-to-video model selections
- Curated required custom nodes (LTX-Video, VideoHelperSuite, KJNodes)
  installed from pinned commits in `config/nodes.json`
- Optional ComfyUI Manager integration
- Local-only binding by default in the launcher
- Scoped Windows virtual-environment lock detection
- Bounded retry and resume controls for large package/model downloads
- Explicit dependency consistency checks before completion
- Network-free installer dry run and local integration tests

## Requirements

| Component | Requirement |
| --- | --- |
| Operating system | Windows 10/11, current Linux, or macOS |
| Python | 3.10 recommended |
| Git | Required for ComfyUI and Manager updates |
| curl | Required by the Windows model downloader |
| ffmpeg | Required for normal video workflows |
| GPU | NVIDIA CUDA GPU recommended; AMD GPUs are supported on Windows via DirectML; CPU is supported but slow |
| Disk | Allow substantial space for PyTorch, ComfyUI, models, and outputs |

An optional `HF_TOKEN` can be supplied for gated Hugging Face assets. The
Windows installer sends it to curl through standard input so it is not printed
or placed in the curl process command line.

## Quick start on Windows

Open an external PowerShell terminal in the repository directory:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\install.ps1 -Cuda cu128 -Models 5b -WithManager
```

The default lock policy is non-destructive. If an editor, type checker, or
ComfyUI process is using `ComfyUI\.venv`, the installer lists only the scoped
blockers and exits before changing Git or packages. To authorize stopping those
scoped process trees and rebuilding the environment:

```powershell
.\install.ps1 -Cuda cu128 -Models 5b -WithManager -LockedVenvAction Stop
```

Use `-ReuseVenv` for an incremental package update only when the existing venv
is healthy:

```powershell
.\install.ps1 -Cuda cu128 -Models 5b -WithManager -ReuseVenv
```

### AMD GPUs on Windows

When `-Cuda` is omitted, the installer inspects the display adapters. A machine
with only an AMD GPU automatically uses the DirectML backend, and a machine
with both NVIDIA and AMD GPUs asks interactively which one to use. To choose
explicitly:

```powershell
.\install.ps1 -Cuda directml -Models 5b -WithManager
```

The DirectML backend installs `torch-directml` and `onnxruntime-directml`
instead of the CUDA builds, and the launcher then starts ComfyUI with
`--directml`. CUDA and DirectML cannot share one virtual environment, so the
launcher keeps one per backend: selecting a device the current environment
does not provide (for example `npm run wstart:amd` on a CUDA install, or
`npm run wstart:cuda` on a DirectML install) automatically creates a sibling
environment (`ComfyUI\.venv-directml` or `ComfyUI\.venv-cuda`), installs the
matching PyTorch build plus the ComfyUI and custom-node requirements into it,
and launches from there. Later selections reuse the provisioned environment,
so switching GPUs is instant after the first run. On-demand CUDA environments
default to the `cu128` build; override with `CUSTOM_WAN_TORCH_CUDA`.

## Quick start on Linux or macOS

```bash
chmod +x install.sh
CUDA=cu128 MODELS=5b WITH_MANAGER=true START=false ./install.sh
```

For macOS or a machine without an NVIDIA GPU, select the CPU backend:

```bash
CUDA=cpu MODELS=5b START=false ./install.sh
```

Validate Unix command construction without cloning, installing, or downloading:

```bash
./install.sh --cuda=cu128 --models=5b --start=false --dry-run=true
```

Generated environment snapshots are not installed implicitly. A reviewed extra
requirements file must be explicitly supplied with `EXTRA_REQUIREMENTS` or
`--extra-requirements`.

## Start ComfyUI

The launcher binds to `127.0.0.1` by default:

```powershell
.\ComfyUI\.venv\Scripts\python.exe .\wan2_cli.py start --path . --port 8188
```

On Linux or macOS:

```bash
./ComfyUI/.venv/bin/python ./wan2_cli.py start --path . --port 8188
```

Then open `http://127.0.0.1:8188` and verify the backend with:

```bash
curl http://127.0.0.1:8188/system_stats
```

Binding to every interface exposes ComfyUI to the local network:

```powershell
.\ComfyUI\.venv\Scripts\python.exe .\wan2_cli.py start --path . --port 8188 --listen-all
```

Do not expose ComfyUI directly to the public internet. Use host firewall rules,
an authenticated reverse proxy, and TLS for any intentionally remote setup.

The compute device defaults to `auto` (CUDA when available, then DirectML,
then CPU) and can be forced with `--device gpu|directml|rocm|cpu` or the
`CUSTOM_WAN_COMFYUI_DEVICE` environment variable. On DirectML the launcher
lists every adapter and selects the discrete AMD GPU rather than DirectML's
default (often the integrated GPU); set `CUSTOM_WAN_DIRECTML_DEVICE` to an
adapter index to override the selection. npm shortcuts are available
on Windows:

```powershell
npm run wstart        # auto-detect
npm run wstart:cuda   # force the NVIDIA GPU
npm run wstart:amd    # force the AMD GPU (DirectML)
npm run wstart:cpu    # force CPU
```

### Memory and model-loading errors on Windows

`OSError 1455` ("the paging file is too small") and
`hostbuf_file_reader_read failed` usually mean Windows ran out of physical or
commit memory while staging model weights — large text encoders are staged
through system RAM, and pinned transfer buffers must fit in physical RAM.
Escalate in this order:

1. Free memory first (WSL/Docker and editor windows are common consumers)
   and pick a smaller text-encoder variant (fp8/fp4 instead of fp16) when the
   workflow allows it.
2. `CUSTOM_WAN_COMFYUI_ARGS="--disable-pinned-memory"` — weight transfers
   spill to the page file instead of failing.
3. `CUSTOM_WAN_COMFYUI_ARGS="--disable-pinned-memory --disable-dynamic-vram"`
   — dynamic VRAM streaming (comfy-aimdo) has had issues with quantized video
   models independent of free RAM; it is actively patched, so also keep
   ComfyUI and `comfy-aimdo` updated.
4. On multi-GPU machines add `--cuda-device 0` (or the index of the intended
   card) so streaming targets one device.

A different error, `buffer length ... must be a multiple of element size`,
is not a memory problem: it means a model file on disk is truncated or
corrupt. Re-download it — installer-managed models are sha256-verified, so a
re-run of the installer replaces any file that fails verification.

All launcher locations and network settings can be supplied dynamically with
`--path`, `--host`, `--port`, `CUSTOM_WAN_COMFYUI_CHECKOUT`,
`CUSTOM_WAN_COMFYUI_HOST`, and `CUSTOM_WAN_COMFYUI_PORT`.

`ovs.py` is the OpenVideo Studio alias for the launcher — `python ovs.py
start --path .` is identical to invoking `wan2_cli.py`, which stays supported.
Every launcher environment variable also accepts an `OVS_` prefix
(`OVS_COMFYUI_DEVICE`, `OVS_COMFYUI_PORT`, `OVS_DIRECTML_DEVICE`,
`OVS_TORCH_CUDA`, …); the legacy `CUSTOM_WAN_*` names remain the fallback.

Windows shortcuts are generated locally and are never committed because a
binary `.lnk` can retain machine-specific paths and browser state:

```powershell
.\ComfyUI-Windows\New-ComfyUIShortcut.ps1 -Port 8188 -OpenBrowser
```

## Installer options

### Windows PowerShell

| Option | Values | Default | Purpose |
| --- | --- | --- | --- |
| `-Cuda` | `cu128`, `cu121`, `cu118`, `directml`, `cpu` | `cu128` | PyTorch backend (`directml` = AMD/Intel GPUs on Windows) |
| `-Models` | `5b`, `14b`, `i2v`, `ltx`, `ltx2`, `all` | `5b` | Model set |
| `-WithManager` | switch | off | Install/update ComfyUI Manager |
| `-SkipNodes` | switch | off | Skip the curated custom-node stack |
| `-Start` | switch | off | Start after successful installation |
| `-Port` | `1`–`65535` | `8188` | ComfyUI port |
| `-ListenAll` | switch | off | Bind to `0.0.0.0` |
| `-PyVersion` | launcher version | `3.10` | Windows Python launcher selection |
| `-ModelRepository` | `owner/repository` | reviewed Wan source | Model delivery source |
| `-ModelRevision` | branch, tag, commit | manifest pin | Model source revision override |
| `-ReuseVenv` | switch | off | Preserve the existing venv |
| `-LockedVenvAction` | `Fail`, `Stop` | `Fail` | Lock-handling policy |

### Bash

The Bash installer accepts matching environment variables and `--name=value`
arguments for CUDA, models, Manager, node-stack skipping (`SKIP_NODES`), start,
port, network binding, venv reuse, dry run, path, and optional reviewed
requirements. Model source overrides use `CUSTOM_WAN_MODEL_REPOSITORY` and
`CUSTOM_WAN_MODEL_REVISION`.

## Model selections

- `5b`: Wan 2.2 TI2V 5B plus the matching VAE and text encoder
- `14b`: Wan 2.2 T2V high-noise and low-noise 14B models
- `i2v`: Wan 2.2 I2V high-noise and low-noise 14B models
- `ltx`: LTX-Video 2B 0.9.8 distilled checkpoint plus the T5-XXL text encoder
  (the legacy 0.9.x line)
- `ltx2`: the current LTX-2.3 stack — 22B dev fp8 checkpoint, distilled 1.1
  LoRA, Gemma-3 12B fp4 text encoder, and the x2 spatial upscaler (~40 GB
  total; runs on the pipeline built into ComfyUI core)
- `all`: all selections above

Wan artifacts come from `Comfy-Org/Wan_2.2_ComfyUI_Repackaged`; the LTX 0.9.x
checkpoint from `Lightricks/LTX-Video` with its text encoder from
`comfyanonymous/flux_text_encoders`; and the LTX-2.3 stack from
`Lightricks/LTX-2.3-fp8`, `Lightricks/LTX-2.3`, `Comfy-Org/ltx-2.3`, and
`Comfy-Org/ltx-2`. Every artifact is pinned to an immutable commit **and a
sha256 checksum** in `config/models.json`; both installers verify the hash
after download (and re-verify existing files), so a truncated or tampered
model can never sit silently in the tree. The
`-ModelRepository`/`-ModelRevision` overrides apply to the Wan family only.

Existing model files larger than the installer sanity threshold are retained.
Interrupted Windows downloads use `.part` files and curl resume/retry controls.

## Required custom nodes

Both installers install the curated video node stack from
[`config/nodes.json`](config/nodes.json) unless `-SkipNodes` /
`--skip-nodes=true` is passed:

| Node | Purpose |
| --- | --- |
| `ComfyUI-LTXVideo` | LTX-Video 0.9.x text-to-video and image-to-video nodes (optional for LTX-2: ComfyUI core ships the whole LTX-2 pipeline) |
| `ComfyUI-VideoHelperSuite` | Video load, combine, and export helpers |
| `ComfyUI-KJNodes` | Utility nodes required by Wan and LTX workflows |

Each node is cloned from its upstream GitHub repository and checked out at the
pinned commit recorded in the manifest; its `requirements.txt` is installed
into the project virtual environment. Update the pins through a reviewed pull
request, the same way model revisions are updated. Pair the LTX nodes with the
`ltx` (or `all`) model selection to download the pinned LTX-Video checkpoint
and text encoder.

## Workflow examples

The `examples/` directory contains portable workflow configuration only. Input
media, output previews, workspace identifiers, temporary URLs, and model files
are not bundled. Select your own licensed inputs and models after importing a
workflow. See [`examples/README.md`](examples/README.md) for contribution and
sanitization requirements.

## Repository layout

```text
openvideo-studio/
├── install.ps1                 # Windows installer
├── install.sh                  # Linux/macOS wrapper
├── wan2_cli.py                 # Local ComfyUI launcher
├── ovs.py                      # OpenVideo Studio alias for the launcher
├── wan2_installer.py           # Cross-platform installer implementation
├── config/models.json          # Versioned model source and artifact mapping
├── config/nodes.json           # Curated custom-node stack at pinned commits
├── scripts/Installer.Venv.psm1 # Scoped Windows lock/removal controls
├── scripts/sanitize_workflows.py # Portable workflow privacy gate
├── scripts/                    # Optional maintenance and repair utilities
├── tests/                      # Local installer integration tests
├── docs/                       # Operational documentation
├── examples/                   # Example ComfyUI workflows
├── site/                       # Project page deployed by GitHub Pages
├── .github/workflows/pages.yml # Page deployment (Actions runs no tests)
└── ComfyUI/                    # Local checkout; ignored by root Git
```

Optional utilities in `scripts/` cover recovery and maintenance tasks:
custom-node repair (`fix_custom_nodes.ps1`, `remove_failed_custom_nodes.ps1`),
speech-stack pinning (`fix_speech_stack.ps1`), auxiliary model downloads
(`download_qwen.py`), LoRA checkpoint conversion (`convert_lora_checkpoint.py`),
and model inventory export (`Export-FolderStructure.ps1`). None of them run
during a normal installation.

## Local validation

Validation is local by design; GitHub Actions only deploys the project page.
Run the locked-venv integration test under PowerShell 7 and Windows PowerShell
5.1:

```powershell
npm test
```

Additional local gates used for this repository include:

```powershell
ruff check --exclude ComfyUI --exclude hf_cache .
python -m py_compile wan2_cli.py wan2_installer.py
```

```bash
bash -n install.sh installme.sh
./install.sh --cuda=cu128 --models=5b --start=false --dry-run=true
```

The PowerShell integration test creates a disposable venv, reproduces Windows'
native executable lock, proves the `Fail` policy is non-destructive, proves the
explicit `Stop` policy removes the scoped process tree, and verifies deletion
guards. It never modifies the real ComfyUI environment.

## Security and privacy notes

- Prompts and generated media remain in the local ComfyUI deployment.
- `.venv`, ComfyUI, model caches, logs, editor state, and local agent state are
  excluded from root version control.
- Binary shortcuts, secret environment files, temporary media URLs, exported
  workspace identifiers, and absolute preview paths are rejected or sanitized.
- Process termination is opt-in and limited by normalized executable paths,
  process identity, and a known supervisor ancestry check.
- Virtual-environment deletion is limited to the expected ComfyUI parent and
  rejects roots, unexpected names, and reparse points.
- `pip check` is a required Windows installation gate.
- Treat ComfyUI custom nodes as third-party code and review them before use.

## Troubleshooting

### `Access to ...\.venv\Scripts\python.exe is denied`

This is normally a Windows executable-image lock, not an ACL problem. Rerun with
the default `-LockedVenvAction Fail` to see the scoped process list. Close those
processes, or explicitly allow scoped termination:

```powershell
.\install.ps1 -Cuda cu128 -Models 5b -LockedVenvAction Stop
```

If an earlier recursive deletion partially removed the environment, do not use
`-ReuseVenv`; rebuild it.

### Large PyTorch download fails

Rerun with `-ReuseVenv` after the new venv and pip have been created. Network
installs use bounded command retries, pip connection retries, resume attempts,
and a longer socket timeout.

### CUDA is unavailable

Confirm that the NVIDIA driver supports the selected PyTorch CUDA build, then
run:

```powershell
.\ComfyUI\.venv\Scripts\python.exe -c "import torch; print(torch.__version__, torch.version.cuda, torch.cuda.is_available())"
```

For more detail, see [Windows installer operations](docs/windows-installer.md)
and [Linux/macOS installer operations](docs/unix-installer.md).

## Community and maintenance

- [Contributing guide](CONTRIBUTING.md)
- [Security policy](SECURITY.md)
- [Support policy](SUPPORT.md)
- [Code of conduct](CODE_OF_CONDUCT.md)
- [Architecture](docs/architecture.md)
- [Testing](docs/testing.md)
- [Release process](docs/releases.md)
- [Model provenance and licensing](docs/model-provenance.md)

## License

Distributed under the MIT License. See [LICENSE](LICENSE) for details.
