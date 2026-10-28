@echo off
setlocal enabledelayedexpansion

cd /d "%~dp0"

REM 1. Handle management subcommands
if "%~1"=="down" (
    echo [INFO] Stopping OverBranch containers...
    docker compose down
    exit /b %ERRORLEVEL%
)
if "%~1"=="stop" (
    echo [INFO] Stopping OverBranch containers...
    docker compose down
    exit /b %ERRORLEVEL%
)
if "%~1"=="logs" (
    docker compose logs -f
    exit /b %ERRORLEVEL%
)
if "%~1"=="ps" (
    docker compose ps
    exit /b %ERRORLEVEL%
)
if "%~1"=="status" (
    docker compose ps
    exit /b %ERRORLEVEL%
)
if "%~1"=="restart" (
    echo [INFO] Restarting OverBranch containers...
    docker compose restart
    exit /b %ERRORLEVEL%
)

echo ============================================================
echo           OverBranch Self-Host Docker Launcher
echo    100% Local • Zero API Keys • SQLite • Gemini Web2API
echo ============================================================
echo.

REM 2. Check if Docker is in PATH or standard Program Files location
set "DOCKER_BIN_DIR=C:\Program Files\Docker\Docker\resources\bin"
where docker >nul 2>nul
if %ERRORLEVEL% neq 0 (
    if exist "%DOCKER_BIN_DIR%\docker.exe" (
        set "PATH=%DOCKER_BIN_DIR%;!PATH!"
        echo [INFO] Detected Docker in standard installation path.
    ) else (
        echo [INFO] Docker is not installed on this Windows system.
        echo [INFO] Automatically installing Docker Desktop for Windows...
        echo.
        
        where winget >nul 2>nul
        if !ERRORLEVEL! equ 0 (
            echo [INFO] Installing Docker Desktop via Windows Package Manager (winget)...
            winget install --id Docker.DockerDesktop -e --source winget --accept-package-agreements --accept-source-agreements --silent
        ) else (
            echo [INFO] Downloading official Docker Desktop installer...
            set "INSTALLER_PATH=%TEMP%\DockerDesktopInstaller.exe"
            powershell -NoProfile -Command "[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; (New-Object System.Net.WebClient).DownloadFile('https://desktop.docker.com/win/main/amd64/Docker%20Desktop%20Installer.exe', $env:INSTALLER_PATH)"
            echo [INFO] Running Docker Desktop installer silently...
            "%TEMP%\DockerDesktopInstaller.exe" install --quiet --accept-license
            del "%TEMP%\DockerDesktopInstaller.exe" 2>nul
        )

        if exist "%DOCKER_BIN_DIR%\docker.exe" (
            set "PATH=%DOCKER_BIN_DIR%;!PATH!"
            powershell -NoProfile -Command "$p = [Environment]::GetEnvironmentVariable('Path', 'User'); if ($p -notlike '*Docker*') { [Environment]::SetEnvironmentVariable('Path', '%DOCKER_BIN_DIR%;' + $p, 'User') }" 2>nul
            echo [SUCCESS] Docker Desktop installed successfully.
        ) else (
            echo [ERROR] Docker installation completed but docker.exe was not found immediately.
            echo Please visit https://www.docker.com/products/docker-desktop/ to complete installation.
            pause
            exit /b 1
        )
    )
)

REM 3. Ensure Docker Desktop daemon is running
docker info >nul 2>nul
if %ERRORLEVEL% neq 0 (
    echo [INFO] Docker daemon is not active. Starting Docker Desktop...
    set "DOCKER_APP=C:\Program Files\Docker\Docker\Docker Desktop.exe"
    if exist "!DOCKER_APP!" (
        start "" "!DOCKER_APP!"
    ) else (
        start "" "Docker Desktop" 2>nul
    )

    echo [INFO] Waiting for Docker daemon to become responsive (this may take up to 45 seconds)...
    set /a RETRIES=0
    :WAIT_DOCKER
    timeout /t 3 /nobreak >nul
    docker info >nul 2>nul
    if !ERRORLEVEL! equ 0 (
        echo [SUCCESS] Docker daemon is running!
        goto DOCKER_READY
    )
    set /a RETRIES+=1
    if !RETRIES! lss 20 (
        echo [INFO] Still waiting for Docker engine... (!RETRIES!/20)
        goto WAIT_DOCKER
    )
    echo [WARN] Docker Desktop started, but daemon took too long to answer. Attempting compose anyway...
)

:DOCKER_READY

REM 4. Ensure required database file and upload directories exist (prevents volume directory bug)
if exist "%~dp0overbranch.db\" (
    echo [WARN] 'overbranch.db' is a directory. Correcting to SQLite database file...
    rmdir /s /q "%~dp0overbranch.db"
)
if not exist "%~dp0overbranch.db" type nul > "%~dp0overbranch.db"
if not exist "%~dp0uploads" mkdir "%~dp0uploads"

REM 5. Start OverBranch via Docker Compose
echo.
if "%~1"=="build" (
    echo [INFO] Building and starting OverBranch via Docker Compose...
    docker compose up --build -d
) else (
    echo [INFO] Starting OverBranch via Docker Compose...
    docker compose up -d
)

if %ERRORLEVEL% neq 0 (
    echo [WARN] 'docker compose' failed, trying legacy 'docker-compose'...
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
    echo   Management commands:
    echo     docker-up.bat stop     (or run.bat stop)    - Stop containers
    echo     docker-up.bat logs     (or run.bat logs)    - View container logs
    echo     docker-up.bat restart  (or run.bat restart) - Restart services
    echo ============================================================
    echo.
    echo Opening OverBranch in default browser...
    start http://localhost:3000
) else (
    echo [ERROR] Failed to start Docker container.
    pause
    exit /b 1
)
