# Windows installer operations

`install.ps1` installs or updates ComfyUI, creates its Python virtual
environment, installs the selected PyTorch build, installs the curated
custom-node stack from `config/nodes.json` at pinned commits (omit with
`-SkipNodes`), and downloads the selected Wan model set.

## Normal installation

Run the installer from an external PowerShell terminal so an editor is less
likely to start background tools in the environment while it is being rebuilt:

```powershell
.\install.ps1 -Cuda cu128 -Models 5b -WithManager
```

The installer recreates `ComfyUI\.venv` by default. Use `-ReuseVenv` only when
the existing environment is known to be healthy and only package updates are
required.

## Compute backend and GPU selection

`-Cuda` accepts `cu128`, `cu121`, `cu118`, `directml`, and `cpu`. The
`directml` backend targets AMD (and Intel) GPUs on Windows: it installs
`torch-directml` and `onnxruntime-directml` instead of the CUDA builds, and the
launcher starts ComfyUI with `--directml`.

When `-Cuda` is omitted, the installer inspects the display adapters:

- both NVIDIA and AMD present: the installer asks interactively which GPU to
  use (in a non-interactive session it keeps the CUDA default and prints how to
  select AMD explicitly);
- only AMD present: the DirectML backend is selected automatically;
- otherwise: the CUDA default applies.

An explicit `-Cuda` value always wins and skips detection. CUDA and DirectML
cannot share one virtual environment, so the launcher keeps one per backend:
`ComfyUI\.venv` serves the backend the installer built, and selecting a
different device at launch (`wan2_cli.py start --device directml|gpu`,
`npm run wstart:amd`, `npm run wstart:cuda`) provisions a sibling environment
(`ComfyUI\.venv-directml` or `ComfyUI\.venv-cuda`) on first use — creating the
venv and installing the matching PyTorch build, the ComfyUI requirements, and
the custom-node requirements — then launches ComfyUI from it. Later
selections reuse the sibling directly. On-demand CUDA environments default to
`cu128`; override with `CUSTOM_WAN_TORCH_CUDA`.

## Locked virtual environments

Windows does not allow a running executable or loaded native module to be
deleted. ComfyUI, a terminal, an editor type checker, or the repository's
restart supervisor can therefore block removal of `.venv`.

The installer performs a preflight before changing Git, packages, or files. Its
default `-LockedVenvAction Fail` policy reports scoped blockers without stopping
them. Explicitly enabling `-LockedVenvAction Stop` stops only:

- process trees whose executable path is inside this exact `.venv`; and
- the known `ComfyUI-Windows\run_wan.ps1` restart supervisor when its exact path
  is present in a PowerShell process command line.

Unrelated Python, PowerShell, and editor processes are not selected. Deletion
is bounded, retried, and protected by checks that reject filesystem roots,
directories not named `.venv`, and reparse points.

For a non-destructive managed-environment policy, fail and report the scoped
blockers instead of stopping them:

```powershell
.\install.ps1 -Cuda cu128 -Models 5b -LockedVenvAction Fail
```

If an earlier deletion already failed partway through, do not use `-ReuseVenv`.
Close the reported process or allow the scoped `Stop` policy, then rerun the
normal installation so the environment is recreated and its interpreter,
`sys.prefix`, and `pip` are verified.

## Local validation

The installer process/deletion integration test creates an isolated temporary
venv. It proves that `Fail` leaves a live environment untouched, `Stop` removes
the live process tree and environment, and the deletion guard rejects an unsafe
directory name.

```powershell
npm test
```

## Portable shortcut

Do not commit a Windows `.lnk` file. Shortcut binaries can retain the creator's
profile, browser state, icon path, and other local details. Generate the
shortcut on the destination machine instead:

```powershell
.\ComfyUI-Windows\New-ComfyUIShortcut.ps1 -Port 8188 -OpenBrowser
```

`-ProjectPath` and `-ShortcutPath` are optional and resolved at runtime. The
generated shortcut is ignored by Git.
