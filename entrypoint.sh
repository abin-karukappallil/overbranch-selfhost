#!/bin/bash
set -e

echo "============================================================"
echo "    Starting OverBranch Self-Host Stack (Docker)"
echo "    100% Local • Zero API Keys • SQLite • Gemini Web2API"
echo "============================================================"

# 1. Prepare persistent directories
mkdir -p /app/uploads/projects /app/bin

# 2. Trap termination signals to cleanly shut down background services
WEB2API_PID=""
BACKEND_PID=""

cleanup() {
    echo ""
    echo "Shutting down OverBranch services..."
    if [ -n "$WEB2API_PID" ]; then
        kill -TERM "$WEB2API_PID" 2>/dev/null || true
    fi
    if [ -n "$BACKEND_PID" ]; then
        kill -TERM "$BACKEND_PID" 2>/dev/null || true
    fi
    exit 0
}

trap cleanup EXIT INT TERM

# 3. Ensure Gemini Web2API standalone Go binary is present
if [ ! -x "/app/bin/gemini-web2api" ]; then
    echo "-> Downloading Gemini Web2API proxy binary..."
    ARCH="$(uname -m)"
    case "$ARCH" in
        x86_64|amd64) TARCH="amd64" ;;
        aarch64|arm64) TARCH="arm64" ;;
        *) TARCH="amd64" ;;
    esac
    curl -fsSL "https://github.com/ikhsan3adi/gemini-web2api/releases/download/v1.2.0/gemini-web2api_1.2.0_linux_${TARCH}.tar.gz" -o /tmp/web2api.tar.gz 2>/dev/null && \
    tar -xzf /tmp/web2api.tar.gz -C /app/bin/ 2>/dev/null && \
    chmod +x /app/bin/gemini-web2api && \
    rm -f /tmp/web2api.tar.gz || echo "Notice: Gemini Web2API binary setup skipped."
fi

# 4. Initialize Local SQLite database schema
echo "-> Checking and initializing SQLite schema (overbranch.db)..."
python3 -c "import sys; sys.path.insert(0, 'backend'); from database import init_sqlite_schema; init_sqlite_schema()" || true

# 5. Start Gemini Web2API local Go proxy on port 8081
if [ -x "/app/bin/gemini-web2api" ]; then
    echo "-> Starting Gemini Web2API Proxy (0.0.0.0:8081)..."
    CFG_FLAG=""
    if [ -f "/app/bin/config.json" ]; then
        CFG_FLAG="-config /app/bin/config.json"
    fi
    /app/bin/gemini-web2api -port 8081 $CFG_FLAG >/dev/null 2>&1 &
    WEB2API_PID=$!
fi

# 6. Start FastAPI LaTeX Backend on port 8000
echo "-> Starting FastAPI LaTeX Backend (0.0.0.0:${BACKEND_PORT:-8000})..."
cd /app/backend
(
    UVICORN_PID=""
    trap 'kill -TERM $UVICORN_PID 2>/dev/null; exit 0' TERM INT
    while true; do
        python3 -m uvicorn main:app \
            --host 0.0.0.0 \
            --port "${BACKEND_PORT:-8000}" \
            --workers 1 \
            --proxy-headers \
            --forwarded-allow-ips="*" \
            --timeout-keep-alive 65 \
            --timeout-graceful-shutdown 30 \
            --limit-concurrency 200 &
        UVICORN_PID=$!
        wait $UVICORN_PID
        echo "Backend uvicorn exited (status $?); restarting in 1s..."
        sleep 1
    done
) &
BACKEND_PID=$!

# Wait for backend to report healthy
cd /app
for i in $(seq 1 15); do
    if curl -sf http://localhost:8000/api/health >/dev/null 2>&1; then
        echo "-> Backend health check OK."
        break
    fi
    sleep 1
done

# 7. Print access banner
echo ""
echo "============================================================"
echo "       OverBranch Self-Host is running successfully!        "
echo "============================================================"
echo ""
echo "  • Web Editor Workspace:  http://localhost:3000"
echo "  • TeX Engine API:        http://localhost:8000"
echo "  • Gemini Web2API Proxy:  http://localhost:8081"
echo ""
echo "============================================================"
echo " Access overbranch through localhost:3000"
echo "============================================================"
echo ""

# 8. Start Next.js Web Application on port 3000 with Bun in foreground
echo "-> Starting Next.js Web App with Bun (0.0.0.0:3000)..."
export PORT=3000
export HOSTNAME="0.0.0.0"

if command -v bun >/dev/null 2>&1; then
    exec bun run start
elif command -v npm >/dev/null 2>&1; then
    exec npm run start
else
    exec node_modules/.bin/next start -p 3000 -H 0.0.0.0
fi
