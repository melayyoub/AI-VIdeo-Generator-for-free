# 1. Merge all requirements into a raw file
Get-ChildItem -Path .\ComfyUI\custom_nodes -Recurse -Filter requirements.txt |
    ForEach-Object { Get-Content $_.FullName } |
    Sort-Object -Unique |
    Set-Content all-requirements-raw.txt

# 2. Dynamic cleanup
$requirements = Get-Content all-requirements-raw.txt
$best = @{}

# Get list of already installed packages
$installed = pip list --format=freeze | ForEach-Object {
    ($_ -split '==')[0].ToLower()
}

foreach ($line in $requirements) {
    if ($line -match '^\s*$' -or $line -match '^\s*#') { continue } # skip empty/comments

    # 🚫 Skip unwanted/problematic packages
    if ($line -match '^(deepspeed|tensorflow==2\.6\.2|numpy==1\.20\.3|tensorflow-addons|tensorboardx==0|opencv-python-headless==|apache-beam|matplotlib)') { continue }
    if ($line -match '^librosa') { continue }
    # Extract package name
    if ($line -match '^([A-Za-z0-9_\-]+)') {
        $pkg = $matches[1].ToLower()

        # 🚫 Skip if already installed
        if ($installed -contains $pkg) { continue }

        if (-not $best.ContainsKey($pkg)) {
            $best[$pkg] = $line
        }
        else {
            if ($line -match '>=') {
                $best[$pkg] = $line
            }
            elseif ($line -match '==') {
                $currMatch = $best[$pkg] -replace '[^\d\.]', ''
                $newMatch  = $line -replace '[^\d\.]', ''
                if ($currMatch -and $newMatch) {
                    try {
                        $currVer = [version]$currMatch
                        $newVer  = [version]$newMatch
                        if ($newVer -gt $currVer) {
                            $best[$pkg] = $line
                        }
                    } catch {
                        # ignore invalid versions
                    }
                }
            }
        }
    }
}

# 3. Write cleaned requirements
$best.Values | Sort-Object | Set-Content all-requirements.txt

# 4. Force modern, compatible versions
@(
    "numpy>=2.0.0,<2.3.0"
    "opencv-python-headless==4.12.0.88"
    "tensorflow>=2.16.0"
    "tensorboardX==2.6.4"
    "librosa>=0.10.1"
) | ForEach-Object { Add-Content all-requirements.txt $_ }

# 5. Install
pip install --upgrade pip setuptools wheel build
pip install -r all-requirements.txt
