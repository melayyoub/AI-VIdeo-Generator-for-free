[CmdletBinding()]
param(
    [string] $ProjectPath = $PSScriptRoot,
    [ValidateSet('Fail', 'Stop')]
    [string] $LockedVenvAction = 'Fail'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$projectRoot = [IO.Path]::GetFullPath($ProjectPath)
$comfy = Join-Path $projectRoot 'ComfyUI'
$venvPath = Join-Path $comfy '.venv'
$venv = Join-Path $venvPath 'Scripts\python.exe'
$supervisor = Join-Path $projectRoot 'ComfyUI-Windows\run_wan.ps1'

Import-Module (Join-Path $projectRoot 'scripts\Installer.Venv.psm1') -Force
Resolve-VirtualEnvironmentLock `
    -Path $venvPath `
    -SupervisorScriptPath $supervisor `
    -LockedVenvAction $LockedVenvAction

if (-not (Test-Path -LiteralPath $venv -PathType Leaf)) {
    throw "Virtual-environment Python was not found: $venv"
}

# Update huggingface & transformers properly
& $venv -m pip install --upgrade --no-cache-dir huggingface_hub transformers diffusers tokenizers accelerate
if ($LASTEXITCODE -ne 0) {
    throw "Dependency update failed with exit code $LASTEXITCODE."
}

# Patch every custom node calling cached_download
Get-ChildItem -LiteralPath (Join-Path $comfy 'custom_nodes') -Recurse -Filter '*.py' -File |
    Select-String -Pattern "cached_download" -List |
    ForEach-Object {
        (Get-Content -LiteralPath $_.Path) |
            ForEach-Object { $_ -replace "from huggingface_hub import cached_download", "from huggingface_hub import hf_hub_download as cached_download" } |
            Set-Content -LiteralPath $_.Path -Encoding utf8
        Write-Host "Patched: $($_.Path)"
    }

Write-Host "`n✅ Patch complete! Restart ComfyUI."
