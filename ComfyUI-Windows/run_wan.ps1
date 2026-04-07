# =========================
# WAN Service Launcher
# =========================

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Config
$projectPath = "E:\python-projects\custom-wan"
$pythonExe = "$projectPath\ComfyUI\.venv\Scripts\python.exe"
$args = "wan2_cli.py start --path . --port 8188"

# Logs
$logOut = "$projectPath\output.log"
$logErr = "$projectPath\error.log"

# Move to project directory
Set-Location $projectPath

Write-Host "====================================="
Write-Host "   WAN Service Launcher Started"
Write-Host "====================================="
Write-Host "Logs:"
Write-Host " - Output: $logOut"
Write-Host " - Error : $logErr"
Write-Host ""
Write-Host "Close this window to stop the service."
Write-Host ""

# Global process reference
$global:process = $null

# Cleanup on exit
$null = Register-EngineEvent PowerShell.Exiting -Action {
    if ($global:process -and -not $global:process.HasExited) {
        Write-Host "`nStopping Python process..."
        Stop-Process -Id $global:process.Id -Force
    }
}

# Restart loop
while ($true) {
    Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] Starting service..."

    $global:process = Start-Process `
        -FilePath $pythonExe `
        -ArgumentList $args `
        -RedirectStandardOutput $logOut `
        -RedirectStandardError $logErr `
        -NoNewWindow `
        -PassThru

    try {
        Wait-Process -Id $global:process.Id
    }
    catch {
        Write-Warning "Process interrupted."
    }

    if ($global:process.HasExited) {
        Write-Warning "[$(Get-Date -Format 'HH:mm:ss')] Process exited. Restarting in 3 seconds..."
        Start-Sleep -Seconds 3
    }
}