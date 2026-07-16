[CmdletBinding()]
param(
    [string] $ProjectPath = (Split-Path -Parent $PSScriptRoot),
    [ValidateRange(1, 65535)]
    [int] $Port = 8188,
    [switch] $OpenBrowser,
    [ValidateRange(1, 300)]
    [int] $RestartDelaySeconds = 3
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$projectRoot = [IO.Path]::GetFullPath($ProjectPath)
$pythonExe = Join-Path $projectRoot 'ComfyUI\.venv\Scripts\python.exe'
$launcher = Join-Path $projectRoot 'wan2_cli.py'
$logOut = Join-Path $projectRoot 'output.log'
$logErr = Join-Path $projectRoot 'error.log'

if (-not (Test-Path -LiteralPath $pythonExe -PathType Leaf)) {
    throw "Virtual-environment Python was not found: $pythonExe"
}
if (-not (Test-Path -LiteralPath $launcher -PathType Leaf)) {
    throw "Launcher was not found: $launcher"
}

Set-Location -LiteralPath $projectRoot

Write-Host '====================================='
Write-Host ' WAN Service Launcher'
Write-Host '====================================='
Write-Host "Logs:`n - $logOut`n - $logErr"

$wanProcess = $null
$browserOpened = $false

try {
    while ($true) {
        Write-Host "`n[$(Get-Date -Format o)] Starting..."

        $arguments = @(
            ('"{0}"' -f $launcher),
            'start',
            '--path',
            ('"{0}"' -f $projectRoot),
            '--port',
            $Port
        ) -join ' '

        try {
            $wanProcess = Start-Process `
                -FilePath $pythonExe `
                -ArgumentList $arguments `
                -WorkingDirectory $projectRoot `
                -RedirectStandardOutput $logOut `
                -RedirectStandardError $logErr `
                -NoNewWindow `
                -PassThru

            Start-Sleep -Seconds 2
            if ($wanProcess.HasExited) {
                Write-Warning "Process exited immediately with code $($wanProcess.ExitCode)."
            }
            else {
                $url = "http://127.0.0.1:$Port"
                Write-Host "Running at $url"
                if ($OpenBrowser -and -not $browserOpened) {
                    Start-Process $url
                    $browserOpened = $true
                }
            }

            Wait-Process -Id $wanProcess.Id
        }
        catch {
            Write-Warning $_.Exception.Message
        }

        Write-Host "Restarting in $RestartDelaySeconds seconds..."
        Start-Sleep -Seconds $RestartDelaySeconds
    }
}
finally {
    if ($wanProcess -and -not $wanProcess.HasExited) {
        taskkill.exe /PID $wanProcess.Id /T /F 2>$null | Out-Null
    }
}
