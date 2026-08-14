Set-StrictMode -Version Latest

function Resolve-TestPython {
    <#
    .SYNOPSIS
    Returns a command-line array (executable plus optional launcher argument)
    for a Python 3.10+ interpreter, or throws when none is available.

    Compatible with Windows PowerShell 5.1 and PowerShell 7.
    #>
    [CmdletBinding()]
    param()

    $versionProbe = 'import sys; sys.exit(0 if sys.version_info >= (3, 10) else 1)'
    $candidates = @(
        ,@('py', '-3.10')
        ,@('py', '-3')
        ,@('python3')
        ,@('python')
    )

    foreach ($candidate in $candidates) {
        $executable = $candidate[0]
        if (-not (Get-Command $executable -ErrorAction SilentlyContinue)) {
            continue
        }
        $arguments = @()
        if ($candidate.Count -gt 1) {
            $arguments = @($candidate[1..($candidate.Count - 1)])
        }
        & $executable @arguments '-c' $versionProbe 2>$null
        if ($LASTEXITCODE -eq 0) {
            return $candidate
        }
    }

    throw 'Python 3.10 or newer was not found (tried: py -3.10, py -3, python3, python).'
}

Export-ModuleMember -Function Resolve-TestPython
