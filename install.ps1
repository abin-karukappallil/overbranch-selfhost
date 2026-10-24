# ==============================================================================
# OverBranch Self-Host — One-Line Windows PowerShell Installer
# ==============================================================================
# Usage (One-Line PowerShell):
#   irm https://raw.githubusercontent.com/abin-karukappallil/overbranch-selfhost/main/install.ps1 | iex
# ==============================================================================

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

100% Local Self-Hosted LaTeX IDE • Embedded Gemini Web2API • SQLite
Windows PowerShell One-Line Installer
"@ -ForegroundColor Green

Write-Cyan "Checking Windows system prerequisites..."

# 1. Check Git
$gitCmd = Get-Command git -ErrorAction SilentlyContinue
if ($gitCmd) {
    Write-Green "Found Git: $($gitCmd.Source)"
} else {
    Write-Red "Git is required to clone and install OverBranch."
    Write-Host "   -> Install with winget: winget install --id Git.Git -e --source winget" -ForegroundColor Yellow
    Write-Host "   -> Or download from: https://git-scm.com/download/win" -ForegroundColor Yellow
    exit 1
}

# 2. Check Python
$pyCmd = Get-Command python -ErrorAction SilentlyContinue
if (-not $pyCmd) {
    $pyCmd = Get-Command py -ErrorAction SilentlyContinue
}
if ($pyCmd) {
    $pyVer = & $pyCmd.Source --version 2>&1
    Write-Green "Found Python: $pyVer ($($pyCmd.Source))"
} else {
    Write-Red "Python 3.9+ is required to run the OverBranch backend."
    Write-Host "   -> Install with winget: winget install -e --id Python.Python.3.11" -ForegroundColor Yellow
    Write-Host "   -> Or download from: https://www.python.org/downloads/windows/" -ForegroundColor Yellow
    exit 1
}

# 3. Check Bun or Node.js
$bunCmd = Get-Command bun -ErrorAction SilentlyContinue
$nodeCmd = Get-Command node -ErrorAction SilentlyContinue
$npmCmd = Get-Command npm -ErrorAction SilentlyContinue

if ($bunCmd) {
    Write-Green "Found Bun: $(& $bunCmd.Source --version)"
} elseif ($nodeCmd -and $npmCmd) {
    Write-Green "Found Node.js: $(& $nodeCmd.Source --version) with npm"
} else {
    Write-Yellow "Neither Bun nor Node.js was found."
    Write-Cyan "Attempting to install Bun automatically via PowerShell..."
    try {
        irm bun.sh/install.ps1 | iex
        $env:BUN_INSTALL = "$HOME\.bun"
        $env:PATH = "$env:BUN_INSTALL\bin;$env:PATH"
        $bunCmd = Get-Command bun -ErrorAction SilentlyContinue
        if ($bunCmd) {
            Write-Green "Successfully installed Bun: $(& $bunCmd.Source --version)"
        }
    } catch {
        Write-Red "Failed to auto-install Bun. Please install Node.js: winget install OpenJS.NodeJS.LTS"
        exit 1
    }
}

# 4. Determine or clone repository
$RepoUrl = if ($env:OVERBRANCH_REPO_URL) { $env:OVERBRANCH_REPO_URL } else { "https://github.com/abin-karukappallil/overbranch-selfhost.git" }
$TargetFolder = if ($env:OVERBRANCH_INSTALL_DIR) { $env:OVERBRANCH_INSTALL_DIR } else { "overbranch-selfhost" }

if ((Test-Path ".\install.py") -and (Test-Path ".\backend") -and (Test-Path ".\package.json")) {
    Write-Cyan "Currently inside OverBranch Self-Host folder. Proceeding..."
    $WorkDir = (Get-Location).Path
} elseif (Test-Path ".\overbranch-selfhost\install.py") {
    Write-Cyan "Entering overbranch-selfhost folder..."
    Set-Location ".\overbranch-selfhost"
    $WorkDir = (Get-Location).Path
} else {
    Write-Cyan "Cloning OverBranch repository from $RepoUrl..."
    if (-not (Test-Path $TargetFolder)) {
        & git clone --depth 1 $RepoUrl $TargetFolder
    }
    if (Test-Path "$TargetFolder\overbranch-selfhost") {
        Set-Location "$TargetFolder\overbranch-selfhost"
    } else {
        Set-Location "$TargetFolder"
    }
    $WorkDir = (Get-Location).Path
}

Write-Green "Working directory: $WorkDir"

# 5. Run Python installer
Write-Cyan "Running core OverBranch installer (downloading Gemini Web2API, setting up venv, SQLite)..."
& $pyCmd.Source install.py

Write-Host @"

============================================================
   OverBranch Self-Host Installation Succeeded!
============================================================

All services are self-contained with zero .env configuration:
  • Web Frontend:    http://localhost:3000
  • TeX Engine API:  http://localhost:8000
  • Gemini Proxy:    http://localhost:8081
  • Database:        overbranch.db (SQLite with Vector Search)

To start OverBranch anytime, run:
  cd $WorkDir
  python run.py  (or: .\run.bat)

"@ -ForegroundColor Green

$startChoice = Read-Host "Would you like to start OverBranch right now? [Y/n]"
if ([string]::IsNullOrWhiteSpace($startChoice) -or $startChoice -match "^[Yy]") {
    Write-Cyan "Starting OverBranch Self-Host stack..."
    & $pyCmd.Source run.py
}
