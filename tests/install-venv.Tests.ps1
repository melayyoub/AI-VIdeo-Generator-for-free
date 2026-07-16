[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repositoryRoot = Split-Path -Parent $PSScriptRoot
$modulePath = Join-Path $repositoryRoot 'scripts\Installer.Venv.psm1'
Import-Module $modulePath -Force

function Assert-True {
  param(
    [Parameter(Mandatory = $true)] [bool] $Condition,
    [Parameter(Mandatory = $true)] [string] $Message
  )

  if (-not $Condition) {
    throw "Assertion failed: $Message"
  }
}

$testRoot = Join-Path $repositoryRoot ('.test-tmp\installer-venv-{0}' -f [Guid]::NewGuid().ToString('N'))
$venvPath = Join-Path $testRoot '.venv'
$pythonPath = Join-Path $venvPath 'Scripts\python.exe'
$process = $null

try {
  New-Item -ItemType Directory -Path $testRoot -Force | Out-Null

  & py '-3.10' '-m' 'venv' $venvPath
  if ($LASTEXITCODE -ne 0) {
    throw "Unable to create the test virtual environment (exit $LASTEXITCODE)."
  }
  Assert-True (Test-Path -LiteralPath $pythonPath) 'the temporary venv Python executable should exist'

  $process = Start-Process -FilePath $pythonPath -ArgumentList @('-c', '"import time; time.sleep(120)"') -PassThru -WindowStyle Hidden
  Start-Sleep -Milliseconds 750
  Assert-True (-not $process.HasExited) 'the temporary venv process should be running'

  $nativeLockObserved = $false
  try {
    Remove-Item -LiteralPath $pythonPath -Force -ErrorAction Stop
  }
  catch [UnauthorizedAccessException] {
    $nativeLockObserved = $true
  }
  catch [IO.IOException] {
    $nativeLockObserved = $true
  }
  Assert-True $nativeLockObserved 'Windows should reject direct deletion of the running venv executable'
  Assert-True (Test-Path -LiteralPath $pythonPath) 'the locked venv executable should remain present'

  $detected = @(Get-VirtualEnvironmentProcess -Path $venvPath)
  Assert-True ($detected.ProcessId -contains $process.Id) 'the running venv process should be detected by executable path'

  $failedSafely = $false
  try {
    Remove-VirtualEnvironment -Path $venvPath -AllowedParentPath $testRoot -LockedVenvAction Fail
  }
  catch {
    $failedSafely = $_.Exception.Message -like '*virtual environment is in use*'
  }
  Assert-True $failedSafely 'Fail policy should report the lock without deleting the venv'
  Assert-True (Test-Path -LiteralPath $venvPath) 'Fail policy should preserve the venv'
  Assert-True (-not $process.HasExited) 'Fail policy should preserve the running process'

  Remove-VirtualEnvironment -Path $venvPath -AllowedParentPath $testRoot -LockedVenvAction Stop
  $process.Refresh()
  Assert-True $process.HasExited 'Stop policy should terminate the venv process tree'
  Assert-True (-not (Test-Path -LiteralPath $venvPath)) 'Stop policy should remove the venv'

  $unsafePath = Join-Path $testRoot 'not-a-venv'
  New-Item -ItemType Directory -Path $unsafePath -Force | Out-Null
  $guarded = $false
  try {
    Remove-VirtualEnvironment -Path $unsafePath -AllowedParentPath $testRoot
  }
  catch {
    $guarded = $_.Exception.Message -like "*not named '.venv'*"
  }
  Assert-True $guarded 'the deletion guard should reject directories not named .venv'
  Assert-True (Test-Path -LiteralPath $unsafePath) 'the deletion guard should preserve rejected directories'

  Write-Output 'PASS: installer virtual-environment process and deletion policies'
}
finally {
  if ($null -ne $process -and -not $process.HasExited) {
    Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue
  }
  if (Test-Path -LiteralPath $testRoot) {
    Remove-Item -LiteralPath $testRoot -Recurse -Force -ErrorAction SilentlyContinue
  }
}
