# Sam Ayoub — Wan 2.2 + ComfyUI installer (Windows PowerShell) — cu128 + Python3.10 Fixed
[CmdletBinding()]
param(
  [ValidateSet('cu128','cu121','cu118','cpu')] [string] $Cuda    = 'cu128',
  [ValidateSet('5b','14b','i2v','all')] [string] $Models = '5b',
  [switch] $WithManager,
  [switch] $Start,
  [int]    $Port        = 8188,
  [switch] $ListenAll,
  [string] $BasePath    = $PSScriptRoot,
  [string] $PyVersion   = '3.10',
  [string] $HfToken     = $env:HF_TOKEN,
  [switch] $ReuseVenv
)

Write-Host ("[install.ps1] Base: {0}  CUDA: {1}  MODELS: {2}  Manager: {3}  Start: {4}  Port: {5}  ListenAll: {6}  ReuseVenv: {7}" `
  -f $BasePath,$Cuda,$Models,$WithManager.IsPresent,$Start.IsPresent,$Port,$ListenAll.IsPresent,$ReuseVenv.IsPresent)

if (-not (Get-Command py -ErrorAction SilentlyContinue)) {
  Write-Error "Python launcher 'py' not found. Install Python 3.10 from https://www.python.org/downloads/release/python-31011/"
  exit 1
}

if ($HfToken) { $env:HF_TOKEN = $HfToken }

# WAN 2.2 CLI Install Args
$installArgs = @(
  'install',
  '--cuda',       $Cuda,
  '--path',       $BasePath,
  '--models',     $Models,
  '--port',       "$Port",
  '--python',       "$PyVersion"
)
if ($WithManager) { $installArgs += '--with-manager' }
if ($Start)       { $installArgs += '--start' }
if ($ListenAll)   { $installArgs += '--listen-all' }
if ($ReuseVenv)   { $installArgs += '--reuse-venv' }

$cliPath = Join-Path $PSScriptRoot 'wan2_cli.py'
& py "-$PyVersion" $cliPath @installArgs
$exit = $LASTEXITCODE
if ($exit -ne 0) { Write-Error "wan2_cli.py install failed ($exit)"; exit $exit }

# ✅ Fix the venv environment for cu128 & face-swap support
Write-Host "[install.ps1] Applying environment patches..."
$venv = Join-Path $BasePath 'ComfyUI\.venv\Scripts\activate.ps1'
& $venv
$env:GIT_CLONE_PROTECTION_ACTIVE = "false"

pip install -U pip setuptools wheel build
pip install protobuf
pip install onnx
pip install onnxruntime-gpu
pip install insightface
pip install git+https://github.com/descriptinc/audiotools
pip install audiotoolbox dac librosa ffmpeg-python soundfile huggingface_hub regex

Write-Host ''
Write-Host '[install.ps1] ✅ Environment patched for cu128 + Python 3.10'
Write-Host ("Root:        {0}" -f $BasePath)
Write-Host ("ComfyUI:     {0}" -f (Join-Path $BasePath 'ComfyUI'))
Write-Host ("Venv:        {0}" -f (Join-Path $BasePath 'ComfyUI\.venv'))
Write-Host ("Run with:    run_nvidia_gpu.bat")
Write-Host ''

# Start command (if --start not used)
$startArgs = @('start','--path',$BasePath,'--port',"$Port")
if ($ListenAll) { $startArgs += '--listen-all' }
$startCmd = @('py', "-$PyVersion", $cliPath) + $startArgs
Write-Host ($startCmd -join ' ')
