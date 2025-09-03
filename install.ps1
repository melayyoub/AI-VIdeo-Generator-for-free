#!/usr/bin/env pwsh
# Sam Ayoub — Wan 2.2 + ComfyUI installer (Windows PowerShell)
param(
  [string]$Cuda = "cu121",         # cu121 | cu118 | cpu
  [string]$Models = "5b",          # 5b | 14b | i2v | all
  [bool]$WithManager = $true,
  [bool]$Start = $true,
  [int]$Port = 8188,
  [bool]$ListenAll = $false,
  [string]$BasePath = "$HOME\ComfyStack",
  [string]$PyVersion = "3.11",     # py launcher version
  [string]$HfToken = $env:HF_TOKEN
)

Write-Host "[install.ps1] Base: $BasePath  CUDA: $Cuda  MODELS: $Models  Manager: $WithManager  Start: $Start  Port: $Port  ListenAll: $ListenAll"

# Verify Python launcher
if (-not (Get-Command py -ErrorAction SilentlyContinue)) {
  Write-Error "Python launcher 'py' not found. Install Python 3.10–3.12 from python.org."; exit 1
}

# Compose flags
$mgr = @()
if ($WithManager) { $mgr += "--with-manager" }

$startFlag = @()
if ($Start) { $startFlag += "--start" }

$listen = @()
if ($ListenAll) { $listen += "--listen-all" }

# Token (optional)
if ($HfToken) { $env:HF_TOKEN = $HfToken }

# Run install
py -$PyVersion .\wan2_cli.py install `
  --cuda $Cuda `
  --path $BasePath `
  @mgr `
  --models $Models `
  @startFlag `
  --port $Port `
  @listen

Write-Host ""
Write-Host "[install.ps1] Done."
Write-Host ("ComfyUI root: {0}\ComfyUI" -f $BasePath)
Write-Host ("To start later: py -{0} .\wan2_cli.py start --path `"{1}`" --port {2} {3}" -f $PyVersion, $BasePath, $Port, ($(if($ListenAll){"--listen-all"})))
