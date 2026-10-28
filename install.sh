#!/usr/bin/env bash
# ==============================================================================
# OverBranch Self-Host — Universal Docker Compose Installer
# ==============================================================================
# Installs and runs OverBranch inside Docker using docker-compose.yml.
# Compatible with:
#   - Linux: Ubuntu, Debian, Arch Linux, CentOS, RHEL, Fedora, Alpine, openSUSE
#   - macOS: Intel (x86_64) & Apple Silicon (ARM64 M1/M2/M3/M4)
#   - Windows: Git Bash, MSYS2, WSL
#
# Usage (One-Line Curl):
#   curl -fsSL https://raw.githubusercontent.com/abin-karukappallil/overbranch-selfhost/main/install.sh | bash
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

log_info() { echo -e "${CYAN}[INFO]${RESET} $1"; }
log_ok() { echo -e "${GREEN}[OK]${RESET} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${RESET} $1"; }
log_error() { echo -e "${RED}[ERROR]${RESET} $1" >&2; }

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
    echo -e "${BOLD}100% Local Self-Hosted LaTeX IDE • Docker Compose • Zero Configuration${RESET}"
    echo -e "Universal Docker Installer\n"
}

# 1. Detect OS
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

# 2. Check for Git
if ! command -v git >/dev/null 2>&1; then
    log_info "Git is required. Attempting installation..."
    if [ "$DISTRO" = "macos" ]; then
        xcode-select --install 2>/dev/null || brew install git 2>/dev/null || true
    elif [ "$(id -u)" -eq 0 ]; then
        if command -v apt-get >/dev/null 2>&1; then apt-get update && apt-get install -y git; fi
        if command -v pacman >/dev/null 2>&1; then pacman -Sy --noconfirm git; fi
        if command -v dnf >/dev/null 2>&1; then dnf install -y git; fi
    elif command -v sudo >/dev/null 2>&1; then
        if command -v apt-get >/dev/null 2>&1; then sudo apt-get update && sudo apt-get install -y git; fi
        if command -v pacman >/dev/null 2>&1; then sudo pacman -Sy --noconfirm git; fi
        if command -v dnf >/dev/null 2>&1; then sudo dnf install -y git; fi
    fi
fi

# 3. Locate or clone repository
WORK_DIR=""
if [ -f "./docker-compose.yml" ] && [ -f "./Dockerfile" ]; then
    WORK_DIR="$(pwd)"
elif [ -d "$HOME/overbranch-selfhost" ] && [ -f "$HOME/overbranch-selfhost/docker-compose.yml" ]; then
    WORK_DIR="$HOME/overbranch-selfhost"
elif [ -d "./overbranch-selfhost" ] && [ -f "./overbranch-selfhost/docker-compose.yml" ]; then
    WORK_DIR="$(pwd)/overbranch-selfhost"
fi

if [ -z "$WORK_DIR" ]; then
    REPO_URL="${OVERBRANCH_REPO_URL:-https://github.com/abin-karukappallil/overbranch-selfhost.git}"
    TARGET_DIR="${OVERBRANCH_INSTALL_DIR:-$HOME/overbranch-selfhost}"
    log_info "Cloning OverBranch repository from ${CYAN}${REPO_URL}${RESET} into ${TARGET_DIR}..."
    if [ ! -d "$TARGET_DIR" ]; then
        git clone --depth 1 "$REPO_URL" "$TARGET_DIR"
    fi
    WORK_DIR="$TARGET_DIR"
fi

cd "$WORK_DIR"
log_ok "Working directory: ${WORK_DIR}"

# 4. Check & Install Docker Engine if missing
if ! command -v docker >/dev/null 2>&1; then
    log_info "Docker is not detected on your system. Installing Docker automatically..."
    case "$DISTRO" in
        macos)
            if command -v brew >/dev/null 2>&1; then
                brew install --cask docker
            else
                ARCH="$(uname -m)"
                [ "$ARCH" = "x86_64" ] && D_ARCH="amd64" || D_ARCH="arm64"
                log_info "Downloading Docker Desktop DMG for macOS ($D_ARCH)..."
                curl -fsSL "https://desktop.docker.com/mac/main/${D_ARCH}/Docker.dmg" -o /tmp/Docker.dmg
                hdiutil attach /tmp/Docker.dmg -nobrowse -quiet
                cp -R /Volumes/Docker/Docker.app /Applications/
                hdiutil detach /Volumes/Docker -quiet || true
                rm -f /tmp/Docker.dmg
            fi
            open -a Docker
            ;;
        *)
            if [ "$(id -u)" -eq 0 ]; then
                curl -fsSL https://get.docker.com | sh
                systemctl enable --now docker 2>/dev/null || service docker start 2>/dev/null || true
            elif command -v sudo >/dev/null 2>&1; then
                log_info "Running official Docker installer (sudo password may be required)..."
                curl -fsSL https://get.docker.com | sudo sh
                sudo systemctl enable --now docker 2>/dev/null || sudo service docker start 2>/dev/null || true
                sudo usermod -aG docker "$USER" 2>/dev/null || true
            else
                log_error "Sudo or root privileges are required to install Docker on Linux."
                exit 1
            fi
            ;;
    esac
fi

# 5. Ensure Docker daemon is active
if ! docker info >/dev/null 2>&1; then
    log_info "Starting Docker daemon..."
    if [ "$DISTRO" = "macos" ]; then
        open -a Docker 2>/dev/null || true
    else
        if [ "$(id -u)" -eq 0 ]; then
            systemctl start docker 2>/dev/null || service docker start 2>/dev/null || true
        elif command -v sudo >/dev/null 2>&1; then
            sudo systemctl start docker || sudo service docker start || true
        fi
    fi

    for i in $(seq 1 20); do
        sleep 2
        if docker info >/dev/null 2>&1; then
            log_ok "Docker daemon is active and responsive."
            break
        fi
    done
fi

# 6. Prepare local files (prevent directory-mount bug)
if [ -d "$WORK_DIR/overbranch.db" ]; then
    rm -rf "$WORK_DIR/overbranch.db"
fi
if [ ! -f "$WORK_DIR/overbranch.db" ]; then
    touch "$WORK_DIR/overbranch.db"
fi
mkdir -p "$WORK_DIR/uploads"

# 7. Create global 'overbranch' CLI launcher in ~/.local/bin or /usr/local/bin
TARGET_BIN_DIR=""
if [ -d "$HOME/.local/bin" ] || mkdir -p "$HOME/.local/bin" 2>/dev/null; then
    TARGET_BIN_DIR="$HOME/.local/bin"
elif [ -w "/usr/local/bin" ]; then
    TARGET_BIN_DIR="/usr/local/bin"
fi

if [ -n "$TARGET_BIN_DIR" ]; then
    cat << EOF > "${TARGET_BIN_DIR}/overbranch"
#!/usr/bin/env bash
cd "${WORK_DIR}" && exec ./docker-up.sh "\$@"
EOF
    chmod +x "${TARGET_BIN_DIR}/overbranch"
    log_ok "Installed global CLI command: ${BOLD}overbranch${RESET} (in ${TARGET_BIN_DIR})"
fi

# 8. Start OverBranch via Docker Compose
chmod +x ./docker-up.sh
exec ./docker-up.sh "$@"
