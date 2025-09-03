# Sam Ayoub — Wan 2.2 + ComfyUI installer (Windows PowerShell)
[CmdletBinding()]
param(
  [ValidateSet('cu121','cu118','cpu')] [string] $Cuda    = 'cu121',
  [ValidateSet('5b','14b','i2v','all')] [string] $Models = '5b',
  [switch] $WithManager,
  [switch] $Start,
  [int]    $Port        = 8188,
  [switch] $ListenAll,
  [string] $BasePath    = $PSScriptRoot,   # base (repo will be under BasePath\ComfyUI)
  [string] $PyVersion   = '3.11',
  [string] $HfToken     = $env:HF_TOKEN,
  [switch] $ReuseVenv
)

Write-Host ("[install.ps1] Base: {0}  CUDA: {1}  MODELS: {2}  Manager: {3}  Start: {4}  Port: {5}  ListenAll: {6}  ReuseVenv: {7}" `
  -f $BasePath,$Cuda,$Models,$WithManager.IsPresent,$Start.IsPresent,$Port,$ListenAll.IsPresent,$ReuseVenv.IsPresent)

if (-not (Get-Command py -ErrorAction SilentlyContinue)) {
  Write-Error "Python launcher 'py' not found. Install Python 3.10–3.12 from python.org."
  exit 1
}
if ($HfToken) { $env:HF_TOKEN = $HfToken }

$installArgs = @(
  'install',
  '--cuda',       $Cuda,
  '--path',       $BasePath,
  '--models',     $Models,
  '--port',       "$Port"
)
if ($WithManager) { $installArgs += '--with-manager' }
if ($Start)       { $installArgs += '--start' }
if ($ListenAll)   { $installArgs += '--listen-all' }
if ($ReuseVenv)   { $installArgs += '--reuse-venv' }

$cliPath = Join-Path $PSScriptRoot 'wan2_cli.py'
& py "-$PyVersion" $cliPath @installArgs
$exit = $LASTEXITCODE
if ($exit -ne 0) { Write-Error "wan2_cli.py install failed ($exit)"; exit $exit }

Write-Host ''
Write-Host '[install.ps1] Done.'
Write-Host ("Root: {0}" -f $BasePath)
Write-Host ("ComfyUI: {0}" -f (Join-Path $BasePath 'ComfyUI'))
Write-Host ("Venv: {0}" -f (Join-Path $BasePath 'ComfyUI\.venv'))

# Start later (no reinstall):
$startArgs = @('start','--path',$BasePath,'--port',"$Port")
if ($ListenAll) { $startArgs += '--listen-all' }
$startCmd = @('py', "-$PyVersion", $cliPath) + $startArgs
Write-Host ($startCmd -join ' ')
