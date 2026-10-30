# ==============================================================================
# OverBranch Self-Host - installer and `overbranch` CLI for Windows (PowerShell)
# ==============================================================================
#   irm https://raw.githubusercontent.com/abin-karukappallil/overbranch-selfhost/main/install.ps1 | iex
#
# Installs Docker Desktop if missing, pulls the prebuilt image and starts it.
# No clone is needed: only docker-compose.yml is fetched into ~\.overbranch.
# Afterwards:  overbranch [up|stop|logs|status|restart|update|build|backup|restore FILE]
# ==============================================================================
param(
    [Parameter(Position = 0)][string]$Action = "up",
    [Parameter(Position = 1)][string]$Arg = ""
)

$ErrorActionPreference = "Stop"
$Raw = if ($env:OVERBRANCH_RAW_URL) { $env:OVERBRANCH_RAW_URL } else { "https://raw.githubusercontent.com/abin-karukappallil/overbranch-selfhost/main" }
$RepoUrl = "https://github.com/abin-karukappallil/overbranch-selfhost.git"
$Port = if ($env:PORT) { $env:PORT } else { "3000" }
$Url = "http://localhost:$Port"

function Info($m) { Write-Host "[INFO] $m" -ForegroundColor Cyan }
function Ok($m)   { Write-Host "[OK] $m" -ForegroundColor Green }
function Warn($m) { Write-Host "[WARN] $m" -ForegroundColor Yellow }
function Die($m)  { Write-Host "[ERROR] $m" -ForegroundColor Red; exit 1 }

# --- where we live: a checkout if run from one, else ~\.overbranch ------------
$ScriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { "" }
if ($ScriptDir -and (Test-Path (Join-Path $ScriptDir "docker-compose.yml"))) { $ObHome = $ScriptDir }
elseif ($env:OVERBRANCH_HOME) { $ObHome = $env:OVERBRANCH_HOME }
else { $ObHome = Join-Path $HOME ".overbranch" }
New-Item -ItemType Directory -Path $ObHome -Force | Out-Null
$InCheckout = Test-Path (Join-Path $ObHome "Dockerfile")

# --- docker -------------------------------------------------------------------
$DockerBin = "C:\Program Files\Docker\Docker\resources\bin"
function Test-Docker { $null -ne (Get-Command docker -ErrorAction SilentlyContinue) }
function Test-Daemon {
    $old = $ErrorActionPreference; $ErrorActionPreference = "Continue"
    try { & docker info *> $null; return ($LASTEXITCODE -eq 0) } catch { return $false } finally { $ErrorActionPreference = $old }
}

function Install-Docker {
    Info "Docker Desktop not found; installing..."
    $winget = Get-Command winget -ErrorAction SilentlyContinue
    if ($winget) {
        & winget install --id Docker.DockerDesktop -e --source winget --accept-package-agreements --accept-source-agreements --silent
    } else {
        $arch = if ($env:PROCESSOR_ARCHITECTURE -eq "ARM64") { "arm64" } else { "amd64" }
        $exe = Join-Path $env:TEMP "DockerDesktopInstaller.exe"
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        Invoke-WebRequest -Uri "https://desktop.docker.com/win/main/$arch/Docker%20Desktop%20Installer.exe" -OutFile $exe
        Start-Process -FilePath $exe -ArgumentList "install --quiet --accept-license" -Wait
        Remove-Item $exe -Force -ErrorAction SilentlyContinue
    }
    if (Test-Path "$DockerBin\docker.exe") { $env:PATH = "$DockerBin;$env:PATH" }
    # A first install needs the WSL2 backend, usually a reboot, and a first-run
    # licence prompt. Say so plainly instead of failing inside Compose.
    Warn "Docker Desktop was just installed. Restart Windows if prompted, start 'Docker Desktop' once and accept its licence,"
    Warn "then run:  overbranch   (or re-run this installer)."
    exit 0
}

function Ensure-Docker {
    if (-not (Test-Docker)) {
        if (Test-Path "$DockerBin\docker.exe") { $env:PATH = "$DockerBin;$env:PATH" } else { Install-Docker }
    }
    if (-not (Test-Daemon)) {
        Info "Starting Docker Desktop..."
        $app = "C:\Program Files\Docker\Docker\Docker Desktop.exe"
        if (Test-Path $app) { Start-Process $app }
        for ($i = 1; $i -le 60; $i++) {
            Start-Sleep -Seconds 3
            if (Test-Daemon) { break }
            if ($i % 5 -eq 0) { Info "Still waiting for the Docker engine... ($i/60)" }
        }
    }
    if (-not (Test-Daemon)) { Die "Cannot reach the Docker engine. Open Docker Desktop, wait until it says 'Engine running' (accept its licence / enable WSL2 if asked), then run 'overbranch'." }
    & docker compose version *> $null
    if ($LASTEXITCODE -ne 0) { Die "Docker Compose v2 is missing. Update Docker Desktop." }
}

# --- compose ------------------------------------------------------------------
$script:Build = $false
function Source-Dir {
    if ($InCheckout) { return $ObHome }
    $d = Join-Path $ObHome "src"
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) { Die "git is required for 'overbranch build'. Install it with: winget install Git.Git" }
    if (Test-Path (Join-Path $d ".git")) { & git -C $d pull --ff-only -q } else { & git clone --depth 1 $RepoUrl $d }
    return $d
}

function Compose {
    $dir = $ObHome; $files = @("-f", "docker-compose.yml")
    if ($script:Build) { $dir = Source-Dir; $files += @("-f", "docker-compose.build.yml") }
    Push-Location $dir
    try { & docker compose @files @args | Out-Host; $code = $LASTEXITCODE } finally { Pop-Location }
    return $code
}

function Sync-Files {
    if ($InCheckout) { return }
    Invoke-WebRequest -UseBasicParsing "$Raw/docker-compose.yml" -OutFile (Join-Path $ObHome "docker-compose.yml")
    Invoke-WebRequest -UseBasicParsing "$Raw/install.ps1" -OutFile (Join-Path $ObHome "install.ps1")
}

function Pull-Image {
    Info "Pulling the OverBranch image (first time: a few GB; later updates are small)..."
    $old = $ErrorActionPreference; $ErrorActionPreference = "Continue"
    Push-Location $ObHome
    try {
        $t = (& docker compose -f docker-compose.yml pull 2>&1 | ForEach-Object { Write-Host $_; "$_" }) -join "`n"
        $code = $LASTEXITCODE
    } finally { Pop-Location; $ErrorActionPreference = $old }
    if ($code -ne 0) {
        if ($t -match "(?i)unauthorized|denied|forbidden|401|403") { Die "The image is not publicly readable yet (registry said unauthorized). The maintainer must make the GHCR package public. Meanwhile: overbranch build" }
        if ($t -match "(?i)no such host|dial tcp|timeout|unreachable|connection refused|TLS handshake") { Die "Could not reach ghcr.io - you appear to be offline. If the image is already pulled, run 'overbranch up'." }
        Die "Image pull failed (see above)."
    }
}

function Image-Ref { $script:Build = $false; (& docker compose -f (Join-Path $ObHome "docker-compose.yml") config --images 2>$null | Select-Object -First 1) }

function Migrate-LegacyDb {
    $old = Join-Path $ObHome "overbranch.db"
    if (-not (Test-Path $old -PathType Leaf) -or (Get-Item $old).Length -eq 0) { return }
    $img = Image-Ref
    & docker volume create overbranch-data *> $null
    & docker run --rm -v overbranch-data:/d --entrypoint sh $img -c "test -e /d/overbranch.db" *> $null
    if ($LASTEXITCODE -eq 0) { return }
    Info "Migrating your existing database into the new data volume..."
    & docker run --rm -v overbranch-data:/d -v "${ObHome}:/src:ro" --entrypoint sh $img -c "cp -p /src/overbranch.db* /d/"
    if ($LASTEXITCODE -eq 0) { Move-Item $old "$old.migrated" -Force; Ok "Migrated (old file kept as overbranch.db.migrated)." }
}

function Cmd-Up {
    Pull-Image
    Migrate-LegacyDb
    if ((Compose up -d) -ne 0) { Die "docker compose up failed." }
    Info "Waiting for OverBranch to become healthy (first start warms the TeX font cache)..."
    for ($i = 1; $i -le 90; $i++) {
        try { Invoke-WebRequest -UseBasicParsing "http://localhost:8000/api/health" -TimeoutSec 3 | Out-Null; break } catch { Start-Sleep -Seconds 2 }
    }
    Ok "OverBranch is running at $Url"
    Start-Process $Url
}

function Cmd-Backup([string]$out) {
    if (-not $out) { $out = "overbranch-backup-$(Get-Date -Format yyyyMMdd-HHmmss).tgz" }
    $full = [IO.Path]::GetFullPath((Join-Path (Get-Location) $out))
    $dir = Split-Path $full; $name = Split-Path $full -Leaf
    & docker run --rm -v overbranch-data:/data:ro -v overbranch-uploads:/uploads:ro -v "${dir}:/out" --entrypoint tar (Image-Ref) czf "/out/$name" -C / data uploads
    if ($LASTEXITCODE -eq 0) { Ok "Backup written to $full" } else { Die "Backup failed." }
}

function Cmd-Restore([string]$file) {
    if (-not $file -or -not (Test-Path $file)) { Die "Usage: overbranch restore <backup.tgz>" }
    $full = (Resolve-Path $file).Path; $dir = Split-Path $full; $name = Split-Path $full -Leaf
    Warn "This replaces the current database and projects."
    $null = Compose stop
    & docker run --rm -v overbranch-data:/data -v overbranch-uploads:/uploads -v "${dir}:/in:ro" --entrypoint sh (Image-Ref) -c "rm -rf /data/* /uploads/* && tar xzf /in/$name -C /"
    $null = Compose up -d; Ok "Restored from $full"
}

function Install-Cli {
    $bin = Join-Path $HOME ".local\bin"
    New-Item -ItemType Directory -Path $bin -Force | Out-Null
    $cmd = "@echo off`r`npowershell -NoProfile -ExecutionPolicy Bypass -File `"$ObHome\install.ps1`" %*"
    Set-Content -Path (Join-Path $bin "overbranch.cmd") -Value $cmd -Force
    $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
    if ($userPath -notlike "*$bin*") {
        [Environment]::SetEnvironmentVariable("Path", "$bin;$userPath", "User")
        $env:PATH = "$bin;$env:PATH"
        Warn "Added $bin to your PATH; open a new terminal to use 'overbranch'."
    }
    Ok "Installed the 'overbranch' command"
}

# --- main ---------------------------------------------------------------------
Ensure-Docker
Sync-Files
switch -Regex ($Action) {
    '^(up|start)$'     { Cmd-Up; Install-Cli }
    '^(update|pull)$'  { Pull-Image; $null = Compose up -d }
    '^build$'          { $script:Build = $true; $null = Compose up -d --build; Ok "Built and started: $Url" }
    '^(stop|down)$'    { $null = Compose down }
    '^restart$'        { $null = Compose restart }
    '^logs$'           { $null = Compose logs -f }
    '^(ps|status)$'    { $null = Compose ps }
    '^backup$'         { Cmd-Backup $Arg }
    '^restore$'        { Cmd-Restore $Arg }
    default            { Die "Unknown command '$Action'. Use: up | stop | logs | status | restart | update | build | backup | restore" }
}
