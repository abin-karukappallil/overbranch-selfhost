#!/usr/bin/env bash
# ==============================================================================
# OverBranch Self-Host — Runner Script (Docker Compose)
# ==============================================================================
# Runs OverBranch inside Docker using docker-compose.yml.
# Supports commands:
#   ./run.sh            (starts containers in background)
#   ./run.sh stop       (stops containers)
#   ./run.sh logs       (views live container logs)
#   ./run.sh restart    (restarts containers)
#   ./run.sh status     (shows container status)
#   ./run.sh build      (rebuilds image and starts)
# ==============================================================================

set -e
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$DIR"

chmod +x "$DIR/docker-up.sh" 2>/dev/null || true
exec "$DIR/docker-up.sh" "$@"
