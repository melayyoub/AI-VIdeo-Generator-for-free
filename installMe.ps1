Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$installer = Join-Path $PSScriptRoot 'install.ps1'
Write-Warning 'installMe.ps1 is a compatibility wrapper. Prefer install.ps1 for new automation.'
& $installer @args
