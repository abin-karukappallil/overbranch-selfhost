@echo off
setlocal enabledelayedexpansion

echo ============================================================
echo           OverBranch Self-Host Docker Launcher
echo    100% Local • Zero API Keys • SQLite • Gemini Web2API
echo ============================================================
echo.

cd /d "%~dp0"

where docker >nul 2>nul
if %ERRORLEVEL% neq 0 (
    echo [ERROR] Docker is not installed or not in PATH.
    echo Please install Docker Desktop: https://www.docker.com/products/docker-desktop/
    echo.
    pause
    exit /b 1
)

docker info >nul 2>nul
if %ERRORLEVEL% neq 0 (
    echo [ERROR] Docker daemon is not running.
    echo Please start Docker Desktop and run this script again.
    echo.
    pause
    exit /b 1
)

echo [INFO] Starting OverBranch via Docker Compose...
echo.

docker compose up -d
if %ERRORLEVEL% neq 0 (
    echo [WARN] docker compose failed, trying docker-compose...
    docker-compose up -d
)

if %ERRORLEVEL% equ 0 (
    echo.
    echo ============================================================
    echo       OverBranch Self-Host is running successfully!
    echo ============================================================
    echo.
    echo       Access overbranch through localhost:3000
    echo.
    echo   • Web Editor Workspace: http://localhost:3000
    echo   • TeX Engine API:       http://localhost:8000
    echo   • Gemini Web2API Proxy: http://localhost:8081
    echo ============================================================
    echo.
    echo Opening OverBranch in default browser...
    start http://localhost:3000
) else (
    echo [ERROR] Failed to start Docker container.
    pause
)
