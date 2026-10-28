# ==============================================================================
# OverBranch Self-Host — One-Line Windows PowerShell Installer (Docker Compose)
# ==============================================================================
# Usage (One-Line PowerShell):
#   irm https://raw.githubusercontent.com/abin-karukappallil/overbranch-selfhost/main/install.ps1 | iex
# ==============================================================================

param(
    [switch]$Build
)

$ErrorActionPreference = "Stop"

function Write-Cyan { param([string]$msg) Write-Host "[INFO] $msg" -ForegroundColor Cyan }
function Write-Green { param([string]$msg) Write-Host "[OK] $msg" -ForegroundColor Green }
function Write-Yellow { param([string]$msg) Write-Host "[WARN] $msg" -ForegroundColor Yellow }
function Write-Red { param([string]$msg) Write-Host "[ERROR] $msg" -ForegroundColor Red }

Write-Host @"
  ___                  ____                       _     
 / _ \__   _____ _ __ | __ ) _ __ __ _ _ __   ___| |__  
| | | \ \ / / _ \ '__||  _ \| '__/ _` | '_ \ / __| '_ \ 
| |_| |\ V /  __/ |   | |_) | | | (_| | | | | (__| | | |
 \___/  \_/ \___|_|   |____/|_|  \__,_|_| |_|\___|_| |_|

100% Local Self-Hosted LaTeX IDE • Docker Compose • Zero Configuration
Windows PowerShell Installer
"@ -ForegroundColor Green

# 1. Check Git
$gitCmd = Get-Command git -ErrorAction SilentlyContinue
if (-not $gitCmd) {
    Write-Cyan "Installing Git for Windows via winget..."
    try {
        & winget install --id Git.Git -e --source winget --accept-package-agreements --accept-source-agreements --silent
        $env:PATH = "C:\Program Files\Git\cmd;$env:PATH"
    } catch {
        Write-Red "Git is required to clone and install OverBranch."
        Write-Host "Please download from: https://git-scm.com/download/win" -ForegroundColor Yellow
        exit 1
    }
}

# 2. Locate or clone repository
$workDir = ""
if (Test-Path ".\docker-compose.yml" -PathType Leaf) {
    $workDir = (Get-Location).Path
} elseif (Test-Path "$HOME\overbranch-selfhost\docker-compose.yml" -PathType Leaf) {
    $workDir = "$HOME\overbranch-selfhost"
} elseif (Test-Path ".\overbranch-selfhost\docker-compose.yml" -PathType Leaf) {
    $workDir = (Join-Path (Get-Location).Path "overbranch-selfhost")
}

if (-not $workDir) {
    $repoUrl = "https://github.com/abin-karukappallil/overbranch-selfhost.git"
    $targetDir = "$HOME\overbranch-selfhost"
    if (-not (Test-Path $targetDir)) {
        & git clone --depth 1 $repoUrl $targetDir
    } else {
        Write-Cyan "Found existing OverBranch directory at $targetDir. Updating..."
        Push-Location $targetDir
        & git pull origin main 2>$null
        Pop-Location
    }
    $workDir = $targetDir
}

Set-Location $workDir
Write-Green "Working directory: $workDir"

# 3. Check or install Docker Desktop for Windows
$dockerBinDir = "C:\Program Files\Docker\Docker\resources\bin"
$dockerCmd = Get-Command docker -ErrorAction SilentlyContinue

if (-not $dockerCmd) {
    if (Test-Path "$dockerBinDir\docker.exe") {
        $env:PATH = "$dockerBinDir;$env:PATH"
        Write-Cyan "Detected Docker in standard installation path."
    } else {
        Write-Yellow "Docker is not detected on your Windows system."
        Write-Cyan "Automatically installing Docker Desktop for Windows..."

        $wingetCmd = Get-Command winget -ErrorAction SilentlyContinue
        if ($wingetCmd) {
            Write-Cyan "Installing Docker Desktop via Windows Package Manager (winget)..."
            & winget install --id Docker.DockerDesktop -e --source winget --accept-package-agreements --accept-source-agreements --silent
        } else {
            Write-Cyan "Downloading official Docker Desktop installer..."
            $installer = "$env:TEMP\DockerDesktopInstaller.exe"
            [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
            (New-Object System.Net.WebClient).DownloadFile("https://desktop.docker.com/win/main/amd64/Docker%20Desktop%20Installer.exe", $installer)
            
            Write-Cyan "Running Docker Desktop installer silently..."
            Start-Process -FilePath $installer -ArgumentList "install --quiet --accept-license" -Wait
            Remove-Item $installer -Force -ErrorAction SilentlyContinue
        }

        if (Test-Path "$dockerBinDir\docker.exe") {
            $env:PATH = "$dockerBinDir;$env:PATH"
            $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
            if ($userPath -notlike "*$dockerBinDir*") {
                [Environment]::SetEnvironmentVariable("Path", "$dockerBinDir;$userPath", "User")
            }
            Write-Green "Docker Desktop installed successfully."
        }
    }
}

# 4. Create global 'overbranch' CLI launcher in user PATH
$userBin = "$HOME\.local\bin"
if (-not (Test-Path $userBin)) {
    New-Item -ItemType Directory -Path $userBin -Force | Out-Null
}
$userPath = [Environment]::GetEnvironmentVariable("Path", "User")
if ($userPath -notlike "*$userBin*") {
    [Environment]::SetEnvironmentVariable("Path", "$userBin;$userPath", "User")
    $env:PATH = "$userBin;$env:PATH"
}

$cmdContent = "@echo off`r`ncall `"$workDir\docker-up.bat`" %*"
Set-Content -Path (Join-Path $userBin "overbranch.cmd") -Value $cmdContent -Force
Write-Green "Installed global CLI command: overbranch (in $userBin)"

# 5. Delegate to docker-up.ps1 to start OverBranch
Write-Cyan "Starting OverBranch via Docker Compose..."
& "$workDir\docker-up.ps1"
