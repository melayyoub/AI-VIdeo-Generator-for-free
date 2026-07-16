Set-StrictMode -Version Latest

function Resolve-SafeVirtualEnvironmentPath {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [string] $Path,

    [Parameter()]
    [AllowNull()]
    [string] $AllowedParentPath
  )

  if ([string]::IsNullOrWhiteSpace($Path)) {
    throw 'The virtual-environment path cannot be empty.'
  }

  $trimChars = [char[]]@(
    [IO.Path]::DirectorySeparatorChar,
    [IO.Path]::AltDirectorySeparatorChar
  )
  $fullPath = [IO.Path]::GetFullPath($Path).TrimEnd($trimChars)
  $pathRoot = [IO.Path]::GetPathRoot($fullPath).TrimEnd($trimChars)

  if ($fullPath -eq $pathRoot) {
    throw "Refusing to treat a filesystem root as a virtual environment: $fullPath"
  }

  if ([IO.Path]::GetFileName($fullPath) -ne '.venv') {
    throw "Refusing to remove a directory that is not named '.venv': $fullPath"
  }

  if (-not [string]::IsNullOrWhiteSpace($AllowedParentPath)) {
    $allowedParent = [IO.Path]::GetFullPath($AllowedParentPath).TrimEnd($trimChars)
    $actualParent = [IO.Path]::GetDirectoryName($fullPath).TrimEnd($trimChars)
    if (-not $actualParent.Equals($allowedParent, [StringComparison]::OrdinalIgnoreCase)) {
      throw "Refusing to operate outside the allowed virtual-environment parent: $allowedParent"
    }
  }

  if (Test-Path -LiteralPath $fullPath) {
    $item = Get-Item -LiteralPath $fullPath -Force
    if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
      throw "Refusing to recursively remove a virtual-environment reparse point: $fullPath"
    }
  }

  return $fullPath
}

function Test-PathWithinRoot {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)] [string] $Candidate,
    [Parameter(Mandatory = $true)] [string] $Root
  )

  try {
    $trimChars = [char[]]@(
      [IO.Path]::DirectorySeparatorChar,
      [IO.Path]::AltDirectorySeparatorChar
    )
    $candidatePath = [IO.Path]::GetFullPath($Candidate)
    $rootPrefix = [IO.Path]::GetFullPath($Root).TrimEnd($trimChars) + [IO.Path]::DirectorySeparatorChar
    return $candidatePath.StartsWith($rootPrefix, [StringComparison]::OrdinalIgnoreCase)
  }
  catch {
    return $false
  }
}

function Get-VirtualEnvironmentProcess {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [string] $Path
  )

  $fullPath = Resolve-SafeVirtualEnvironmentPath -Path $Path
  if (-not (Test-Path -LiteralPath $fullPath)) {
    return @()
  }

  try {
    $processes = @(Get-CimInstance -ClassName Win32_Process -ErrorAction Stop)
  }
  catch {
    throw "Unable to inspect Windows processes before changing the virtual environment: $($_.Exception.Message)"
  }

  return @(
    $processes | Where-Object {
      -not [string]::IsNullOrWhiteSpace($_.ExecutablePath) -and
      (Test-PathWithinRoot -Candidate $_.ExecutablePath -Root $fullPath)
    } | ForEach-Object {
      [PSCustomObject]@{
        ProcessId      = [int] $_.ProcessId
        ParentProcessId = [int] $_.ParentProcessId
        CreationTicks  = ([DateTime] $_.CreationDate).ToUniversalTime().Ticks
        Name           = [string] $_.Name
        ExecutablePath = [string] $_.ExecutablePath
        BlockerKind    = 'VirtualEnvironment'
      }
    }
  )
}

function Get-VirtualEnvironmentSupervisor {
  [CmdletBinding()]
  param(
    [Parameter()]
    [AllowNull()]
    [string] $SupervisorScriptPath,

    [Parameter(Mandatory = $true)]
    [object[]] $VirtualEnvironmentProcess
  )

  if ([string]::IsNullOrWhiteSpace($SupervisorScriptPath) -or $VirtualEnvironmentProcess.Count -eq 0) {
    return @()
  }

  $fullScriptPath = [IO.Path]::GetFullPath($SupervisorScriptPath)
  try {
    $processes = @(Get-CimInstance -ClassName Win32_Process -ErrorAction Stop)
  }
  catch {
    throw "Unable to inspect Windows processes before changing the virtual environment: $($_.Exception.Message)"
  }

  $processById = @{}
  foreach ($process in $processes) {
    $processById[[int] $process.ProcessId] = $process
  }

  $ancestorIds = [Collections.Generic.HashSet[int]]::new()
  foreach ($venvProcess in $VirtualEnvironmentProcess) {
    $parentId = [int] $venvProcess.ParentProcessId
    while ($parentId -gt 0 -and $processById.ContainsKey($parentId)) {
      if (-not $ancestorIds.Add($parentId)) {
        break
      }
      $parentId = [int] $processById[$parentId].ParentProcessId
    }
  }

  $escapedScriptPath = [Regex]::Escape($fullScriptPath)
  $fileArgumentPattern = '(?i)(?:^|\s)-File\s+(?:"{0}"|''{0}''|{0})(?=\s|$)' -f $escapedScriptPath

  return @(
    $processes | Where-Object {
      $ancestorIds.Contains([int] $_.ProcessId) -and
      $_.Name -in @('powershell.exe', 'pwsh.exe') -and
      -not [string]::IsNullOrWhiteSpace($_.CommandLine) -and
      [Regex]::IsMatch($_.CommandLine, $fileArgumentPattern)
    } | ForEach-Object {
      [PSCustomObject]@{
        ProcessId      = [int] $_.ProcessId
        ParentProcessId = [int] $_.ParentProcessId
        CreationTicks  = ([DateTime] $_.CreationDate).ToUniversalTime().Ticks
        Name           = [string] $_.Name
        ExecutablePath = [string] $_.ExecutablePath
        BlockerKind    = 'Supervisor'
      }
    }
  )
}

function Get-VirtualEnvironmentBlocker {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)] [string] $Path,
    [Parameter()] [AllowNull()] [string] $SupervisorScriptPath
  )

  $venvProcesses = @(Get-VirtualEnvironmentProcess -Path $Path)
  if ($venvProcesses.Count -eq 0) {
    return @()
  }
  $supervisors = @(
    Get-VirtualEnvironmentSupervisor `
      -SupervisorScriptPath $SupervisorScriptPath `
      -VirtualEnvironmentProcess $venvProcesses
  )
  return @($supervisors) + @($venvProcesses)
}

function Format-VirtualEnvironmentProcessList {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [object[]] $Process
  )

  return (($Process | ForEach-Object {
    '{0}: {1} (PID {2}, executable {3})' -f $_.BlockerKind, $_.Name, $_.ProcessId, $_.ExecutablePath
  }) -join [Environment]::NewLine)
}

function Stop-ScopedProcessTree {
  [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
  param(
    [Parameter(Mandatory = $true)]
    [object] $Process,

    [Parameter(Mandatory = $true)]
    [string] $VirtualEnvironmentPath,

    [Parameter()]
    [AllowNull()]
    [string] $SupervisorScriptPath
  )

  $processId = [int] $Process.ProcessId
  $currentMatch = @(
    Get-VirtualEnvironmentBlocker `
      -Path $VirtualEnvironmentPath `
      -SupervisorScriptPath $SupervisorScriptPath |
      Where-Object {
        $_.ProcessId -eq $processId -and
        $_.CreationTicks -eq $Process.CreationTicks -and
        $_.BlockerKind -eq $Process.BlockerKind
      }
  )
  if ($currentMatch.Count -eq 0) {
    Write-Verbose "Scoped process identity changed or exited before stop: PID $processId"
    return
  }

  if (-not $PSCmdlet.ShouldProcess("$($Process.Name) (PID $processId)", 'Stop scoped virtual-environment process tree')) {
    return
  }

  Write-Warning ("Stopping scoped {0} {1} (PID {2}) because it is using the virtual environment." -f `
    $Process.BlockerKind, $Process.Name, $processId)

  $taskkill = Get-Command -Name 'taskkill.exe' -ErrorAction SilentlyContinue
  if ($taskkill) {
    & $taskkill.Source '/PID' "$processId" '/T' '/F' 2>$null | Out-Null
  }
  else {
    Stop-Process -Id $processId -Force -ErrorAction SilentlyContinue
  }

  $deadline = [DateTime]::UtcNow.AddSeconds(5)
  while ((Get-Process -Id $processId -ErrorAction SilentlyContinue) -and
         [DateTime]::UtcNow -lt $deadline) {
    Start-Sleep -Milliseconds 100
  }

  if (Get-Process -Id $processId -ErrorAction SilentlyContinue) {
    throw "Unable to stop $($Process.Name) (PID $processId)."
  }
}

function Resolve-VirtualEnvironmentLock {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [string] $Path,

    [Parameter()]
    [AllowNull()]
    [string] $SupervisorScriptPath,

    [Parameter()]
    [ValidateSet('Stop', 'Fail')]
    [string] $LockedVenvAction = 'Fail'
  )

  $fullPath = Resolve-SafeVirtualEnvironmentPath -Path $Path
  if (-not (Test-Path -LiteralPath $fullPath)) {
    return
  }

  $delays = @(250, 500, 1000, 2000, 4000)
  foreach ($delay in $delays) {
    $blockers = @(Get-VirtualEnvironmentBlocker -Path $fullPath -SupervisorScriptPath $SupervisorScriptPath)
    if ($blockers.Count -eq 0) {
      return
    }

    $processList = Format-VirtualEnvironmentProcessList -Process $blockers
    if ($LockedVenvAction -eq 'Fail') {
      throw ("The virtual environment is in use. Close the scoped processes below, rerun with -LockedVenvAction Stop, or skip rebuilding with -ReuseVenv only if the environment is healthy.{0}{1}" -f `
        [Environment]::NewLine, $processList)
    }

    $supervisors = @($blockers | Where-Object BlockerKind -eq 'Supervisor')
    if ($supervisors.Count -gt 0) {
      foreach ($supervisor in $supervisors) {
        Stop-ScopedProcessTree `
          -Process $supervisor `
          -VirtualEnvironmentPath $fullPath `
          -SupervisorScriptPath $SupervisorScriptPath `
          -Confirm:$false
      }
      Start-Sleep -Milliseconds $delay
      continue
    }

    foreach ($blocker in @($blockers | Where-Object BlockerKind -eq 'VirtualEnvironment')) {
      Stop-ScopedProcessTree `
        -Process $blocker `
        -VirtualEnvironmentPath $fullPath `
        -SupervisorScriptPath $SupervisorScriptPath `
        -Confirm:$false
    }
    Start-Sleep -Milliseconds $delay
  }

  $remaining = @(Get-VirtualEnvironmentBlocker -Path $fullPath -SupervisorScriptPath $SupervisorScriptPath)
  if ($remaining.Count -gt 0) {
    throw ("Processes keep reopening the virtual environment. Close the supervisor or editor and retry.{0}{1}" -f `
      [Environment]::NewLine, (Format-VirtualEnvironmentProcessList -Process $remaining))
  }
}

function Remove-VirtualEnvironment {
  [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
  param(
    [Parameter(Mandatory = $true)]
    [string] $Path,

    [Parameter(Mandatory = $true)]
    [string] $AllowedParentPath,

    [Parameter()]
    [AllowNull()]
    [string] $SupervisorScriptPath,

    [Parameter()]
    [ValidateSet('Stop', 'Fail')]
    [string] $LockedVenvAction = 'Fail',

    [Parameter()]
    [ValidateRange(1, 20)]
    [int] $RetryCount = 6,

    [Parameter()]
    [ValidateRange(50, 5000)]
    [int] $RetryDelayMilliseconds = 500
  )

  $fullPath = Resolve-SafeVirtualEnvironmentPath -Path $Path -AllowedParentPath $AllowedParentPath
  if (-not (Test-Path -LiteralPath $fullPath)) {
    return
  }

  if (-not $PSCmdlet.ShouldProcess($fullPath, 'Stop scoped users and recursively remove virtual environment')) {
    return
  }

  $lastError = $null
  for ($attempt = 1; $attempt -le $RetryCount; $attempt++) {
    Resolve-VirtualEnvironmentLock `
      -Path $fullPath `
      -SupervisorScriptPath $SupervisorScriptPath `
      -LockedVenvAction $LockedVenvAction

    try {
      [void] (Resolve-SafeVirtualEnvironmentPath -Path $fullPath -AllowedParentPath $AllowedParentPath)
      Remove-Item -LiteralPath $fullPath -Recurse -Force -ErrorAction Stop
      if (-not (Test-Path -LiteralPath $fullPath)) {
        return
      }
      $lastError = "The directory still exists after Remove-Item returned: $fullPath"
    }
    catch {
      $lastError = $_.Exception.Message
    }

    if ($attempt -lt $RetryCount) {
      Start-Sleep -Milliseconds $RetryDelayMilliseconds
    }
  }

  $remaining = @(Get-VirtualEnvironmentBlocker -Path $fullPath -SupervisorScriptPath $SupervisorScriptPath)
  $lockHint = if ($remaining.Count -gt 0) {
    '{0}Remaining scoped processes:{0}{1}' -f [Environment]::NewLine, (Format-VirtualEnvironmentProcessList -Process $remaining)
  }
  else {
    ' Antivirus, indexing, an editor, or another uninspectable process may still hold a file open.'
  }

  throw ("Unable to remove the virtual environment after {0} attempts: {1}.{2} Last error: {3}" -f `
    $RetryCount, $fullPath, $lockHint, $lastError)
}

Export-ModuleMember -Function `
  Get-VirtualEnvironmentProcess, `
  Resolve-VirtualEnvironmentLock, `
  Remove-VirtualEnvironment
