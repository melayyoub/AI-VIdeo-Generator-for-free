# Wan 2.2 AI Video Generator for ComfyUI

Local-first installers and launchers for running **Wan 2.2 text-to-video and
image-to-video workflows in ComfyUI** on Windows, Linux, or macOS. The project
creates an isolated Python environment, selects a PyTorch CUDA or CPU backend,
optionally installs ComfyUI Manager, and downloads official ComfyUI-packaged Wan
model files.

This repository is designed for creators and developers who want a repeatable
local AI video setup without sending prompts, source images, or generated media
to an application server operated by this project.

**Project website:** [comfyui.reallexi.io](https://comfyui.reallexi.io/) provides
the full installation guide, architecture and publication diagrams, security
boundaries, model provenance notes, troubleshooting, and contributor workflow.

## Highlights

- Windows PowerShell and Bash installation paths
- CUDA 12.8, CUDA 12.1, CUDA 11.8, and CPU PyTorch backends
- Wan 2.2 5B, 14B text-to-video, and 14B image-to-video model selections
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
| GPU | NVIDIA CUDA GPU recommended; CPU is supported but slow |
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

## Installer options

### Windows PowerShell

| Option | Values | Default | Purpose |
| --- | --- | --- | --- |
| `-Cuda` | `cu128`, `cu121`, `cu118`, `cpu` | `cu128` | PyTorch backend |
| `-Models` | `5b`, `14b`, `i2v`, `all` | `5b` | Wan model set |
| `-WithManager` | switch | off | Install/update ComfyUI Manager |
| `-Start` | switch | off | Start after successful installation |
| `-Port` | `1`–`65535` | `8188` | ComfyUI port |
| `-ListenAll` | switch | off | Bind to `0.0.0.0` |
| `-PyVersion` | launcher version | `3.10` | Windows Python launcher selection |
| `-ReuseVenv` | switch | off | Preserve the existing venv |
| `-LockedVenvAction` | `Fail`, `Stop` | `Fail` | Lock-handling policy |

### Bash

The Bash installer accepts matching environment variables and `--name=value`
arguments for CUDA, models, Manager, start, port, network binding, venv reuse,
dry run, path, and optional reviewed requirements.

## Model selections

- `5b`: Wan 2.2 TI2V 5B plus the matching VAE and text encoder
- `14b`: Wan 2.2 T2V high-noise and low-noise 14B models
- `i2v`: Wan 2.2 I2V high-noise and low-noise 14B models
- `all`: all selections above

Existing model files larger than the installer sanity threshold are retained.
Interrupted Windows downloads use `.part` files and curl resume/retry controls.

## Repository layout

```text
custom-wan/
├── install.ps1                 # Windows installer
├── install.sh                  # Linux/macOS wrapper
├── wan2_cli.py                 # Local ComfyUI launcher
├── wan2_cli_RTX.py             # Cross-platform installer implementation
├── scripts/Installer.Venv.psm1 # Scoped Windows lock/removal controls
├── tests/                      # Local installer integration tests
├── docs/                       # Operational documentation
├── examples/                   # Example ComfyUI workflows
└── ComfyUI/                    # Local checkout; ignored by root Git
```

## Local validation

Run the locked-venv integration test under PowerShell 7 and Windows PowerShell
5.1:

```powershell
npm test
```

Additional local gates used for this repository include:

```powershell
ruff check --exclude ComfyUI --exclude hf_cache .
python -m py_compile wan2_cli.py wan2_cli_RTX.py
```

```bash
bash -n install.sh installme.sh generateNewSShKey.sh
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
