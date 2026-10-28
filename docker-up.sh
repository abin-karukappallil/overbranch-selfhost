#!/usr/bin/env bash
# ==============================================================================
# OverBranch Self-Host — Universal Docker Compose Launcher with Auto-Installer
# ==============================================================================
# Compatible with: Linux (all distributions) and macOS (Intel & Apple Silicon)
# ==============================================================================

set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$DIR"

ACTION="${1:-up}"

# 1. Determine if sudo is required to communicate with Docker socket (Linux non-root users)
SUDO_PREFIX=""
if [ "$(id -u)" -ne 0 ] && command -v docker >/dev/null 2>&1; then
    DOCKER_ERR=$(docker info 2>&1 || true)
    if echo "$DOCKER_ERR" | grep -qi "permission denied"; then
        if command -v sudo >/dev/null 2>&1; then
            echo "[INFO] Non-root user '$USER' does not have direct permission for /var/run/docker.sock."
            echo "[INFO] Using 'sudo' for Docker commands (you may be prompted for your sudo password)..."
            SUDO_PREFIX="sudo "
            
            # Attempt to add user to docker group so future logins don't require sudo
            if ! groups "$USER" 2>/dev/null | grep -q "\bdocker\b"; then
                echo "[INFO] Adding '$USER' to the 'docker' group for future sessions..."
                sudo usermod -aG docker "$USER" 2>/dev/null || true
                echo "[TIP] To run Docker without sudo in future sessions, run: newgrp docker"
            fi
        fi
    fi
fi

# 2. Determine Docker Compose binary/plugin
if ${SUDO_PREFIX}docker compose version >/dev/null 2>&1 || docker compose version >/dev/null 2>&1; then
    COMPOSE_CMD="${SUDO_PREFIX}docker compose"
elif command -v docker-compose >/dev/null 2>&1; then
    COMPOSE_CMD="${SUDO_PREFIX}docker-compose"
else
    # Install compose plugin on Linux if missing
    if [ "$(uname -s)" = "Linux" ]; then
        if command -v apt-get >/dev/null 2>&1; then
            (${SUDO_PREFIX}apt-get update && ${SUDO_PREFIX}apt-get install -y docker-compose-plugin) 2>/dev/null || true
        elif command -v pacman >/dev/null 2>&1; then
            ${SUDO_PREFIX}pacman -Sy --noconfirm docker-compose 2>/dev/null || true
        elif command -v dnf >/dev/null 2>&1; then
            ${SUDO_PREFIX}dnf install -y docker-compose-plugin 2>/dev/null || true
        fi
    fi
    if ${SUDO_PREFIX}docker compose version >/dev/null 2>&1 || docker compose version >/dev/null 2>&1; then
        COMPOSE_CMD="${SUDO_PREFIX}docker compose"
    elif command -v docker-compose >/dev/null 2>&1; then
        COMPOSE_CMD="${SUDO_PREFIX}docker-compose"
    else
        echo "[ERROR] Docker Compose plugin or docker-compose binary not found." >&2
        exit 1
    fi
fi

# 3. Handle management subcommands
case "$ACTION" in
    down|stop)
        echo "[INFO] Stopping OverBranch containers..."
        exec $COMPOSE_CMD down
        ;;
    logs)
        shift 2>/dev/null || true
        exec $COMPOSE_CMD logs -f "$@"
        ;;
    ps|status)
        exec $COMPOSE_CMD ps
        ;;
    restart)
        echo "[INFO] Restarting OverBranch containers..."
        exec $COMPOSE_CMD restart
        ;;
esac

echo "============================================================"
echo "          OverBranch Self-Host Docker Launcher"
echo "    100% Local • Zero API Keys • SQLite • Gemini Web2API"
echo "============================================================"
echo ""

# 4. Detect and install Docker if not present
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
                SUDO_PREFIX="sudo "
                COMPOSE_CMD="${SUDO_PREFIX}${COMPOSE_CMD}"
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

# 5. Ensure Docker daemon is running
if ! ${SUDO_PREFIX}docker info >/dev/null 2>&1; then
    echo "[INFO] Docker daemon is not active. Attempting to start Docker service..."
    if [ "$(uname -s)" = "Darwin" ]; then
        open -a Docker 2>/dev/null || true
    else
        if [ "$(id -u)" -eq 0 ]; then
            systemctl start docker 2>/dev/null || service docker start 2>/dev/null || true
        elif command -v sudo >/dev/null 2>&1; then
            echo "[INFO] Starting Docker service (sudo password may be required)..."
            sudo systemctl start docker || sudo service docker start || true
        fi
    fi

    echo "[INFO] Waiting for Docker daemon to become responsive..."
    for i in $(seq 1 20); do
        sleep 2
        if ${SUDO_PREFIX}docker info >/dev/null 2>&1; then
            echo "[SUCCESS] Docker daemon is running!"
            break
        fi
    done

    if ! ${SUDO_PREFIX}docker info >/dev/null 2>&1; then
        echo "[ERROR] Could not connect to Docker daemon. Please ensure Docker is running and rerun:" >&2
        echo "  sudo systemctl start docker   (Linux)" >&2
        echo "  or start Docker Desktop       (macOS / Windows)" >&2
        exit 1
    fi
fi

# 6. Prepare required local files and directories (prevents Docker directory-mount bug)
if [ -d "$DIR/overbranch.db" ]; then
    echo "[WARN] Detected 'overbranch.db' as a directory. Correcting to SQLite database file..."
    rm -rf "$DIR/overbranch.db"
fi
if [ ! -f "$DIR/overbranch.db" ]; then
    touch "$DIR/overbranch.db"
fi
mkdir -p "$DIR/uploads"

# 7. Execute Docker Compose
case "$ACTION" in
    build)
        echo "[INFO] Building and starting OverBranch via Docker Compose ($COMPOSE_CMD up --build -d)..."
        shift 2>/dev/null || true
        $COMPOSE_CMD up --build -d "$@"
        ;;
    up|start)
        shift 2>/dev/null || true
        echo "[INFO] Starting OverBranch via Docker Compose ($COMPOSE_CMD up -d)..."
        $COMPOSE_CMD up -d "$@"
        ;;
    *)
        echo "[INFO] Starting OverBranch via Docker Compose ($COMPOSE_CMD up -d)..."
        $COMPOSE_CMD up -d "$@"
        ;;
esac

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
echo "  Management commands:"
echo "    ./docker-up.sh stop     (or ./run.sh stop)    - Stop containers"
echo "    ./docker-up.sh logs     (or ./run.sh logs)    - View container logs"
echo "    ./docker-up.sh restart  (or ./run.sh restart) - Restart services"
echo "============================================================"
echo ""

# Try opening in browser
if command -v xdg-open >/dev/null 2>&1; then
    xdg-open http://localhost:3000 >/dev/null 2>&1 || true
elif command -v open >/dev/null 2>&1; then
    open http://localhost:3000 >/dev/null 2>&1 || true
fi
