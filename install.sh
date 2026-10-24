#!/usr/bin/env bash
# ==============================================================================
# OverBranch Self-Host — One-Line Universal Installer
# ==============================================================================
# Compatible with:
#   - Linux: Ubuntu, Debian, Arch Linux, CentOS, RHEL, Fedora, Alpine, openSUSE
#   - macOS: Intel (x86_64) & Apple Silicon (ARM64 M1/M2/M3/M4)
#   - Windows: Git Bash, MSYS2, MINGW, Cygwin, WSL
#
# Usage (One-Line Curl):
#   curl -fsSL https://raw.githubusercontent.com/abin-karukappallil/overbranch-selfhost/main/install.sh | bash
# Or:
#   bash <(curl -fsSL https://raw.githubusercontent.com/abin-karukappallil/overbranch-selfhost/main/install.sh)
# ==============================================================================

set -eo pipefail

# ANSI Colors
if [ -t 1 ]; then
    CYAN='\033[0;36m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    RED='\033[0;31m'
    BOLD='\033[1m'
    RESET='\033[0m'
else
    CYAN=''
    GREEN=''
    YELLOW=''
    RED=''
    BOLD=''
    RESET=''
fi

log_info() {
    echo -e "${CYAN}[INFO]${RESET} $1"
}

log_ok() {
    echo -e "${GREEN}[OK]${RESET} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${RESET} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${RESET} $1" >&2
}

print_banner() {
    echo -e "${GREEN}${BOLD}"
    cat << "EOF"
  ___                  ____                       _     
 / _ \__   _____ _ __ | __ ) _ __ __ _ _ __   ___| |__  
| | | \ \ / / _ \ '__||  _ \| '__/ _` | '_ \ / __| '_ \ 
| |_| |\ V /  __/ |   | |_) | | | (_| | | | | (__| | | |
 \___/  \_/ \___|_|   |____/|_|  \__,_|_| |_|\___|_| |_|
EOF
    echo -e "${RESET}"
    echo -e "${BOLD}100% Local Self-Hosted LaTeX IDE • Embedded Gemini Web2API • SQLite${RESET}"
    echo -e "Universal One-Line Installer\n"
}

# Detect OS
detect_os() {
    OS_TYPE="$(uname -s)"
    case "$OS_TYPE" in
        Linux*)
            if [ -f /etc/os-release ]; then
                . /etc/os-release
                DISTRO="${ID:-linux}"
            else
                DISTRO="linux"
            fi
            OS_NAME="Linux ($DISTRO)"
            ;;
        Darwin*)
            OS_NAME="macOS"
            DISTRO="macos"
            ;;
        MINGW*|MSYS*|CYGWIN*)
            OS_NAME="Windows"
            DISTRO="windows"
            ;;
        *)
            OS_NAME="Unix-like ($OS_TYPE)"
            DISTRO="unknown"
            ;;
    esac
}

print_banner
detect_os
log_info "Detected Operating System: ${BOLD}${OS_NAME}${RESET}"

# Check required commands
MISSING_DEPS=0

check_cmd() {
    local cmd="$1"
    local name="$2"
    if command -v "$cmd" >/dev/null 2>&1; then
        log_ok "Found ${name}: $(command -v "$cmd")"
        return 0
    else
        log_error "Missing required dependency: ${name} ('${cmd}')"
        return 1
    fi
}

log_info "Checking prerequisites..."

if ! check_cmd "git" "Git"; then
    MISSING_DEPS=1
    case "$DISTRO" in
        ubuntu|debian|pop|mint)
            echo "   -> Install with: sudo apt update && sudo apt install -y git"
            ;;
        arch|manjaro|endeavouros)
            echo "   -> Install with: sudo pacman -S --noconfirm git"
            ;;
        fedora)
            echo "   -> Install with: sudo dnf install -y git"
            ;;
        centos|rhel|rocky|almalinux)
            echo "   -> Install with: sudo yum install -y git"
            ;;
        macos)
            echo "   -> Install with: xcode-select --install  or  brew install git"
            ;;
        *)
            echo "   -> Please install Git using your system package manager."
            ;;
    esac
fi

# Detect Python (Python 3.9+)
PYTHON_BIN=""
if command -v python3 >/dev/null 2>&1; then
    PYTHON_BIN="python3"
elif command -v python >/dev/null 2>&1; then
    PYTHON_BIN="python"
fi

if [ -n "$PYTHON_BIN" ]; then
    PY_VER="$("$PYTHON_BIN" -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")' 2>/dev/null || echo "0.0")"
    log_ok "Found Python: $("$PYTHON_BIN" --version 2>&1) ($PYTHON_BIN)"
else
    log_error "Missing required dependency: Python (version 3.9 or higher)"
    MISSING_DEPS=1
    case "$DISTRO" in
        ubuntu|debian|pop|mint)
            echo "   -> Install with: sudo apt update && sudo apt install -y python3 python3-venv python3-pip"
            ;;
        arch|manjaro|endeavouros)
            echo "   -> Install with: sudo pacman -S --noconfirm python python-pip"
            ;;
        fedora)
            echo "   -> Install with: sudo dnf install -y python3 python3-pip"
            ;;
        centos|rhel|rocky|almalinux)
            echo "   -> Install with: sudo yum install -y python3 python3-pip"
            ;;
        macos)
            echo "   -> Install with: brew install python"
            ;;
        *)
            echo "   -> Please install Python 3.9+ using your system package manager."
            ;;
    esac
fi

# Detect Node.js / Bun
NODE_OK=0
if command -v bun >/dev/null 2>&1; then
    log_ok "Found Bun: $(bun --version 2>&1)"
    NODE_OK=1
elif command -v node >/dev/null 2>&1 && command -v npm >/dev/null 2>&1; then
    log_ok "Found Node.js: $(node --version 2>&1) with npm $(npm --version 2>&1)"
    NODE_OK=1
fi

if [ $NODE_OK -eq 0 ]; then
    log_warn "Neither Bun nor Node.js / npm was found."
    log_info "Attempting to install Bun automatically for blazing-fast performance..."
    if command -v curl >/dev/null 2>&1; then
        curl -fsSL https://bun.sh/install | bash || true
        export BUN_INSTALL="$HOME/.bun"
        export PATH="$BUN_INSTALL/bin:$PATH"
        if command -v bun >/dev/null 2>&1; then
            log_ok "Successfully installed Bun: $(bun --version 2>&1)"
            NODE_OK=1
        fi
    fi
    if [ $NODE_OK -eq 0 ]; then
        log_error "Please install Node.js (v18+) or Bun (v1+) to run the web frontend."
        MISSING_DEPS=1
    fi
fi

# Check pdflatex / latexmk (optional but recommended)
if command -v pdflatex >/dev/null 2>&1 || command -v latexmk >/dev/null 2>&1; then
    log_ok "Found LaTeX compiler: $(command -v pdflatex || command -v latexmk)"
else
    log_warn "LaTeX engine (pdflatex / latexmk) not found on PATH."
    log_warn "You can install TeX Live anytime to enable full offline PDF builds:"
    case "$DISTRO" in
        ubuntu|debian|pop|mint)
            echo "   -> sudo apt install -y texlive-latex-base texlive-latex-extra latexmk"
            ;;
        arch|manjaro)
            echo "   -> sudo pacman -S --noconfirm texlive-basic texlive-latexextra"
            ;;
        fedora)
            echo "   -> sudo dnf install -y texlive-scheme-basic latexmk"
            ;;
        macos)
            echo "   -> brew install --cask mactex-no-gui"
            ;;
    esac
fi

if [ $MISSING_DEPS -ne 0 ]; then
    echo ""
    log_error "Please install the missing tools above and re-run this installer."
    exit 1
fi

# Locate or clone repository
REPO_URL="${OVERBRANCH_REPO_URL:-https://github.com/abin-karukappallil/overbranch-selfhost.git}"
TARGET_DIR="${OVERBRANCH_INSTALL_DIR:-overbranch-selfhost}"

# Determine if we are already inside overbranch-selfhost
if [ -f "./install.py" ] && [ -d "./backend" ] && [ -f "./package.json" ]; then
    log_info "Currently inside OverBranch Self-Host directory. Proceeding..."
    WORK_DIR="$(pwd)"
elif [ -f "./overbranch-selfhost/install.py" ]; then
    log_info "Detected overbranch-selfhost subdirectory. Entering..."
    cd "./overbranch-selfhost"
    WORK_DIR="$(pwd)"
elif [ -n "${BASH_SOURCE[0]}" ] && [ -f "$(dirname "${BASH_SOURCE[0]}")/install.py" ]; then
    cd "$(dirname "${BASH_SOURCE[0]}")"
    WORK_DIR="$(pwd)"
else
    log_info "Cloning OverBranch repository from ${CYAN}${REPO_URL}${RESET}..."
    if [ -d "$TARGET_DIR" ]; then
        log_warn "Directory '${TARGET_DIR}' already exists. Using existing folder."
    else
        git clone --depth 1 "$REPO_URL" "$TARGET_DIR"
    fi
    
    if [ -d "${TARGET_DIR}/overbranch-selfhost" ]; then
        cd "${TARGET_DIR}/overbranch-selfhost"
    else
        cd "$TARGET_DIR"
    fi
    WORK_DIR="$(pwd)"
fi

log_ok "Working directory: ${WORK_DIR}"

# Run Python installer
echo ""
log_info "Starting core setup via Python installer..."
"$PYTHON_BIN" install.py "$@"

# Post-install banner
echo ""
echo -e "${GREEN}${BOLD}============================================================${RESET}"
echo -e "${GREEN}${BOLD}   OverBranch Self-Host Installation Succeeded!${RESET}"
echo -e "${GREEN}${BOLD}============================================================${RESET}"
echo ""
echo -e "All services are self-contained with ${BOLD}zero .env configuration${RESET}:"
echo -e "  • Web Frontend:    ${CYAN}http://localhost:3000${RESET}"
echo -e "  • TeX Engine API:  ${CYAN}http://localhost:8000${RESET}"
echo -e "  • Gemini Proxy:    ${CYAN}http://localhost:8081${RESET}"
echo -e "  • Database:        ${CYAN}overbranch.db (SQLite with Vector Search)${RESET}"
echo ""
echo -e "To start OverBranch anytime, run:"
echo -e "  ${BOLD}cd ${WORK_DIR}${RESET}"
echo -e "  ${BOLD}./run.sh${RESET}  (or: ${BOLD}${PYTHON_BIN} run.py${RESET})"
echo ""

# Interactive start prompt if a terminal is attached
START_APP=""
if [ -t 0 ]; then
    echo -ne "${BOLD}Would you like to start OverBranch right now? [Y/n] (auto-skip in 10s): ${RESET}"
    read -r -t 10 START_APP || START_APP="n"
elif [ -e /dev/tty ] && [ -r /dev/tty ]; then
    echo -ne "${BOLD}Would you like to start OverBranch right now? [Y/n] (auto-skip in 10s): ${RESET}"
    read -r -t 10 START_APP < /dev/tty 2>/dev/null || START_APP="n"
fi

if [[ -z "$START_APP" || "$START_APP" =~ ^[Yy]$ ]]; then
    echo ""
    log_info "Launching OverBranch Self-Host stack..."
    exec ./run.sh
fi
