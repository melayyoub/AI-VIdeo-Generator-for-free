<#
.SYNOPSIS
Exports only model files (.safetensors, .ckpt, .pt, .bin)
from a directory and its subfolders to a text file in a tree-style layout.
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$Path,

    [Parameter(Mandatory = $true)]
    [string]$Output
)

if (-not (Test-Path $Path)) {
    Write-Host "The path '$Path' does not exist." -ForegroundColor Red
    exit
}

# Clear or create output file
"" | Out-File -FilePath $Output -Encoding UTF8

# Define model file types
$modelExtensions = @(".safetensors", ".ckpt", ".pt", ".bin")

function Write-ModelsTree {
    param([string]$FolderPath, [int]$Level = 0)

    $indent = ("|   " * $Level)
    $folderName = Split-Path $FolderPath -Leaf

    # Check if the folder or its subfolders contain any model files
    $hasModels = Get-ChildItem -Path $FolderPath -Recurse -File |
        Where-Object { $modelExtensions -contains $_.Extension.ToLower() }

    if ($hasModels.Count -gt 0) {
        Add-Content -Path $Output -Value ("{0}+-- {1}" -f $indent, $folderName)

        # List model files in current folder
        Get-ChildItem -Path $FolderPath -File |
            Where-Object { $modelExtensions -contains $_.Extension.ToLower() } |
            Sort-Object Name |
            ForEach-Object {
                Add-Content -Path $Output -Value ("{0}|   {1}" -f $indent, $_.Name)
            }

        # Recurse into subfolders
        Get-ChildItem -Path $FolderPath -Directory | Sort-Object Name |
            ForEach-Object {
                Write-ModelsTree -FolderPath $_.FullName -Level ($Level + 1)
            }
    }
}

Write-ModelsTree -FolderPath $Path
Write-Host "Model file structure exported to $Output" -ForegroundColor Green
