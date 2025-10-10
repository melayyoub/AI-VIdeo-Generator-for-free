# Rename-FoxWolf.ps1
param(
    [Parameter(Mandatory=$true)]
    [string]$Path,

    [switch]$Preview
)

$files = Get-ChildItem -Path $Path -Filter *.png

foreach ($f in $files) {
    $name = $f.BaseName
    $ext  = $f.Extension
    Write-Host "file is: $($f.Extension) $($f.BaseName)" -ForegroundColor Red
    # Match pattern: FoxWolfMeme_<group>_<number>_
    if ($name -match '^minime_(\d+)_(\d+)_$') {
        $num = [int]$matches[1]   # remove leading zeros

        # New name
        $newName = "minime_${num}${ext}"
        $newPath = Join-Path $f.DirectoryName $newName

        if ($newName -ne $f.Name) {
            Write-Host "Rename:`n  From: $($f.Name)`n  To:   $newName" -ForegroundColor Cyan

            if (-not $Preview) {
                Rename-Item -LiteralPath $f.FullName -NewName $newName
            }
        }
    } else {
        Write-Host "Skipping (no match): $($f.Name)" -ForegroundColor Yellow
    }
}

if ($Preview) {
    Write-Host "`nPreview mode only, no files renamed." -ForegroundColor Yellow
} else {
    Write-Host "`nDone." -ForegroundColor Green
}
