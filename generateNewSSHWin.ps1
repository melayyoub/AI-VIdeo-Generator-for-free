[CmdletBinding()]
param(
    [string] $KeyPath = (Join-Path $HOME '.ssh\id_ed25519'),
    [string] $Comment = $(if ($env:CUSTOM_WAN_SSH_KEY_COMMENT) { $env:CUSTOM_WAN_SSH_KEY_COMMENT } else { 'custom-wan' })
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$keyFullPath = [IO.Path]::GetFullPath($KeyPath)
if (Test-Path -LiteralPath $keyFullPath) {
    throw "Refusing to overwrite an existing SSH key: $keyFullPath"
}
New-Item -ItemType Directory -Path (Split-Path -Parent $keyFullPath) -Force | Out-Null

& ssh-keygen -t ed25519 -C $Comment -f $keyFullPath
if ($LASTEXITCODE -ne 0) { throw 'ssh-keygen failed.' }

$agent = Get-Service ssh-agent -ErrorAction Stop
if ($agent.Status -ne 'Running') { Start-Service ssh-agent }
& ssh-add $keyFullPath
if ($LASTEXITCODE -ne 0) { throw 'ssh-add failed.' }

Write-Output 'Add this public key to your Git hosting account:'
Get-Content -LiteralPath "$keyFullPath.pub"
