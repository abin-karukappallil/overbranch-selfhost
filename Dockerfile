# ============================================================
# OverBranch Self-Host — application image
# ============================================================
# Thin layer over the published TeX base (docker/texlive.Dockerfile, built by
# .github/workflows/texlive-base.yml). Runs Next.js (3000), the FastAPI LaTeX
# engine (8000) and the embedded Gemini Web2API proxy (8081).
#
# TeX Live and fonts are NOT built here: they come from the base image, which
# CI builds and smoke-tests once per release. CI passes the digest-pinned ref
# from docker/texlive-base.lock; the default below is only for a bare
# `docker build .`.
# ============================================================

ARG TEX_BASE=ghcr.io/abin-karukappallil/overbranch-texlive:2026
FROM ${TEX_BASE} AS app

ENV DEBIAN_FRONTEND=noninteractive
ENV NEXT_TELEMETRY_DISABLED=1

# 1. Assert the base is the TeX Live this app needs. minted only works at
#    runtime on TeX Live >= 2025 (latexminted is allow-listed in restricted
#    shell-escape; backend/compiler.py never passes -shell-escape).
RUN pdflatex --version | head -1 | grep -qi "pdfTeX" && \
    kpsewhich beamer.cls && \
    kpsewhich tikz.sty && \
    test "$(kpsewhich -var-value shell_escape)" = "p" && \
    kpsewhich -var-value shell_escape_commands | tr ',' '\n' | grep -qx latexminted && \
    echo "TeX Live Base Assertions PASSED"

# 2. Bun (pinned to the version that wrote bun.lock)
RUN npm install -g bun@1.3.5

WORKDIR /app

# 3. Gemini Web2API Go proxy. A missing proxy would silently disable AI, so
#    this must fail the build (entrypoint.sh keeps a runtime fallback).
#    dpkg's arch names (amd64/arm64) match the release asset names.
RUN set -eux; \
    ARCH="$(dpkg --print-architecture)"; \
    mkdir -p /app/bin; \
    curl -fsSL --retry 5 --retry-delay 3 \
      "https://github.com/ikhsan3adi/gemini-web2api/releases/download/v1.2.0/gemini-web2api_1.2.0_linux_${ARCH}.tar.gz" \
      -o /tmp/web2api.tar.gz; \
    tar -xzf /tmp/web2api.tar.gz -C /app/bin/; \
    rm -f /tmp/web2api.tar.gz; \
    chmod +x /app/bin/gemini-web2api

# 4. Node dependencies — a lockfile mismatch must fail, not silently re-resolve
COPY package.json bun.lock ./
RUN bun install --frozen-lockfile

# 5. Python dependencies
COPY backend/requirements.txt ./backend/requirements.txt
RUN python3 -m pip install \
    --no-cache-dir \
    --break-system-packages \
    -r backend/requirements.txt

# 6. Application source (.dockerignore keeps host databases and binaries out)
COPY . .

# 7. Zero-configuration production environment.
#    OVERBRANCH_DATA_DIR is a Docker volume holding the SQLite DB and its
#    -wal/-shm files together.
ENV NODE_ENV=production \
    PORT=3000 \
    HOSTNAME=0.0.0.0 \
    OVERBRANCH_DATA_DIR=/app/data \
    NEXT_PUBLIC_APP_URL=http://localhost:3000 \
    NEXT_PUBLIC_BACKEND_URL=http://localhost:8000 \
    BACKEND_URL=http://localhost:8000 \
    WEB2API_BASE_URL=http://localhost:8081/v1 \
    GEMINI_WEB2API_BASE_URL=http://localhost:8081/v1 \
    WEB2API_API_KEY=local \
    GEMINI_WEB2API_API_KEY=local \
    BETTER_AUTH_SECRET=selfhost-local-sample-secret-overbranch-2026 \
    BETTER_AUTH_URL=http://localhost:3000 \
    NEXT_PUBLIC_ZERO_AUTH=true

# 8. Build Next.js
RUN bun run build

# 3000: Next.js   8000: FastAPI   8081: Gemini Web2API
EXPOSE 3000 8000 8081

# Volumes (/app/data, /app/uploads) are declared in docker-compose.yml only:
# a Dockerfile VOLUME creates orphaned anonymous volumes for `docker run` users.

# Both the API and the web app must answer.
HEALTHCHECK \
    --interval=30s \
    --timeout=10s \
    --start-period=60s \
    --retries=3 \
    CMD curl -sf http://localhost:8000/api/health && curl -sf -o /dev/null http://localhost:3000 || exit 1

RUN chmod +x /app/entrypoint.sh
ENTRYPOINT ["/app/entrypoint.sh"]
