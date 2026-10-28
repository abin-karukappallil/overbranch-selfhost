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

$dockerCmd = Get-Command docker -ErrorAction SilentlyContinue
if (-not $dockerCmd) {
    Write-Host "[ERROR] Docker is not installed or not in PATH." -ForegroundColor Red
    Write-Host "Please install Docker Desktop: https://www.docker.com/products/docker-desktop/" -ForegroundColor Yellow
    exit 1
}

try {
    & docker info 2>&1 | Out-Null
} catch {
    Write-Host "[ERROR] Docker daemon is not running. Please start Docker Desktop first." -ForegroundColor Red
    exit 1
}

Write-Host "[INFO] Starting OverBranch via Docker Compose..." -ForegroundColor Cyan

$composeProc = Start-Process -FilePath "docker" -ArgumentList "compose up -d" -NoNewWindow -PassThru -Wait
if ($composeProc.ExitCode -ne 0) {
    Write-Host "[WARN] 'docker compose' failed, trying 'docker-compose'..." -ForegroundColor Yellow
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
