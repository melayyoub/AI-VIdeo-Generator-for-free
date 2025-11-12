# --- Activate venv ---
# $venv = ".\.venv\Scripts\Activate.ps1"
# if (Test-Path $venv) { & $venv } else { Write-Host "Venv not found."; exit }

Write-Host ""
Write-Host "[1/5] Fixing core compatibility versions..." -ForegroundColor Cyan

pip install --no-cache-dir --force-reinstall `
 numpy==1.26.4 `
 pydantic==2.9.2 `
 protobuf==3.20.3 `
 huggingface_hub==0.25.2

Write-Host ""
Write-Host "[2/5] Installing Fish-Speech required dependencies..." -ForegroundColor Cyan

pip install --no-cache-dir --force-reinstall `
 datasets==2.18.0 `
 modelscope==1.17.1 `
 einx[torch]==0.2.2 `
 tiktoken>=0.8.0 `
 resampy>=0.4.3 `
 silero-vad `
 pyrootutils>=1.0.4 `
 opencc-python-reimplemented==0.1.7 `
 ormsgpack

Write-Host ""
Write-Host "[3/5] Installing Fish-Speech..." -ForegroundColor Cyan
pip install --no-cache-dir --force-reinstall fish-speech==0.1.0 --no-deps

Write-Host ""
# Write-Host "[4/5] Installing SenseVoice (Arabic TTS)..." -ForegroundColor Cyan
# pip install --no-cache-dir --force-reinstall sense-voice==1.1.6 --no-deps

Write-Host ""
Write-Host "[5/5] Cleaning Pip Cache..." -ForegroundColor Cyan
pip cache purge

Write-Host ""
Write-Host "DONE - Restart ComfyUI now." -ForegroundColor Green
