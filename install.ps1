# Wan 2.2 + ComfyUI installer for Windows PowerShell.
# Compatible with the current wan2_cli.py, which exposes only the `start` command.

[CmdletBinding()]
param(
  [ValidateSet('cu128','cu121','cu118','cpu')]
  [string] $Cuda = 'cu128',

  [ValidateSet('5b','14b','i2v','all')]
  [string] $Models = '5b',

  [switch] $WithManager,
  [switch] $Start,
  [ValidateRange(1, 65535)]
  [int] $Port = 8188,
  [switch] $ListenAll,
  [string] $BasePath = $PSScriptRoot,
  [string] $PyVersion = '3.10',
  [string] $HfToken = $env:HF_TOKEN,
  [string] $ModelRepository = $env:CUSTOM_WAN_MODEL_REPOSITORY,
  [string] $ModelRevision = $env:CUSTOM_WAN_MODEL_REVISION,
  [switch] $ReuseVenv,

  [ValidateSet('Stop','Fail')]
  [string] $LockedVenvAction = 'Fail'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$modelManifestPath = Join-Path $PSScriptRoot 'config\models.json'
if (-not (Test-Path -LiteralPath $modelManifestPath -PathType Leaf)) {
  throw "Model manifest is missing: $modelManifestPath"
}
$modelManifest = Get-Content -LiteralPath $modelManifestPath -Raw | ConvertFrom-Json
if ($modelManifest.schema_version -ne 1) {
  throw 'Unsupported model manifest schema version.'
}
if ([string]::IsNullOrWhiteSpace($ModelRepository)) {
  $ModelRepository = [string] $modelManifest.wan.repository
}
if ([string]::IsNullOrWhiteSpace($ModelRevision)) {
  $ModelRevision = [string] $modelManifest.wan.revision
}

if ($ModelRepository -notmatch '^[A-Za-z0-9._-]+/[A-Za-z0-9._-]+$') {
  throw 'ModelRepository must use the owner/repository form.'
}
if ($ModelRevision -notmatch '^[A-Za-z0-9._/-]+$' -or $ModelRevision.Contains('..')) {
  throw 'ModelRevision must be a branch, tag, or commit without traversal segments.'
}

$installerVenvModule = Join-Path $PSScriptRoot 'scripts\Installer.Venv.psm1'
if (-not (Test-Path -LiteralPath $installerVenvModule)) {
  throw "Installer support module is missing: $installerVenvModule"
}
Import-Module $installerVenvModule -Force

function Invoke-Native {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)] [string] $FilePath,
    [Parameter()] [string[]] $ArgumentList = @()
  )

  Write-Host ("> {0} {1}" -f $FilePath, ($ArgumentList -join ' ')) -ForegroundColor DarkGray
  & $FilePath @ArgumentList
  $code = $LASTEXITCODE
  if ($code -ne 0) {
    throw ("Command failed with exit code {0}: {1} {2}" -f $code, $FilePath, ($ArgumentList -join ' '))
  }
}

function Ensure-Directory {
  param([Parameter(Mandatory = $true)] [string] $Path)
  if (-not (Test-Path -LiteralPath $Path)) {
    New-Item -ItemType Directory -Path $Path -Force | Out-Null
  }
}

function Get-HuggingFaceFile {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)] [string] $RelativePath,
    [Parameter(Mandatory = $true)] [string] $Destination
  )

  if (Test-Path -LiteralPath $Destination) {
    $existing = Get-Item -LiteralPath $Destination
    if ($existing.Length -gt 1MB) {
      Write-Host "[models] Existing file kept: $Destination" -ForegroundColor Green
      return
    }
    Remove-Item -LiteralPath $Destination -Force
  }

  $destinationDir = Split-Path -Parent $Destination
  Ensure-Directory $destinationDir

  $encodedRepository = (($ModelRepository -split '/') | ForEach-Object { [Uri]::EscapeDataString($_) }) -join '/'
  $encodedRevision = (($ModelRevision -split '/') | ForEach-Object { [Uri]::EscapeDataString($_) }) -join '/'
  $repo = "https://huggingface.co/${encodedRepository}/resolve/${encodedRevision}"
  $encodedPath = (($RelativePath -split '/') | ForEach-Object { [Uri]::EscapeDataString($_) }) -join '/'
  $url = "${repo}/${encodedPath}?download=true"
  $partial = "$Destination.part"

  Write-Host "[models] Downloading: $(Split-Path -Leaf $Destination)" -ForegroundColor Cyan

  $curlArgs = @(
    '-L',
    '--fail',
    '--retry', '8',
    '--retry-delay', '5',
    '--retry-all-errors',
    '--continue-at', '-',
    '--output', $partial
  )

  if ($env:HF_TOKEN) {
    if ($env:HF_TOKEN -match '[\r\n]') {
      throw 'HF_TOKEN contains an invalid newline character.'
    }

    # curl accepts headers from stdin via @-. This keeps the bearer token out
    # of the process command line and out of Invoke-Native's command log.
    Write-Host '> curl.exe [Authorization header supplied via stdin]' -ForegroundColor DarkGray
    "Authorization: Bearer $($env:HF_TOKEN)" | & curl.exe @curlArgs '-H' '@-' $url
    $curlExitCode = $LASTEXITCODE
    if ($curlExitCode -ne 0) {
      throw "Model download failed with curl exit code $curlExitCode."
    }
  }
  else {
    $curlArgs += $url
    Invoke-Native -FilePath 'curl.exe' -ArgumentList $curlArgs
  }

  if (-not (Test-Path -LiteralPath $partial)) {
    throw "Model download completed without creating the expected file: $partial"
  }

  $downloaded = Get-Item -LiteralPath $partial
  if ($downloaded.Length -lt 1MB) {
    throw "Downloaded model file is unexpectedly small: $partial"
  }

  Move-Item -LiteralPath $partial -Destination $Destination -Force
  Write-Host "[models] Saved: $Destination" -ForegroundColor Green
}

Write-Host ("[install.ps1] Base: {0}  CUDA: {1}  MODELS: {2}  Manager: {3}  Start: {4}  Port: {5}  ListenAll: {6}  ReuseVenv: {7}  LockedVenvAction: {8}" `
  -f $BasePath,$Cuda,$Models,$WithManager.IsPresent,$Start.IsPresent,$Port,$ListenAll.IsPresent,$ReuseVenv.IsPresent,$LockedVenvAction)

if (-not (Get-Command py -ErrorAction SilentlyContinue)) {
  throw "Python launcher 'py' was not found. Install 64-bit Python $PyVersion first."
}

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
  throw "Git was not found. Install Git for Windows and reopen PowerShell."
}

if (-not (Get-Command curl.exe -ErrorAction SilentlyContinue)) {
  throw "curl.exe was not found. A current Windows 10/11 installation normally includes it."
}

if ($HfToken) {
  $env:HF_TOKEN = $HfToken
}

$BasePath = [IO.Path]::GetFullPath($BasePath)
Ensure-Directory $BasePath

$comfyPath   = Join-Path $BasePath 'ComfyUI'
$mainPy      = Join-Path $comfyPath 'main.py'
$venvPath    = Join-Path $comfyPath '.venv'
$venvPython  = Join-Path $venvPath 'Scripts\python.exe'
$cliPath     = Join-Path $PSScriptRoot 'wan2_cli.py'
$runWanPath  = Join-Path $PSScriptRoot 'ComfyUI-Windows\run_wan.ps1'

# Refuse or stop scoped users of the environment before Git, pip, or filesystem
# mutations. This also prevents the run_wan.ps1 watchdog from racing deletion.
if (Test-Path -LiteralPath $venvPath) {
  Resolve-VirtualEnvironmentLock `
    -Path $venvPath `
    -SupervisorScriptPath $runWanPath `
    -LockedVenvAction $LockedVenvAction
}

function Invoke-NativeWithRetry {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)] [string] $FilePath,
    [Parameter()] [string[]] $ArgumentList = @(),
    [Parameter()] [ValidateRange(1, 10)] [int] $MaxAttempts = 3,
    [Parameter()] [ValidateRange(1, 300)] [int] $InitialDelaySeconds = 5
  )

  for ($attempt = 1; $attempt -le $MaxAttempts; $attempt++) {
    try {
      Invoke-Native -FilePath $FilePath -ArgumentList $ArgumentList
      return
    }
    catch {
      if ($attempt -eq $MaxAttempts) {
        throw
      }

      $delay = $InitialDelaySeconds * [Math]::Pow(2, $attempt - 1)
      Write-Warning ("Command attempt {0}/{1} failed. Retrying in {2} seconds: {3}" -f `
        $attempt, $MaxAttempts, $delay, $_.Exception.Message)
      Start-Sleep -Seconds $delay
    }
  }
}

# -----------------------------------------------------------------------------
# Install or update ComfyUI directly. Do not call `wan2_cli.py install` because
# the current CLI only implements the `start` command.
# -----------------------------------------------------------------------------
if (-not (Test-Path -LiteralPath $mainPy)) {
  if (Test-Path -LiteralPath $comfyPath) {
    $items = @(Get-ChildItem -LiteralPath $comfyPath -Force -ErrorAction SilentlyContinue)
    if ($items.Count -gt 0) {
      throw "The ComfyUI directory exists but main.py is missing: $comfyPath. Rename/remove that incomplete directory and run again."
    }
  }

  Write-Host '[install.ps1] Cloning ComfyUI...' -ForegroundColor Cyan
  Invoke-Native -FilePath 'git' -ArgumentList @(
    'clone',
    '--depth', '1',
    'https://github.com/Comfy-Org/ComfyUI.git',
    $comfyPath
  )
}
elseif (Test-Path -LiteralPath (Join-Path $comfyPath '.git')) {
  Write-Host '[install.ps1] Updating ComfyUI...' -ForegroundColor Cyan

  # A normal git pull refuses to overwrite locally modified ComfyUI core files.
  # Preserve tracked local edits in a named stash, update ComfyUI, and leave the
  # stash intact for manual review. Untracked/ignored custom nodes and models are
  # not stashed or removed.
  $trackedStatus = @(
    & git -C $comfyPath status --porcelain --untracked-files=no
  )
  if ($LASTEXITCODE -ne 0) {
    throw 'Unable to inspect the ComfyUI Git working tree.'
  }

  $autoStashMessage = $null
  if ($trackedStatus.Count -gt 0) {
    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $autoStashMessage = "custom-wan-installer-before-update-$stamp"

    Write-Warning 'Tracked local ComfyUI changes were found. They will be preserved in Git stash before updating.'
    $trackedStatus | ForEach-Object { Write-Host ("  {0}" -f $_) -ForegroundColor Yellow }

    Invoke-Native -FilePath 'git' -ArgumentList @(
      '-C', $comfyPath,
      'stash', 'push',
      '--message', $autoStashMessage
    )
  }

  try {
    Invoke-Native -FilePath 'git' -ArgumentList @('-C', $comfyPath, 'pull', '--ff-only')
  }
  catch {
    # If updating itself fails, restore the just-created stash when possible so
    # the working installation is returned to its previous state.
    if ($autoStashMessage) {
      Write-Warning 'ComfyUI update failed. Attempting to restore the preserved local changes...'
      & git -C $comfyPath stash pop
      if ($LASTEXITCODE -ne 0) {
        Write-Warning "Automatic stash restoration also failed. The changes remain available in git stash: $autoStashMessage"
      }
    }
    throw
  }

  if ($autoStashMessage) {
    $stashRecord = @(
      & git -C $comfyPath stash list --max-count=1 '--format=%gd %s'
    )
    if ($LASTEXITCODE -eq 0 -and $stashRecord.Count -gt 0) {
      Write-Warning ("ComfyUI was updated. Your prior core-file edits remain preserved as: {0}" -f $stashRecord[0])
      Write-Host "Review later: git -C `"$comfyPath`" stash show -p 'stash@{0}'" -ForegroundColor Yellow
      Write-Host "Restore later: git -C `"$comfyPath`" stash apply 'stash@{0}'" -ForegroundColor Yellow
    }
  }
}
else {
  Write-Host '[install.ps1] Existing non-Git ComfyUI installation detected; update skipped.' -ForegroundColor Yellow
}

# -----------------------------------------------------------------------------
# Create/reuse the virtual environment.
# -----------------------------------------------------------------------------
if ((Test-Path -LiteralPath $venvPath) -and -not $ReuseVenv) {
  Write-Host '[install.ps1] Removing the existing virtual environment...' -ForegroundColor Yellow
  Remove-VirtualEnvironment `
    -Path $venvPath `
    -AllowedParentPath $comfyPath `
    -SupervisorScriptPath $runWanPath `
    -LockedVenvAction $LockedVenvAction
}

if (-not (Test-Path -LiteralPath $venvPython)) {
  Write-Host "[install.ps1] Creating Python $PyVersion virtual environment..." -ForegroundColor Cyan
  Invoke-Native -FilePath 'py' -ArgumentList @("-$PyVersion", '-m', 'venv', $venvPath)
}

# Recheck immediately before health checks and package mutation. Editors may
# start a language server while the Git update or venv creation is in progress.
Resolve-VirtualEnvironmentLock `
  -Path $venvPath `
  -SupervisorScriptPath $runWanPath `
  -LockedVenvAction $LockedVenvAction

$venvCheckCode = 'import pathlib, sys; expected = pathlib.Path(sys.argv[1]).resolve(); actual = pathlib.Path(sys.prefix).resolve(); assert actual == expected, f"Unexpected sys.prefix: {actual} != {expected}"'
Invoke-Native -FilePath $venvPython -ArgumentList @('-c', $venvCheckCode, $venvPath)
Invoke-Native -FilePath $venvPython -ArgumentList @('-m', 'pip', '--version')

Invoke-Native -FilePath $venvPython -ArgumentList @('-m', 'pip', 'install', '--upgrade', 'pip', 'setuptools<82', 'wheel', 'build')
$pipNetworkOptions = @('--retries', '10', '--resume-retries', '10', '--timeout', '120')

# -----------------------------------------------------------------------------
# Install PyTorch for the requested compute backend.
# -----------------------------------------------------------------------------
$torchIndex = switch ($Cuda) {
  'cu128' { 'https://download.pytorch.org/whl/cu128' }
  'cu121' { 'https://download.pytorch.org/whl/cu121' }
  'cu118' { 'https://download.pytorch.org/whl/cu118' }
  'cpu'   { 'https://download.pytorch.org/whl/cpu' }
}

Write-Host "[install.ps1] Installing PyTorch build: $Cuda" -ForegroundColor Cyan
Invoke-NativeWithRetry -FilePath $venvPython -ArgumentList (
  @('-m', 'pip', 'install', '--upgrade') +
  $pipNetworkOptions +
  @('torch', 'torchvision', 'torchaudio', '--index-url', $torchIndex)
)

$requirements = Join-Path $comfyPath 'requirements.txt'
if (-not (Test-Path -LiteralPath $requirements)) {
  throw "ComfyUI requirements.txt is missing: $requirements"
}
Invoke-NativeWithRetry -FilePath $venvPython -ArgumentList (@('-m', 'pip', 'install') + $pipNetworkOptions + @('-r', $requirements))

# -----------------------------------------------------------------------------
# Optional ComfyUI Manager.
# -----------------------------------------------------------------------------
if ($WithManager) {
  $customNodes = Join-Path $comfyPath 'custom_nodes'
  $managerPath = Join-Path $customNodes 'ComfyUI-Manager'
  Ensure-Directory $customNodes

  if (-not (Test-Path -LiteralPath (Join-Path $managerPath '.git'))) {
    if (Test-Path -LiteralPath $managerPath) {
      Remove-Item -LiteralPath $managerPath -Recurse -Force
    }
    Write-Host '[install.ps1] Installing ComfyUI-Manager...' -ForegroundColor Cyan
    Invoke-Native -FilePath 'git' -ArgumentList @(
      'clone',
      '--depth', '1',
      'https://github.com/Comfy-Org/ComfyUI-Manager.git',
      $managerPath
    )
  }
  else {
    Invoke-Native -FilePath 'git' -ArgumentList @('-C', $managerPath, 'pull', '--ff-only')
  }

  $managerRequirements = Join-Path $managerPath 'requirements.txt'
  if (Test-Path -LiteralPath $managerRequirements) {
    Invoke-NativeWithRetry -FilePath $venvPython -ArgumentList (@('-m', 'pip', 'install') + $pipNetworkOptions + @('-r', $managerRequirements))
  }
}

# -----------------------------------------------------------------------------
# Environment patches for ONNX, face-swap, and audio custom nodes.
# Use the venv interpreter explicitly; do not depend on activate.ps1 or bare pip.
# -----------------------------------------------------------------------------
$env:GIT_CLONE_PROTECTION_ACTIVE = 'false'

$corePackages = @(
  'protobuf>=4.25,<5',
  'onnx',
  'huggingface_hub',
  'regex',
  'librosa',
  'ffmpeg-python',
  'soundfile'
)

if ($Cuda -eq 'cpu') {
  $corePackages += 'onnxruntime'
}
else {
  $corePackages += 'onnxruntime-gpu'
}

Invoke-NativeWithRetry -FilePath $venvPython -ArgumentList (@('-m', 'pip', 'install', '--upgrade') + $pipNetworkOptions + $corePackages)

# Older revisions installed the unrelated PyPI package named `dac`, which
# downgrades Click/Typer and conflicts with current Hugging Face Hub. Remove
# only that known legacy package before installing the intended audio codec.
& $venvPython -m pip show dac *> $null
if ($LASTEXITCODE -eq 0) {
  Write-Warning "Removing legacy package 'dac'; the intended package is 'descript-audio-codec'."
  Invoke-Native -FilePath $venvPython -ArgumentList @('-m', 'pip', 'uninstall', '-y', 'dac')
}

$optionalPackages = @(
  'insightface',
  'audiotoolbox',
  'descript-audio-codec>=1.0.0',
  'git+https://github.com/descriptinc/audiotools@348ebf2034ce24e2a91a553e3171cb00c0c71678'
)

foreach ($package in $optionalPackages) {
  try {
    Invoke-NativeWithRetry -FilePath $venvPython -ArgumentList (@('-m', 'pip', 'install', '--upgrade') + $pipNetworkOptions + @($package))
  }
  catch {
    Write-Warning "Optional package failed and was skipped: $package`n$($_.Exception.Message)"
  }
}

# Optional audio packages have historically imposed older CLI dependency
# bounds. Restore the core-compatible versions, then require a clean graph.
Invoke-NativeWithRetry -FilePath $venvPython -ArgumentList (
  @('-m', 'pip', 'install', '--upgrade') +
  $pipNetworkOptions +
  @('click>=8.4.2,<9', 'typer>=0.27,<1')
)
Invoke-Native -FilePath $venvPython -ArgumentList @('-m', 'pip', 'check')

# -----------------------------------------------------------------------------
# Download official ComfyUI-packaged Wan 2.2 model files.
# `all` includes 5B TI2V, 14B T2V, and 14B I2V.
# -----------------------------------------------------------------------------
$selectedModelGroups = if ($Models -eq 'all') { @('5b', '14b', 'i2v') } else { @($Models) }
$allowedDestinations = @('diffusion_models', 'text_encoders', 'vae')
foreach ($artifact in $modelManifest.wan.artifacts) {
  $artifactGroups = @($artifact.groups | ForEach-Object { [string] $_ })
  if ('shared' -notin $artifactGroups -and -not @($artifactGroups | Where-Object { $_ -in $selectedModelGroups })) {
    continue
  }
  $destinationGroup = [string] $artifact.destination
  if ($destinationGroup -notin $allowedDestinations) {
    throw "Unsupported model destination in manifest: $destinationGroup"
  }
  $relativePath = [string] $artifact.path
  if ($relativePath -notmatch '^split_files/[A-Za-z0-9._/-]+$' -or $relativePath.Contains('..')) {
    throw "Unsafe model path in manifest: $relativePath"
  }
  $destinationDirectory = Join-Path $comfyPath "models\$destinationGroup"
  Ensure-Directory $destinationDirectory
  Get-HuggingFaceFile `
    -RelativePath $relativePath `
    -Destination (Join-Path $destinationDirectory (Split-Path -Leaf $relativePath))
}

# -----------------------------------------------------------------------------
# Verify Python/PyTorch. CUDA verification is reported clearly but does not hide
# the installed torch build information.
# -----------------------------------------------------------------------------
$verifyCode = @'
import sys
import torch
print('Python:', sys.version.split()[0])
print('Torch:', torch.__version__)
print('Torch CUDA build:', torch.version.cuda)
print('CUDA available:', torch.cuda.is_available())
if torch.cuda.is_available():
    print('GPU:', torch.cuda.get_device_name(0))
'@

Invoke-Native -FilePath $venvPython -ArgumentList @('-c', $verifyCode)

Write-Host ''
Write-Host '[install.ps1] Installation completed.' -ForegroundColor Green
Write-Host ("Root:       {0}" -f $BasePath)
Write-Host ("ComfyUI:    {0}" -f $comfyPath)
Write-Host ("Venv:       {0}" -f $venvPath)
Write-Host ("Models:     {0}" -f $Models)
Write-Host ("Port:       {0}" -f $Port)
Write-Host ''

# -----------------------------------------------------------------------------
# Start only after installation is complete. Global CLI flags are placed before
# the positional `start` command to match the current argparse usage.
# -----------------------------------------------------------------------------
if ($Start) {
  $device = if ($Cuda -eq 'cpu') { 'cpu' } else { 'gpu' }

  if (Test-Path -LiteralPath $cliPath) {
    # Run the launcher inside the same venv where CUDA-enabled PyTorch was installed.
    # Using the global `py` launcher can load a CPU-only torch installation.
    $startArgs = @(
      $cliPath,
      '--path', $BasePath,
      '--port', "$Port",
      '--device', $device
    )
    if ($ListenAll) {
      $startArgs += '--listen-all'
    }
    $startArgs += 'start'

    Invoke-Native -FilePath $venvPython -ArgumentList $startArgs
  }
  else {
    $mainArgs = @($mainPy, '--port', "$Port")
    if ($ListenAll) {
      $mainArgs += @('--listen', '0.0.0.0')
    }
    if ($Cuda -eq 'cpu') {
      $mainArgs += '--cpu'
    }

    Invoke-Native -FilePath $venvPython -ArgumentList $mainArgs
  }
}
else {
  Write-Host 'Start later with:' -ForegroundColor Cyan
  Write-Host ("  & `"{0}`" `"{1}`" --port {2}" -f $venvPython, $mainPy, $Port)
}
