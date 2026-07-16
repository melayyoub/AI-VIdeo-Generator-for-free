[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repositoryRoot = Split-Path -Parent $PSScriptRoot
Set-Location $repositoryRoot

function Assert-NativeSuccess {
  param([Parameter(Mandatory = $true)] [string] $Description)

  if ($LASTEXITCODE -ne 0) {
    throw "$Description failed with exit code $LASTEXITCODE."
  }
}

$powerShellFiles = @(
  Get-ChildItem -LiteralPath $repositoryRoot -File -Filter '*.ps1' |
    Where-Object Name -NotIn @('install-broken.ps1', 'install.old.ps1')
  Get-ChildItem -LiteralPath (Join-Path $repositoryRoot 'ComfyUI-Windows') -File -Filter '*.ps1'
  Get-ChildItem -LiteralPath (Join-Path $repositoryRoot 'scripts') -File -Filter '*.psm1'
  Get-ChildItem -LiteralPath $PSScriptRoot -File -Filter '*.ps1'
)

foreach ($file in $powerShellFiles) {
  $tokens = $null
  $errors = $null
  [void] [Management.Automation.Language.Parser]::ParseFile(
    $file.FullName,
    [ref] $tokens,
    [ref] $errors
  )
  if ($errors.Count -gt 0) {
    $messages = ($errors | ForEach-Object Message) -join [Environment]::NewLine
    throw "PowerShell parse failed for $($file.FullName):$([Environment]::NewLine)$messages"
  }
}
Write-Output "PASS: parsed $($powerShellFiles.Count) PowerShell files"

$pythonFiles = @(
  Get-ChildItem -LiteralPath $repositoryRoot -File -Filter '*.py'
  Get-ChildItem -LiteralPath (Join-Path $repositoryRoot 'patches') -File -Filter '*.py'
)
$pythonPaths = @($pythonFiles | ForEach-Object FullName)
$compileCode = "import ast,pathlib,sys; [ast.parse(pathlib.Path(p).read_text(encoding='utf-8-sig'), filename=p) for p in sys.argv[1:]]"
if (Get-Command py -ErrorAction SilentlyContinue) {
  & py '-3.10' '-c' $compileCode @pythonPaths
}
elseif (Get-Command python3 -ErrorAction SilentlyContinue) {
  & python3 '-c' $compileCode @pythonPaths
}
else {
  throw 'Python 3 is required for source validation.'
}
Assert-NativeSuccess 'Python source compilation'
Write-Output "PASS: compiled $($pythonFiles.Count) Python files without writing bytecode"

foreach ($workflow in Get-ChildItem -LiteralPath (Join-Path $repositoryRoot 'examples') -File -Filter '*.json') {
  Get-Content -Raw -LiteralPath $workflow.FullName | ConvertFrom-Json | Out-Null
}
Write-Output 'PASS: parsed example workflow JSON files'

$trackedFiles = @(& git ls-files)
Assert-NativeSuccess 'Tracked-file inventory'
$forbiddenPatterns = @(
  ('(?i)[a-z]:\\' + 'Users\\'),
  ('(?i)[a-z]:\\[^\r\n]*\\python-' + 'projects\\'),
  ('(?i)/ho' + 'me/[^/\s]+/'),
  ('(?i)/Us' + 'ers/[^/\s]+/')
)
$textExtensions = @('.json', '.md', '.ps1', '.psm1', '.py', '.sh', '.txt', '.yml', '.yaml')
foreach ($trackedFile in $trackedFiles) {
  if ($textExtensions -notcontains [IO.Path]::GetExtension($trackedFile)) {
    continue
  }
  $fullTrackedPath = Join-Path $repositoryRoot $trackedFile
  if (-not (Test-Path -LiteralPath $fullTrackedPath -PathType Leaf)) {
    continue
  }
  $content = Get-Content -Raw -LiteralPath $fullTrackedPath -ErrorAction Stop
  foreach ($pattern in $forbiddenPatterns) {
    if ($content -match $pattern) {
      throw "Tracked file contains a personal or machine-specific value: $trackedFile"
    }
  }
}
Write-Output 'PASS: tracked text files contain no personal or machine-specific paths'

if (-not (Get-Command ruff -ErrorAction SilentlyContinue)) {
  throw 'ruff is required for source validation.'
}
& ruff check --exclude ComfyUI --exclude hf_cache .
Assert-NativeSuccess 'Ruff'

if ($IsWindows) {
  $gitExecutable = (Get-Command git -ErrorAction Stop).Source
  $gitRoot = Split-Path -Parent (Split-Path -Parent $gitExecutable)
  $bash = Join-Path $gitRoot 'bin\bash.exe'
  if (-not (Test-Path -LiteralPath $bash -PathType Leaf)) {
    $bash = (Get-Command bash -ErrorAction Stop).Source
  }
}
else {
  $bash = (Get-Command bash -ErrorAction Stop).Source
}
& $bash -n install.sh installme.sh generateNewSShKey.sh
Assert-NativeSuccess 'Bash syntax validation'

$unixDryRun = @(
  & $bash install.sh --cuda=cu128 --models=5b --with-manager=false --start=false --listen-all=false --reuse-venv=false --dry-run=true
)
$unixDryRun | Write-Output
Assert-NativeSuccess 'Unix installer dry run'
$targetVenvPython = if ($IsWindows) {
  Join-Path $repositoryRoot 'ComfyUI\.venv\Scripts\python.exe'
}
else {
  Join-Path $repositoryRoot 'ComfyUI/.venv/bin/python'
}
$unsafeRecreationPattern = [Regex]::Escape($targetVenvPython) + '\s+-m\s+venv\s+'
if (($unixDryRun -join [Environment]::NewLine) -match $unsafeRecreationPattern) {
  throw 'Unix installer cannot recreate a venv using the interpreter inside that same venv.'
}

if ($IsWindows) {
  $npm = 'npm.cmd'
}
else {
  $npm = 'npm'
}
& $npm install --package-lock-only --ignore-scripts --offline
Assert-NativeSuccess 'Offline npm lockfile validation'
& git diff --exit-code -- package.json package-lock.json
Assert-NativeSuccess 'npm metadata consistency'

Write-Output 'PASS: repository validation suite'
