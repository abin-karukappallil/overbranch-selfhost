# ==============================================================================
# OverBranch Self-Host — 1-Click Docker Compose Launcher (PowerShell)
# ==============================================================================

$ErrorActionPreference = "Stop"

Write-Host @"
============================================================
          OverBranch Self-Host Docker Launcher
   100% Local • Zero API Keys • SQLite • Gemini Web2API
============================================================
"@ -ForegroundColor Green

# 1. Check or install Docker on Windows
$dockerBinDir = "C:\Program Files\Docker\Docker\resources\bin"
$dockerCmd = Get-Command docker -ErrorAction SilentlyContinue

if (-not $dockerCmd) {
    if (Test-Path "$dockerBinDir\docker.exe") {
        $env:PATH = "$dockerBinDir;$env:PATH"
        Write-Host "[INFO] Detected Docker in standard installation path." -ForegroundColor Cyan
    } else {
        Write-Host "[INFO] Docker is not detected on your Windows system." -ForegroundColor Yellow
        Write-Host "[INFO] Automatically installing Docker Desktop for Windows..." -ForegroundColor Cyan

        $wingetCmd = Get-Command winget -ErrorAction SilentlyContinue
        if ($wingetCmd) {
            Write-Host "[INFO] Installing Docker Desktop via Windows Package Manager (winget)..." -ForegroundColor Cyan
            & winget install --id Docker.DockerDesktop -e --source winget --accept-package-agreements --accept-source-agreements --silent
        } else {
            Write-Host "[INFO] Downloading official Docker Desktop installer..." -ForegroundColor Cyan
            $installer = "$env:TEMP\DockerDesktopInstaller.exe"
            [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
            (New-Object System.Net.WebClient).DownloadFile("https://desktop.docker.com/win/main/amd64/Docker%20Desktop%20Installer.exe", $installer)
            
            Write-Host "[INFO] Running Docker Desktop installer silently..." -ForegroundColor Cyan
            Start-Process -FilePath $installer -ArgumentList "install --quiet --accept-license" -Wait
            Remove-Item $installer -Force -ErrorAction SilentlyContinue
        }

        if (Test-Path "$dockerBinDir\docker.exe") {
            $env:PATH = "$dockerBinDir;$env:PATH"
            $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
            if ($userPath -notlike "*$dockerBinDir*") {
                [Environment]::SetEnvironmentVariable("Path", "$dockerBinDir;$userPath", "User")
            }
            Write-Host "[SUCCESS] Docker Desktop installed successfully." -ForegroundColor Green
        } else {
            Write-Host "[ERROR] Docker installation completed but docker.exe was not found immediately." -ForegroundColor Red
            Write-Host "Please download and install Docker Desktop manually from: https://www.docker.com/products/docker-desktop/" -ForegroundColor Yellow
            exit 1
        }
    }
}

# 2. Check and start Docker Desktop daemon if not already running
$daemonReady = $false
try {
    & docker info 2>&1 | Out-Null
    $daemonReady = ($LASTEXITCODE -eq 0)
} catch {
    $daemonReady = $false
}

if (-not $daemonReady) {
    Write-Host "[INFO] Docker daemon is not active. Starting Docker Desktop..." -ForegroundColor Cyan
    $dockerApp = "C:\Program Files\Docker\Docker\Docker Desktop.exe"
    if (Test-Path $dockerApp) {
        Start-Process -FilePath $dockerApp
    } else {
        Start-Process "Docker Desktop" -ErrorAction SilentlyContinue
    }

    Write-Host "[INFO] Waiting for Docker engine to become responsive (this may take up to 45 seconds)..." -ForegroundColor Cyan
    for ($i = 1; $i -le 20; $i++) {
        Start-Sleep -Seconds 3
        try {
            & docker info 2>&1 | Out-Null
            if ($LASTEXITCODE -eq 0) {
                Write-Host "[SUCCESS] Docker daemon is active and responsive!" -ForegroundColor Green
                $daemonReady = $true
                break
            }
        } catch {}
        Write-Host "[INFO] Still waiting for Docker engine... ($i/20)" -ForegroundColor Gray
    }
}

# 3. Start OverBranch via Docker Compose
Write-Host ""
Write-Host "[INFO] Starting OverBranch via Docker Compose..." -ForegroundColor Cyan

$composeProc = Start-Process -FilePath "docker" -ArgumentList "compose up -d" -NoNewWindow -PassThru -Wait
if ($composeProc.ExitCode -ne 0) {
    Write-Host "[WARN] 'docker compose' failed, trying legacy 'docker-compose'..." -ForegroundColor Yellow
    $composeProc = Start-Process -FilePath "docker-compose" -ArgumentList "up -d" -NoNewWindow -PassThru -Wait
}

if ($composeProc.ExitCode -eq 0) {
    Write-Host @"

============================================================
       OverBranch Self-Host is running successfully!
============================================================

   Access overbranch through localhost:3000

   • Web Editor Workspace: http://localhost:3000
   • TeX Engine API:       http://localhost:8000
   • Gemini Web2API Proxy: http://localhost:8081
============================================================

"@ -ForegroundColor Green

    Write-Host "Opening OverBranch in default browser..." -ForegroundColor Cyan
    Start-Process "http://localhost:3000"
} else {
    Write-Host "[ERROR] Failed to start Docker container." -ForegroundColor Red
    exit 1
}
