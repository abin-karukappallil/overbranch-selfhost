# ============================================================
# OverBranch Self-Host Dockerfile (Multi-stage)
# ============================================================
# 100% Local • Zero-Configuration • Non-Breakable LaTeX Compiler
# Runs Next.js (port 3000), FastAPI LaTeX Engine (port 8000),
# and Embedded Gemini Web2API Proxy (port 8081).
# ============================================================

ARG TEX_BASE=texlive-base

# ============================================================
# Stage 1: Non-Breakable TeX Live & Fonts Base Image
# (Only built when TEX_BASE=texlive-base; reuses external base if provided)
# ============================================================
FROM node:22-bookworm-slim AS texlive-base

ENV DEBIAN_FRONTEND=noninteractive
ENV NEXT_TELEMETRY_DISABLED=1

# 1. System dependencies + PDF tooling + all system fonts from parent app
RUN sed -i 's/ main$/ main contrib/' /etc/apt/sources.list.d/debian.sources 2>/dev/null || \
    sed -i 's/ main$/ main contrib/' /etc/apt/sources.list 2>/dev/null || true && \
    apt-get update && \
    apt-get upgrade -y && \
    apt-get install -y --no-install-recommends \
    # Python & runtime
    python3 \
    python3-pip \
    python3-venv \
    python3-pygments \
    # PDF tooling
    ghostscript \
    poppler-utils \
    # General utilities
    perl \
    ca-certificates \
    curl \
    wget \
    unzip \
    xz-utils \
    fontconfig \
    # Metric-compatible MS fonts
    fonts-crosextra-carlito \
    fonts-crosextra-caladea \
    fonts-croscore \
    fonts-liberation \
    fonts-liberation2 \
    fonts-urw-base35 \
    fonts-dejavu \
    # Common TeX/Overleaf typography
    fonts-freefont-ttf \
    fonts-freefont-otf \
    fonts-linuxlibertine \
    fonts-ebgaramond \
    fonts-ebgaramond-extra \
    fonts-open-sans \
    fonts-roboto-unhinted \
    fonts-lato \
    fonts-cantarell \
    fonts-inconsolata \
    fonts-hack \
    fonts-firacode \
    fonts-fira-sans \
    fonts-jetbrains-mono \
    fonts-ibm-plex \
    fonts-stix \
    fonts-symbola \
    fonts-texgyre \
    fonts-lmodern \
    # CJK fonts
    fonts-noto-cjk \
    fonts-ipafont-gothic \
    fonts-ipafont-mincho \
    fonts-nanum \
    fonts-wqy-microhei \
    fonts-wqy-zenhei \
    fonts-arphic-uming \
    fonts-arphic-ukai \
    # Global script coverage
    fonts-noto-core \
    fonts-noto-extra \
    fonts-noto-ui-core \
    fonts-noto-color-emoji \
    fonts-indic \
    fonts-smc \
    fonts-hosny-amiri \
    fonts-thai-tlwg \
    fonts-sil-charis \
    fonts-sil-gentium \
    fonts-sil-gentiumplus \
    fonts-sil-doulos \
    fonts-sil-scheherazade \
    fonts-sil-padauk \
    && rm -rf /var/lib/apt/lists/*

# 2. Microsoft core fonts (Times New Roman, Arial, Courier New, Georgia, etc.)
RUN sed -i 's/ main$/ main contrib/' /etc/apt/sources.list.d/debian.sources 2>/dev/null || \
    sed -i 's/ main$/ main contrib/' /etc/apt/sources.list 2>/dev/null || true && \
    apt-get update && \
    echo "ttf-mscorefonts-installer msttcorefonts/accepted-mscorefonts-eula select true" \
        | debconf-set-selections && \
    for attempt in 1 2 3; do \
        apt-get install -y --no-install-recommends ttf-mscorefonts-installer && break; \
        echo "mscorefonts attempt $attempt failed; retrying..." >&2; sleep 5; \
    done && \
    rm -rf /var/lib/apt/lists/*

# 3. Non-Breakable, Complete TeX Live toolchain
# Installs pdflatex, xelatex, lualatex, latexmk, biber, beamer, tikz/pgf, amsmath, newtx, and all packages
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    texlive-latex-base \
    texlive-latex-recommended \
    texlive-latex-extra \
    texlive-pictures \
    texlive-fonts-recommended \
    texlive-fonts-extra \
    texlive-science \
    texlive-xetex \
    texlive-luatex \
    texlive-bibtex-extra \
    biber \
    latexmk \
    cm-super \
    && rm -rf /var/lib/apt/lists/*

# 4. Fontconfig registration for TeX Live OpenType/TrueType fonts
RUN printf '%s\n' \
    '<?xml version="1.0"?>' \
    '<!DOCTYPE fontconfig SYSTEM "fonts.dtd">' \
    '<fontconfig>' \
    '  <dir>/usr/share/texlive/texmf-dist/fonts/opentype</dir>' \
    '  <dir>/usr/share/texlive/texmf-dist/fonts/truetype</dir>' \
    '  <dir>/usr/share/texlive/texmf-dist/fonts/type1</dir>' \
    '  <dir>/usr/share/texmf/fonts/opentype</dir>' \
    '  <dir>/usr/share/texmf/fonts/truetype</dir>' \
    '  <dir>/usr/local/share/fonts</dir>' \
    '</fontconfig>' \
    > /etc/fonts/conf.d/09-texlive-fonts.conf && \
    fc-cache -f && \
    mktexlsr && \
    updmap-sys --force || true

# 5. Font coverage gate
COPY docker/check-fonts.sh /usr/local/bin/ob-check-fonts
RUN chmod +x /usr/local/bin/ob-check-fonts && ob-check-fonts

# 6. Build-time smoke compiles (ensures compiler is 100% functional)
COPY docker/smoke-tests /usr/local/share/overbranch/smoke-tests
RUN set -eux; cd /usr/local/share/overbranch/smoke-tests; \
    echo "== pdflatex + newtx =="; \
    max_print_line=10000 pdflatex -interaction=nonstopmode -halt-on-error pdflatex_newtx.tex; \
    test -f pdflatex_newtx.pdf; \
    echo "== xelatex + fontspec =="; \
    xelatex -interaction=nonstopmode -halt-on-error xelatex_fontspec.tex; \
    test -f xelatex_fontspec.pdf; \
    echo "== lualatex + unicode-math =="; \
    lualatex -interaction=nonstopmode -halt-on-error lualatex_math.tex; \
    test -f lualatex_math.pdf; \
    echo "== biblatex + biber via latexmk =="; \
    latexmk -pdf -interaction=nonstopmode bib.tex; \
    test -f bib.pdf; \
    echo "== makeindex + glossaries via latexmk =="; \
    latexmk -pdf -interaction=nonstopmode glos.tex; \
    test -f glos.pdf; \
    echo "== minted under restricted shell-escape =="; \
    latexmk -pdf -interaction=nonstopmode mint.tex; \
    test -f mint.pdf; \
    echo "== beamer metropolis =="; \
    latexmk -pdf -interaction=nonstopmode deck.tex || \
      xelatex -interaction=nonstopmode -halt-on-error deck.tex; \
    test -f deck.pdf; \
    echo "ALL SMOKE COMPILES PASSED"; \
    latexmk -C >/dev/null 2>&1 || true

LABEL org.overbranch.version="selfhost-1.0.0"


# ============================================================
# Stage 2: Application
# ============================================================
FROM ${TEX_BASE} AS app

ENV DEBIAN_FRONTEND=noninteractive
ENV NEXT_TELEMETRY_DISABLED=1

# 1. Assert TeX base is healthy
RUN pdflatex --version | head -1 | grep -qi "pdfTeX" && \
    kpsewhich beamer.cls && \
    kpsewhich tikz.sty && \
    echo "TeX Live Base Assertions PASSED"

# 2. Install Bun
RUN npm install -g bun@latest

# 3. Application directory
WORKDIR /app

# 4. Download Gemini Web2API standalone Go binary for zero-config AI
ARG TARGETARCH
RUN set -eux; \
    ARCH="${TARGETARCH:-amd64}"; \
    if [ "$ARCH" = "x86_64" ]; then ARCH="amd64"; fi; \
    if [ "$ARCH" = "aarch64" ]; then ARCH="arm64"; fi; \
    mkdir -p /app/bin; \
    curl -fsSL "https://github.com/ikhsan3adi/gemini-web2api/releases/download/v1.2.0/gemini-web2api_1.2.0_linux_${ARCH}.tar.gz" -o /tmp/web2api.tar.gz || true; \
    if [ -f /tmp/web2api.tar.gz ]; then \
        tar -xzf /tmp/web2api.tar.gz -C /app/bin/ || true; \
        rm -f /tmp/web2api.tar.gz; \
    fi; \
    if [ -f /app/bin/gemini-web2api ]; then \
        chmod +x /app/bin/gemini-web2api; \
    fi

# 5. Install Node.js dependencies
COPY package.json bun.lock* ./
RUN bun install --frozen-lockfile || bun install

# 6. Install Python dependencies
COPY backend/requirements.txt ./backend/requirements.txt
RUN python3 -m pip install \
    --no-cache-dir \
    --break-system-packages \
    -r backend/requirements.txt

# 7. Copy application source
COPY . .

# 8. Zero-configuration production environment variables
ENV NODE_ENV=production \
    PORT=3000 \
    HOSTNAME=0.0.0.0 \
    DATABASE_URL=file:/app/overbranch.db \
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

# 9. Build Next.js application
RUN bun run build

# 10. Runtime ports
# 3000: Next.js Frontend
# 8000: FastAPI Backend
# 8081: Gemini Web2API Proxy
EXPOSE 3000 8000 8081

# 11. Persistent storage
VOLUME ["/app/uploads"]

# 12. Health check
HEALTHCHECK \
    --interval=30s \
    --timeout=10s \
    --start-period=30s \
    --retries=3 \
    CMD curl -sf http://localhost:8000/api/health || exit 1

# 13. Entrypoint
RUN chmod +x /app/entrypoint.sh
ENTRYPOINT ["/app/entrypoint.sh"]
