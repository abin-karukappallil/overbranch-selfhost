#!/usr/bin/env bash
# ==============================================================================
# OverBranch Self-Host — 1-Click Docker Compose Launcher
# ==============================================================================

set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$DIR"

echo "============================================================"
echo "          OverBranch Self-Host Docker Launcher"
echo "    100% Local • Zero API Keys • SQLite • Gemini Web2API"
echo "============================================================"
echo ""

if command -v docker >/dev/null 2>&1; then
    if docker compose version >/dev/null 2>&1; then
        COMPOSE_CMD="docker compose"
    elif command -v docker-compose >/dev/null 2>&1; then
        COMPOSE_CMD="docker-compose"
    else
        echo "[ERROR] Docker Compose plugin or docker-compose binary not found." >&2
        exit 1
    fi
else
    echo "[ERROR] Docker is not installed. Please install Docker first:" >&2
    echo "  https://docs.docker.com/engine/install/" >&2
    exit 1
fi

if ! docker info >/dev/null 2>&1; then
    echo "[ERROR] Docker daemon is not running. Please start Docker first." >&2
    exit 1
fi

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
