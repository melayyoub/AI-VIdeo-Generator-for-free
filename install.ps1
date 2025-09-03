# Sam Ayoub — Wan 2.2 + ComfyUI installer (Windows PowerShell)
[CmdletBinding()]
param(
  [ValidateSet('cu121','cu118','cpu')] [string] $Cuda    = 'cu121',
  [ValidateSet('5b','14b','i2v','all')] [string] $Models = '5b',
  [switch] $WithManager,
  [switch] $Start,
  [int]    $Port        = 8188,
  [switch] $ListenAll,
  # Default to the folder where THIS script resides (same-location layout)
  [string] $BasePath    = $PSScriptRoot,
  [string] $PyVersion   = '3.11',
  [string] $HfToken     = $env:HF_TOKEN,
  [switch] $ForceHere,
  [switch] $ReuseVenv
)

Write-Host ("[install.ps1] Base: {0}  CUDA: {1}  MODELS: {2}  Manager: {3}  Start: {4}  Port: {5}  ListenAll: {6}  ForceHere: {7}  ReuseVenv: {8}" `
  -f $BasePath,$Cuda,$Models,$WithManager.IsPresent,$Start.IsPresent,$Port,$ListenAll.IsPresent,$ForceHere.IsPresent,$ReuseVenv.IsPresent)

# Verify Python launcher
if (-not (Get-Command py -ErrorAction SilentlyContinue)) {
  Write-Error "Python launcher 'py' not found. Install Python 3.10–3.12 from python.org."
  exit 1
}

# Optional token
if ($HfToken) { $env:HF_TOKEN = $HfToken }

# Build install args as an array (robust against spaces/quotes)
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
if ($ForceHere)   { $installArgs += '--force-here' }
if ($ReuseVenv)   { $installArgs += '--reuse-venv' }

# Run: py -<ver> <script-dir>\wan2_cli.py <args...>
$cliPath = Join-Path $PSScriptRoot 'wan2_cli.py'
& py "-$PyVersion" $cliPath @installArgs
$exit = $LASTEXITCODE
if ($exit -ne 0) { Write-Error "wan2_cli.py install failed ($exit)"; exit $exit }

Write-Host ''
Write-Host '[install.ps1] Done.'
Write-Host ("Root: {0}" -f $BasePath)
Write-Host ("Venv: {0}" -f (Join-Path $BasePath '.venv'))

# Print a safe "start later" hint
$startArgs = @('start','--path',$BasePath,'--port',"$Port")
if ($ListenAll) { $startArgs += '--listen-all' }
$startCmd = @('py', "-$PyVersion", $cliPath) + $startArgs
Write-Host ($startCmd -join ' ')
