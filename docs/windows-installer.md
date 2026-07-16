# Windows installer operations

`install.ps1` installs or updates ComfyUI, creates its Python virtual
environment, installs the selected PyTorch build, and downloads the selected
Wan model set.

## Normal installation

Run the installer from an external PowerShell terminal so an editor is less
likely to start background tools in the environment while it is being rebuilt:

```powershell
.\install.ps1 -Cuda cu128 -Models 5b -WithManager
```

The installer recreates `ComfyUI\.venv` by default. Use `-ReuseVenv` only when
the existing environment is known to be healthy and only package updates are
required.

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
