[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$portTestPath = Join-Path $PSScriptRoot 'port-validation.Tests.ps1'
& pwsh -NoProfile -File $portTestPath
if ($LASTEXITCODE -ne 0) {
  throw "Port validation test failed with exit code $LASTEXITCODE."
}

if (-not [Runtime.InteropServices.RuntimeInformation]::IsOSPlatform(
  [Runtime.InteropServices.OSPlatform]::Windows
)) {
  Write-Output 'SKIP: Windows virtual-environment lock integration test'
  exit 0
}

$testPath = Join-Path $PSScriptRoot 'install-venv.Tests.ps1'

& pwsh -NoProfile -File $testPath
if ($LASTEXITCODE -ne 0) {
  throw "PowerShell 7 installer test failed with exit code $LASTEXITCODE."
}

& powershell.exe -NoProfile -File $testPath
if ($LASTEXITCODE -ne 0) {
  throw "Windows PowerShell 5.1 installer test failed with exit code $LASTEXITCODE."
}
