# =========================
# WAN Service Launcher (STABLE)
# =========================

$ErrorActionPreference = "Continue"

# Config
$projectPath = "E:\python-projects\custom-wan"
$pythonExe   = "$projectPath\ComfyUI\.venv\Scripts\python.exe"
$args        = "wan2_cli.py start --path . --port 8188"

$logOut = "$projectPath\output.log"
$logErr = "$projectPath\error.log"

# Validate
if (!(Test-Path $projectPath)) { Write-Host "Bad project path"; Read-Host; exit }
if (!(Test-Path $pythonExe))   { Write-Host "Bad python path"; Read-Host; exit }

Set-Location $projectPath

Write-Host "====================================="
Write-Host " WAN Service Launcher (Stable Mode)"
Write-Host "====================================="
Write-Host "Logs:"
Write-Host " - $logOut"
Write-Host " - $logErr"
Write-Host ""

$process = $null

# Kill on exit
Register-EngineEvent PowerShell.Exiting -Action {
    if ($process -and -not $process.HasExited) {
        taskkill /PID $process.Id /T /F | Out-Null
    }
} | Out-Null

while ($true) {

    Write-Host "`n[$(Get-Date)] Starting..."

    try {
        $process = Start-Process `
            -FilePath $pythonExe `
            -ArgumentList $args `
            -WorkingDirectory $projectPath `
            -RedirectStandardOutput $logOut `
            -RedirectStandardError $logErr `
            -NoNewWindow `
            -PassThru

        Start-Sleep 2

        if ($process.HasExited) {
            Write-Host "❌ Crashed immediately (exit $($process.ExitCode))"
        }
        else {
            Write-Host "✅ Running at http://localhost:8188"
            Start-Process "http://localhost:8188"
        }

        Wait-Process -Id $process.Id
    }
    catch {
        Write-Host "ERROR:"
        Write-Host $_
    }

    Write-Host "Restarting in 3 seconds..."
    Start-Sleep 3
}