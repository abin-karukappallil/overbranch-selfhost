#!/usr/bin/env bash
# ==============================================================================
# OverBranch Self-Host — Instant Universal Runner (Docker Compose)
# ==============================================================================
# Starts OverBranch immediately in Docker using docker-compose.yml:
#   ./start.sh
# Or 1-line curl launcher:
#   curl -fsSL https://raw.githubusercontent.com/abin-karukappallil/overbranch-selfhost/main/start.sh | bash
# ==============================================================================

set -e

# 1. Locate existing OverBranch directory
WORK_DIR=""

if [ -f "./docker-compose.yml" ] && [ -f "./Dockerfile" ]; then
    WORK_DIR="$(pwd)"
elif [ -d "$HOME/overbranch-selfhost" ] && [ -f "$HOME/overbranch-selfhost/docker-compose.yml" ]; then
    WORK_DIR="$HOME/overbranch-selfhost"
elif [ -d "./overbranch-selfhost" ] && [ -f "./overbranch-selfhost/docker-compose.yml" ]; then
    WORK_DIR="$(pwd)/overbranch-selfhost"
elif [ -n "${BASH_SOURCE[0]}" ] && [ -f "$(dirname "${BASH_SOURCE[0]}")/docker-compose.yml" ]; then
    WORK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fi

# 2. If not found, clone repository
if [ -z "$WORK_DIR" ]; then
    echo "[INFO] OverBranch not detected locally. Cloning repository..."
    REPO_URL="${OVERBRANCH_REPO_URL:-https://github.com/abin-karukappallil/overbranch-selfhost.git}"
    TARGET_DIR="${OVERBRANCH_INSTALL_DIR:-$HOME/overbranch-selfhost}"
    if [ ! -d "$TARGET_DIR" ]; then
        git clone --depth 1 "$REPO_URL" "$TARGET_DIR"
    fi
    WORK_DIR="$TARGET_DIR"
fi

# 3. Enter directory and run via Docker Compose
cd "$WORK_DIR"
chmod +x ./docker-up.sh 2>/dev/null || true
exec ./docker-up.sh "$@"
