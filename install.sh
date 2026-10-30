#!/usr/bin/env bash
# ==============================================================================
# OverBranch Self-Host - installer and `overbranch` CLI (Linux, macOS, WSL, Git Bash)
# ==============================================================================
#   curl -fsSL https://raw.githubusercontent.com/overbranch/overbranch-selfhost/main/install.sh | bash
#
# Installs Docker if missing, pulls the prebuilt image and starts it. No
# clone is needed: only docker-compose.yml is fetched into ~/.overbranch.
# Afterwards the same script is the `overbranch` command:
#   overbranch [up|stop|logs|status|restart|update|build|backup|restore FILE]
# Windows (PowerShell) users: install.ps1.
# ==============================================================================
set -eo pipefail

RAW="${OVERBRANCH_RAW_URL:-https://raw.githubusercontent.com/overbranch/overbranch-selfhost/main}"
REPO_URL="${OVERBRANCH_REPO_URL:-https://github.com/overbranch/overbranch-selfhost.git}"
URL="http://localhost:${PORT:-3000}"

if [ -t 1 ]; then C='\033[0;36m'; G='\033[0;32m'; Y='\033[1;33m'; R='\033[0;31m'; Z='\033[0m'; else C=; G=; Y=; R=; Z=; fi
info() { printf "${C}[INFO]${Z} %s\n" "$*"; }
ok()   { printf "${G}[OK]${Z} %s\n" "$*"; }
warn() { printf "${Y}[WARN]${Z} %s\n" "$*" >&2; }
die()  { printf "${R}[ERROR]${Z} %s\n" "$*" >&2; exit 1; }

# --- where we live -----------------------------------------------------------
# Run from a checkout: use it. Otherwise (curl | bash, or the installed CLI): ~/.overbranch
SELF="${BASH_SOURCE[0]:-}"
if [ -n "$SELF" ] && [ -f "$SELF" ] && [ -f "$(dirname "$SELF")/docker-compose.yml" ]; then
    OB_HOME="$(cd "$(dirname "$SELF")" && pwd)"
else
    OB_HOME="${OVERBRANCH_HOME:-$HOME/.overbranch}"
fi
mkdir -p "$OB_HOME"

case "$(uname -s)" in
    Linux*)  OS=linux ;;
    Darwin*) OS=macos ;;
    MINGW*|MSYS*|CYGWIN*) OS=windows ;;
    *) OS=other ;;
esac

SUDO=""; [ "$(id -u)" -ne 0 ] && command -v sudo >/dev/null 2>&1 && SUDO="sudo"
fetch() { curl -fsSL --retry 3 "$1" -o "$2"; }

# --- docker -------------------------------------------------------------------
install_docker() {
    info "Docker not found; installing..."
    case "$OS" in
        macos)
            if command -v brew >/dev/null 2>&1; then
                brew install --cask docker
            else
                local a; [ "$(uname -m)" = "x86_64" ] && a=amd64 || a=arm64
                fetch "https://desktop.docker.com/mac/main/${a}/Docker.dmg" /tmp/Docker.dmg
                hdiutil attach /tmp/Docker.dmg -nobrowse -quiet
                cp -R /Volumes/Docker/Docker.app /Applications/
                hdiutil detach /Volumes/Docker -quiet || true
                rm -f /tmp/Docker.dmg
            fi
            open -a Docker
            ;;
        linux)
            [ "$(id -u)" -eq 0 ] || [ -n "$SUDO" ] || die "Need root or sudo to install Docker. Install it from https://docs.docker.com/engine/install/ and re-run."
            curl -fsSL https://get.docker.com | $SUDO sh
            $SUDO systemctl enable --now docker 2>/dev/null || $SUDO service docker start 2>/dev/null || true
            [ -n "$SUDO" ] && $SUDO usermod -aG docker "$USER" 2>/dev/null || true
            ;;
        windows) die "Docker Desktop is not installed. Run install.ps1 from PowerShell (it installs Docker Desktop), then re-run." ;;
        *) die "Unsupported platform. Install Docker: https://docs.docker.com/engine/install/" ;;
    esac
}

DOCKER="docker"
ensure_docker() {
    command -v docker >/dev/null 2>&1 || install_docker
    command -v docker >/dev/null 2>&1 || die "Docker is still not on PATH. Open a new terminal (or start Docker Desktop) and re-run."

    if ! docker info >/dev/null 2>&1; then
        if docker info 2>&1 | grep -qi "permission denied" && [ -n "$SUDO" ]; then
            warn "No permission for the Docker socket; using sudo for this run (log out/in to use the docker group)."
            DOCKER="sudo docker"
        else
            info "Starting the Docker daemon..."
            case "$OS" in
                macos|windows) open -a Docker 2>/dev/null || true ;;
                *) $SUDO systemctl start docker 2>/dev/null || $SUDO service docker start 2>/dev/null || true ;;
            esac
            local i
            for i in $(seq 1 45); do
                docker info >/dev/null 2>&1 && break
                if docker info 2>&1 | grep -qi "permission denied" && [ -n "$SUDO" ]; then DOCKER="sudo docker"; break; fi
                sleep 2
            done
        fi
    fi
    $DOCKER info >/dev/null 2>&1 || die "Cannot reach the Docker daemon. Start Docker (Docker Desktop on macOS/Windows) and re-run 'overbranch'."
    $DOCKER compose version >/dev/null 2>&1 || die "Docker Compose v2 plugin is missing. See https://docs.docker.com/compose/install/"
}

# --- compose ------------------------------------------------------------------
BUILD=0
compose() {
    local dir="$OB_HOME" f=(-f docker-compose.yml)
    if [ "$BUILD" = 1 ]; then
        dir="$(source_dir)"; f+=(-f docker-compose.build.yml)
    fi
    (cd "$dir" && $DOCKER compose "${f[@]}" "$@")
}

# `build` needs the Dockerfile, so it needs a checkout.
source_dir() {
    if [ -f "$OB_HOME/Dockerfile" ]; then echo "$OB_HOME"; return; fi
    local d="$OB_HOME/src"
    if [ -d "$d/.git" ]; then git -C "$d" pull --ff-only -q || true
    else command -v git >/dev/null 2>&1 || die "git is required for 'overbranch build'."
         git clone --depth 1 "$REPO_URL" "$d" >&2; fi
    echo "$d"
}

sync_files() {
    # In a checkout the files are already there.
    [ -f "$OB_HOME/Dockerfile" ] && return 0
    fetch "$RAW/docker-compose.yml" "$OB_HOME/docker-compose.yml"
    fetch "$RAW/install.sh" "$OB_HOME/install.sh" && chmod +x "$OB_HOME/install.sh"
}

pull_image() {
    local log; log="$(mktemp)"
    info "Pulling the OverBranch image (first time: a few GB; later updates are small)..."
    if ! compose pull 2>&1 | tee "$log"; then
        if grep -qiE "unauthorized|denied|forbidden|401|403" "$log"; then
            die "The image is not publicly readable yet (registry said unauthorized). The maintainer must make the GHCR package public. Meanwhile: overbranch build"
        elif grep -qiE "no such host|dial tcp|timeout|network is unreachable|connection refused|TLS handshake" "$log"; then
            die "Could not reach ghcr.io - you appear to be offline. If the image is already pulled, run 'overbranch up'; otherwise connect and retry."
        fi
        die "Image pull failed (see above)."
    fi
    rm -f "$log"
}

# Older installs kept ./overbranch.db next to the compose file; carry it over once.
migrate_legacy_db() {
    local old="$OB_HOME/overbranch.db"
    [ -s "$old" ] || return 0
    $DOCKER volume inspect overbranch-data >/dev/null 2>&1 && \
        $DOCKER run --rm -v overbranch-data:/d --entrypoint sh "$IMAGE" -c 'test -e /d/overbranch.db' 2>/dev/null && return 0
    info "Migrating your existing database into the new data volume..."
    $DOCKER volume create overbranch-data >/dev/null
    $DOCKER run --rm -v overbranch-data:/d -v "$OB_HOME:/src:ro" --entrypoint sh "$IMAGE" -c 'cp -p /src/overbranch.db* /d/' \
        && mv "$old" "$old.migrated" && ok "Migrated (old file kept as overbranch.db.migrated)."
}

image_ref() { compose config --images 2>/dev/null | head -1; }

cmd_up() {
    pull_image
    IMAGE="$(image_ref)"; migrate_legacy_db || true
    compose up -d
    info "Waiting for OverBranch to become healthy (first start warms the TeX font cache)..."
    local i
    for i in $(seq 1 90); do
        curl -sf "http://localhost:${BACKEND_PORT:-8000}/api/health" >/dev/null 2>&1 && break
        sleep 2
    done
    ok "OverBranch is running at ${URL}"
    case "$OS" in macos) open "$URL" >/dev/null 2>&1 || true ;; linux) xdg-open "$URL" >/dev/null 2>&1 || true ;; esac
}

cmd_build() { BUILD=1; compose up -d --build; ok "Built and started: ${URL}"; }

cmd_backup() {
    local out="${1:-overbranch-backup-$(date +%Y%m%d-%H%M%S).tgz}"
    IMAGE="$(image_ref)"; out="$(cd "$(dirname "$out")" && pwd)/$(basename "$out")"
    $DOCKER run --rm -v overbranch-data:/data:ro -v overbranch-uploads:/uploads:ro -v "$(dirname "$out"):/out" \
        --entrypoint tar "$IMAGE" czf "/out/$(basename "$out")" -C / data uploads
    ok "Backup written to $out"
}

cmd_restore() {
    [ -f "${1:-}" ] || die "Usage: overbranch restore <backup.tgz>"
    local f dir; f="$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"; dir="$(dirname "$f")"
    IMAGE="$(image_ref)"
    warn "This replaces the current database and projects."
    compose stop 2>/dev/null || true
    $DOCKER run --rm -v overbranch-data:/data -v overbranch-uploads:/uploads -v "$dir:/in:ro" \
        --entrypoint sh "$IMAGE" -c "rm -rf /data/* /uploads/* && tar xzf /in/$(basename "$f") -C /"
    compose up -d && ok "Restored from $f"
}

install_cli() {
    local bin="$HOME/.local/bin"; mkdir -p "$bin"
    printf '#!/usr/bin/env bash\nexec bash "%s/install.sh" "$@"\n' "$OB_HOME" > "$bin/overbranch"
    chmod +x "$bin/overbranch"
    case ":$PATH:" in *":$bin:"*) ;; *)
        local rc; for rc in "$HOME/.zshrc" "$HOME/.bashrc" "$HOME/.profile"; do
            [ -f "$rc" ] && ! grep -q '.local/bin' "$rc" && printf '\nexport PATH="$HOME/.local/bin:$PATH"\n' >> "$rc" || true
        done
        warn "Added ~/.local/bin to your shell profile; open a new terminal to use 'overbranch'." ;;
    esac
    ok "Installed the 'overbranch' command"
}

# --- main ---------------------------------------------------------------------
ACTION="${1:-up}"; [ $# -gt 0 ] && shift || true
ensure_docker
sync_files
case "$ACTION" in
    up|start)        cmd_up ;;
    update|pull)     pull_image; compose up -d ;;
    build)           cmd_build ;;
    stop|down)       compose down ;;
    restart)         compose restart ;;
    logs)            compose logs -f "$@" ;;
    ps|status)       compose ps ;;
    backup)          cmd_backup "$@" ;;
    restore)         cmd_restore "$@" ;;
    *) die "Unknown command '$ACTION'. Use: up | stop | logs | status | restart | update | build | backup | restore" ;;
esac
[ "$ACTION" = up ] || [ "$ACTION" = start ] && install_cli || true
