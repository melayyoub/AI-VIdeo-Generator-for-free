@echo off
setlocal EnableExtensions
title Install ACE-Step-ComfyUI for ComfyUI Windows Portable

cd /d "%~dp0"

echo.
echo ============================================================
echo   ACE-Step-ComfyUI installer - Windows Portable
echo ============================================================
echo.

if not exist "python_embeded\python.exe" (
    echo ERROR: python_embeded\python.exe was not found.
    echo Put this BAT file in the ComfyUI_windows_portable root folder,
    echo beside python_embeded and the ComfyUI folder.
    echo.
    pause
    exit /b 1
)

if not exist "ComfyUI\custom_nodes" (
    echo ERROR: ComfyUI\custom_nodes was not found.
    echo This BAT must be run from the ComfyUI_windows_portable root folder.
    echo.
    pause
    exit /b 1
)

where git >nul 2>nul
if errorlevel 1 (
    echo ERROR: Git is not installed or is not available in PATH.
    echo Install Git for Windows, reopen this folder, and run the BAT again.
    echo.
    pause
    exit /b 1
)

set "NODEDIR=ComfyUI\custom_nodes\ACE-Step-ComfyUI"

if exist "%NODEDIR%\.git" (
    echo Updating existing official ACE-Step-ComfyUI checkout...
    git -C "%NODEDIR%" pull --ff-only
    if errorlevel 1 goto :fail
) else if exist "%NODEDIR%" (
    echo ERROR: "%NODEDIR%" exists but is not a Git checkout.
    echo This is commonly caused by an incorrectly extracted or nested ZIP.
    echo Rename or remove that folder, then run this BAT again.
    echo Expected files directly inside it:
    echo   __init__.py
    echo   nodes.py
    echo   requirements.txt
    echo   js\
    echo.
    pause
    exit /b 1
) else (
    echo Cloning the official repository...
    git clone https://github.com/ace-step/ACE-Step-ComfyUI.git "%NODEDIR%"
    if errorlevel 1 goto :fail
)

echo.
echo Installing requirements into ComfyUI's embedded Python...
"python_embeded\python.exe" -m pip install -r "%NODEDIR%\requirements.txt"
if errorlevel 1 goto :fail

echo.
echo Checking required Python imports...
"python_embeded\python.exe" -c "import torch, numpy, requests; print('Dependencies OK | torch=' + torch.__version__ + ' | numpy=' + numpy.__version__ + ' | requests=' + requests.__version__)"
if errorlevel 1 goto :fail

if not exist "%NODEDIR%\__init__.py" goto :badlayout
if not exist "%NODEDIR%\nodes.py" goto :badlayout
if not exist "%NODEDIR%\js" goto :badlayout

echo.
echo ============================================================
echo SUCCESS
echo ============================================================
echo Fully close ComfyUI, start it again, then refresh the browser.
echo Search the node library for:
echo   ACE-Step Settings
echo   ACE-Step Text2music Gen Params
echo   ACE-Step Text2music Server
echo   ACE-Step Show Text
echo.
echo If they are still absent, inspect the ComfyUI startup window for:
echo   IMPORT FAILED ... ACE-Step-ComfyUI
echo and copy the complete traceback.
echo.
pause
exit /b 0

:badlayout
echo.
echo ERROR: Repository folder layout is incomplete.
echo Expected "%NODEDIR%\__init__.py", nodes.py, and js\.
echo.
pause
exit /b 1

:fail
echo.
echo INSTALLATION FAILED.
echo Read the error directly above this message.
echo.
pause
exit /b 1
