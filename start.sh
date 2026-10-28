#!/usr/bin/env bash
# ==============================================================================
# OverBranch Self-Host — Instant Universal Runner
# ==============================================================================
# Starts OverBranch immediately without re-cloning or re-installing:
#   ./start.sh
# Or 1-line curl launcher:
#   curl -fsSL https://raw.githubusercontent.com/abin-karukappallil/overbranch-selfhost/main/start.sh | bash
# ==============================================================================

set -e

# 1. Locate existing OverBranch directory
WORK_DIR=""

if [ -f "./run.py" ] && [ -d "./backend" ] && [ -f "./package.json" ]; then
    WORK_DIR="$(pwd)"
elif [ -d "$HOME/overbranch-selfhost" ] && [ -f "$HOME/overbranch-selfhost/run.py" ]; then
    WORK_DIR="$HOME/overbranch-selfhost"
elif [ -d "./overbranch-selfhost" ] && [ -f "./overbranch-selfhost/run.py" ]; then
    WORK_DIR="$(pwd)/overbranch-selfhost"
elif [ -n "${BASH_SOURCE[0]}" ] && [ -f "$(dirname "${BASH_SOURCE[0]}")/run.py" ]; then
    WORK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fi

# 2. If not found, clone once and install
if [ -z "$WORK_DIR" ]; then
    echo "[INFO] OverBranch not detected locally. Running one-time installer..."
    REPO_URL="${OVERBRANCH_REPO_URL:-https://github.com/abin-karukappallil/overbranch-selfhost.git}"
    TARGET_DIR="${OVERBRANCH_INSTALL_DIR:-$HOME/overbranch-selfhost}"
    git clone --depth 1 "$REPO_URL" "$TARGET_DIR"
    WORK_DIR="$TARGET_DIR"
    cd "$WORK_DIR"
    python3 install.py
fi

# 3. Enter directory and run the stack
cd "$WORK_DIR"

if [ "$1" = "--docker" ] || [ "${DOCKER:-0}" = "1" ]; then
    chmod +x ./docker-up.sh
    exec ./docker-up.sh
fi

if command -v python3 >/dev/null 2>&1; then
    exec python3 run.py "$@"
elif command -v python >/dev/null 2>&1; then
    exec python run.py "$@"
else
    echo "Error: Python 3 or Docker is required to run OverBranch Self-Host." >&2
    exit 1
fi
