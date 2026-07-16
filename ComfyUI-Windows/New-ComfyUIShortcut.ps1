[CmdletBinding()]
param(
    [string] $ProjectPath = (Split-Path -Parent $PSScriptRoot),
    [string] $ShortcutPath,
    [ValidateRange(1, 65535)]
    [int] $Port = 8188,
    [switch] $OpenBrowser
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$projectRoot = [IO.Path]::GetFullPath($ProjectPath)
$launcher = Join-Path $PSScriptRoot 'run_wan.ps1'
if (-not (Test-Path -LiteralPath $launcher -PathType Leaf)) {
    throw "Launcher was not found: $launcher"
}

if ([string]::IsNullOrWhiteSpace($ShortcutPath)) {
    $ShortcutPath = Join-Path $PSScriptRoot 'ComfyUI.lnk'
}
$shortcutFullPath = [IO.Path]::GetFullPath($ShortcutPath)
$shortcutDirectory = Split-Path -Parent $shortcutFullPath
if (-not (Test-Path -LiteralPath $shortcutDirectory -PathType Container)) {
    New-Item -ItemType Directory -Path $shortcutDirectory -Force | Out-Null
}

$powerShell = Get-Command pwsh.exe -ErrorAction SilentlyContinue
if ($null -eq $powerShell) {
    $powerShell = Get-Command powershell.exe -ErrorAction Stop
}

$arguments = @(
    '-NoProfile',
    '-File',
    ('"{0}"' -f $launcher),
    '-ProjectPath',
    ('"{0}"' -f $projectRoot),
    '-Port',
    $Port
)
if ($OpenBrowser) {
    $arguments += '-OpenBrowser'
}

$shell = New-Object -ComObject WScript.Shell
$shortcut = $shell.CreateShortcut($shortcutFullPath)
$shortcut.TargetPath = $powerShell.Source
$shortcut.Arguments = $arguments -join ' '
$shortcut.WorkingDirectory = $projectRoot
$shortcut.Description = 'Start the local Custom Wan ComfyUI service'
$shortcut.Save()

Write-Output "Created portable shortcut: $shortcutFullPath"
