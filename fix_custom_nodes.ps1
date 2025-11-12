$venv = "E:\python-projects\custom-wan\ComfyUI\.venv\Scripts\python.exe"
$comfy = "E:\python-projects\custom-wan\ComfyUI"

# Kill running ComfyUI
taskkill /IM python.exe /F 2>$null

# Update huggingface & transformers properly
& $venv -m pip install --upgrade --no-cache-dir huggingface_hub transformers diffusers tokenizers accelerate

# Patch every custom node calling cached_download
Get-ChildItem -Path "$comfy\custom_nodes" -Recurse -Include *.py |
    Select-String -Pattern "cached_download" -List |
    ForEach-Object {
        (Get-Content $_.Path) |
            ForEach-Object { $_ -replace "from huggingface_hub import cached_download", "from huggingface_hub import hf_hub_download as cached_download" } |
            Set-Content $_.Path
        Write-Host "Patched: $($_.Path)"
    }

Write-Host "`n✅ Patch complete! Restart ComfyUI."
