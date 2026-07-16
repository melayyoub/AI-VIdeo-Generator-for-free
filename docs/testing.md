# Testing

Validation is local-first and must report actual results. A user interface,
dry run, or mocked command is not evidence that a full network installation or
GPU generation succeeded.

## Full local gate

From the repository root on Windows:

```powershell
npm run check
```

This runs `npm test` followed by `tests/validate.ps1`. The current suite checks:

- the inclusive port contract (`1` through `65535`) in PowerShell and both
  Python launchers;
- Windows executable-lock detection plus non-destructive `Fail`, explicit
  scoped `Stop`, and guarded `.venv` deletion behavior;
- PowerShell parsing for maintained scripts;
- Python parsing without writing bytecode;
- example workflow JSON parsing;
- tracked text for personal or machine-specific values;
- `ruff` checks outside generated/runtime trees;
- Bash syntax and the network-free Unix installer dry run;
- offline npm lockfile consistency.

The lock integration test creates and removes only a uniquely named temporary
directory under `.test-tmp`; it does not use the real `ComfyUI/.venv`. On
non-Windows systems, `tests/run.ps1` skips the native Windows lock test.

## Prerequisites

- PowerShell 7 (`pwsh`)
- Python 3; the Windows integration path expects the `py -3.10` launcher
- npm
- `ruff`
- Bash; on Windows, the validator first looks for Git Bash
- Windows PowerShell 5.1 for the second Windows lock-policy pass

If a prerequisite is absent, report the check as not run rather than treating
it as passed.

## Focused checks

Run the PowerShell and Python integration suite:

```powershell
npm test
```

Run validation without the integration suite:

```powershell
pwsh -NoProfile -File tests/validate.ps1
```

Validate the Unix command plan without network or installation changes:

```bash
./install.sh --cuda=cu128 --models=5b --start=false --dry-run=true
```

Check shell syntax directly:

```bash
bash -n install.sh installme.sh generateNewSShKey.sh
```

## Manual installation and smoke testing

A change that affects cloning, packages, models, CUDA selection, or process
startup may need a disposable end-to-end environment in addition to the local
gate. Record the platform, Python version, backend, model selection, exact
command, upstream revisions where available, and whether model download,
`pip check`, `/system_stats`, and an actual workflow completed.

Do not run destructive installer tests against an environment containing the
only copy of a user's models, custom nodes, or outputs. Do not claim GPU or
model validation based solely on dry-run output.
