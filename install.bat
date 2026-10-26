@echo off
setlocal enabledelayedexpansion

echo ============================================================
echo        OverBranch Self-Host Installer for Windows
echo ============================================================

set "PY_CMD=python"
where python >nul 2>nul
if %ERRORLEVEL% neq 0 (
    where py >nul 2>nul
    if %ERRORLEVEL% equ 0 (
        set "PY_CMD=py -3"
    ) else (
        echo [ERROR] Python is required. Download from https://www.python.org/downloads/
        pause
        exit /b 1
    )
)

where git >nul 2>nul
if %ERRORLEVEL% neq 0 (
    echo [ERROR] Git is required. Download from https://git-scm.com/download/win
    pause
    exit /b 1
)

cd /d "%~dp0"

if not exist "install.py" (
    if exist "overbranch-selfhost\install.py" (
        cd overbranch-selfhost
    ) else (
        echo [INFO] Cloning OverBranch repository...
        git clone --depth 1 https://github.com/abin-karukappallil/overbranch-selfhost.git overbranch-selfhost
        cd overbranch-selfhost
    )
)

%PY_CMD% install.py %*
