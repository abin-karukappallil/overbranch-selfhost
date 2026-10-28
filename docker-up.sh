#!/usr/bin/env bash
# ==============================================================================
# OverBranch Self-Host — 1-Click Docker Compose Launcher with Auto-Installer
# ==============================================================================

set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$DIR"

echo "============================================================"
echo "          OverBranch Self-Host Docker Launcher"
echo "    100% Local • Zero API Keys • SQLite • Gemini Web2API"
echo "============================================================"
echo ""

# 1. Detect and install Docker if not present
if ! command -v docker >/dev/null 2>&1; then
    echo "[INFO] Docker was not found on your system."
    OS_TYPE="$(uname -s)"
    
    case "$OS_TYPE" in
        Linux*)
            echo "[INFO] Installing Docker Engine automatically for Linux..."
            if [ "$(id -u)" -eq 0 ]; then
                if command -v curl >/dev/null 2>&1; then
                    curl -fsSL https://get.docker.com | sh
                elif command -v wget >/dev/null 2>&1; then
                    wget -qO- https://get.docker.com | sh
                fi
                systemctl enable --now docker 2>/dev/null || service docker start 2>/dev/null || true
            elif command -v sudo >/dev/null 2>&1; then
                if command -v curl >/dev/null 2>&1; then
                    curl -fsSL https://get.docker.com | sudo sh
                elif command -v wget >/dev/null 2>&1; then
                    wget -qO- https://get.docker.com | sudo sh
                fi
                sudo systemctl enable --now docker 2>/dev/null || sudo service docker start 2>/dev/null || true
                sudo usermod -aG docker "$USER" 2>/dev/null || true
            else
                echo "[ERROR] Sudo or root privileges are required to install Docker on Linux." >&2
                exit 1
            fi
            ;;
        Darwin*)
            echo "[INFO] Installing Docker Desktop automatically for macOS..."
            if command -v brew >/dev/null 2>&1; then
                brew install --cask docker
            else
                ARCH="$(uname -m)"
                [ "$ARCH" = "x86_64" ] && D_ARCH="amd64" || D_ARCH="arm64"
                echo "[INFO] Downloading Docker Desktop DMG for macOS ($D_ARCH)..."
                curl -fsSL "https://desktop.docker.com/mac/main/${D_ARCH}/Docker.dmg" -o /tmp/Docker.dmg
                hdiutil attach /tmp/Docker.dmg -nobrowse -quiet
                cp -R /Volumes/Docker/Docker.app /Applications/
                hdiutil detach /Volumes/Docker -quiet || true
                rm -f /tmp/Docker.dmg
            fi
            open -a Docker
            ;;
        *)
            echo "[ERROR] Unsupported platform: $OS_TYPE. Please install Docker manually:" >&2
            echo "  https://docs.docker.com/engine/install/" >&2
            exit 1
            ;;
    esac
fi

# 2. Determine Docker Compose binary/plugin
if docker compose version >/dev/null 2>&1; then
    COMPOSE_CMD="docker compose"
elif command -v docker-compose >/dev/null 2>&1; then
    COMPOSE_CMD="docker-compose"
else
    # Install compose plugin on Linux if missing
    if [ "$(uname -s)" = "Linux" ]; then
        if command -v apt-get >/dev/null 2>&1; then
            (sudo apt-get update && sudo apt-get install -y docker-compose-plugin) 2>/dev/null || true
        elif command -v pacman >/dev/null 2>&1; then
            sudo pacman -Sy --noconfirm docker-compose 2>/dev/null || true
        elif command -v dnf >/dev/null 2>&1; then
            sudo dnf install -y docker-compose-plugin 2>/dev/null || true
        fi
    fi
    if docker compose version >/dev/null 2>&1; then
        COMPOSE_CMD="docker compose"
    elif command -v docker-compose >/dev/null 2>&1; then
        COMPOSE_CMD="docker-compose"
    else
        echo "[ERROR] Docker Compose plugin or docker-compose binary not found." >&2
        exit 1
    fi
fi

# 3. Ensure Docker daemon is running
if ! docker info >/dev/null 2>&1; then
    echo "[INFO] Starting Docker service daemon..."
    if [ "$(uname -s)" = "Darwin" ]; then
        open -a Docker 2>/dev/null || true
    else
        if [ "$(id -u)" -eq 0 ]; then
            systemctl start docker 2>/dev/null || service docker start 2>/dev/null || true
        elif command -v sudo >/dev/null 2>&1; then
            sudo systemctl start docker 2>/dev/null || sudo service docker start 2>/dev/null || true
        fi
    fi

    echo "[INFO] Waiting for Docker daemon to become responsive..."
    for i in $(seq 1 20); do
        sleep 2
        if docker info >/dev/null 2>&1; then
            echo "[SUCCESS] Docker daemon is running!"
            break
        fi
    done
fi

# 4. Start OverBranch via Docker Compose
echo ""
echo "[INFO] Starting OverBranch via Docker Compose ($COMPOSE_CMD up -d)..."
$COMPOSE_CMD up -d

echo ""
echo "============================================================"
echo "       OverBranch Self-Host is running successfully!"
echo "============================================================"
echo ""
echo "  Access overbranch through localhost:3000"
echo ""
echo "  • Web Editor Workspace:  http://localhost:3000"
echo "  • TeX Engine API:        http://localhost:8000"
echo "  • Gemini Web2API Proxy:  http://localhost:8081"
echo "============================================================"
echo ""

# Try opening in browser
if command -v xdg-open >/dev/null 2>&1; then
    xdg-open http://localhost:3000 >/dev/null 2>&1 || true
elif command -v open >/dev/null 2>&1; then
    open http://localhost:3000 >/dev/null 2>&1 || true
fi
