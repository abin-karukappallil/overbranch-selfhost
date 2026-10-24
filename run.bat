@echo off
setlocal
cd /d "%~dp0"

where python >nul 2>nul
if %ERRORLEVEL% equ 0 (
    python run.py %*
) else (
    echo Error: Python is required to run OverBranch Self-Host.
    pause
    exit /b 1
)
