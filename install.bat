@echo off
setlocal
cd /d "%~dp0"

echo ============================================================
echo   OverBranch Self-Host Windows Installer (Docker Compose)
echo ============================================================
echo.

where powershell >nul 2>nul
if %ERRORLEVEL% equ 0 (
    powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0install.ps1" %*
) else (
    call "%~dp0docker-up.bat" %*
)
