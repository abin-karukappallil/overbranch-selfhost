#!/usr/bin/env python3
"""
install.py — Universal Cross-Platform Installer for OverBranch Self-Host
========================================================================
Compatible with:
  - Linux: Ubuntu, Debian, Arch Linux, CentOS, RHEL, Fedora, Alpine, openSUSE, etc.
  - macOS: Intel (x86_64) & Apple Silicon (ARM64 M1/M2/M3/M4)
  - Windows: 10 / 11 / Server (x86_64 & ARM64)

Automates:
  1. Downloading & installing the standalone Gemini Web2API Go binary
  2. Setting up Python virtual environment & backend dependencies
  3. Installing frontend Node.js / Bun dependencies
  4. Initializing the local SQLite database & vector search index
"""

import os
import sys
import shutil
import tarfile
import zipfile
import platform
import subprocess
import urllib.request
from pathlib import Path

ROOT_DIR = Path(__file__).resolve().parent
BIN_DIR = ROOT_DIR / "bin"
BACKEND_DIR = ROOT_DIR / "backend"

WEB2API_VERSION = "v1.2.0"
WEB2API_REPO = "ikhsan3adi/gemini-web2api"

# ANSI Colors
CYAN = "\033[96m"
GREEN = "\033[92m"
YELLOW = "\033[93m"
RED = "\033[91m"
BOLD = "\033[1m"
RESET = "\033[0m"

def log_info(msg: str):
    print(f"{CYAN}[INFO]{RESET} {msg}")

def log_success(msg: str):
    print(f"{GREEN}[SUCCESS]{RESET} {msg}")

def log_warn(msg: str):
    print(f"{YELLOW}[WARN]{RESET} {msg}")

def log_error(msg: str):
    print(f"{RED}[ERROR]{RESET} {msg}")


def detect_platform_and_arch():
    """Detects operating system and architecture for binary download."""
    system = platform.system().lower()
    machine = platform.machine().lower()

    os_name = ""
    if "linux" in system:
        os_name = "linux"
    elif "darwin" in system:
        os_name = "darwin"
    elif "windows" in system:
        os_name = "windows"
    else:
        os_name = "linux"

    arch_name = ""
    if machine in ("x86_64", "amd64", "x64"):
        arch_name = "amd64"
    elif machine in ("arm64", "aarch64", "armv8b", "armv8l"):
        arch_name = "arm64"
    else:
        arch_name = "amd64"

    return os_name, arch_name


def download_gemini_web2api():
    """Downloads precompiled gemini-web2api binary for the target OS & Arch."""
    BIN_DIR.mkdir(parents=True, exist_ok=True)
    os_name, arch_name = detect_platform_and_arch()
    
    binary_name = "gemini-web2api.exe" if os_name == "windows" else "gemini-web2api"
    target_binary = BIN_DIR / binary_name
    
    if target_binary.exists() and target_binary.stat().st_size > 1000:
        log_info(f"Gemini Web2API binary already exists at: {target_binary}")
        if os_name != "windows":
            target_binary.chmod(0o755)
        return True

    ext = "zip" if os_name == "windows" else "tar.gz"
    asset_filename = f"gemini-web2api_{WEB2API_VERSION.lstrip('v')}_{os_name}_{arch_name}.{ext}"
    download_url = f"https://github.com/{WEB2API_REPO}/releases/download/{WEB2API_VERSION}/{asset_filename}"

    log_info(f"Detected Platform: {os_name}/{arch_name}")
    log_info(f"Downloading Gemini Web2API from: {download_url}")

    archive_path = BIN_DIR / asset_filename
    try:
        req = urllib.request.Request(
            download_url,
            headers={"User-Agent": "Mozilla/5.0 OverBranch-SelfHost-Installer"}
        )
        with urllib.request.urlopen(req, timeout=60) as resp, open(archive_path, "wb") as out:
            shutil.copyfileobj(resp, out)
        log_success(f"Downloaded {asset_filename}")

        # Extract binary
        if ext == "zip":
            with zipfile.ZipFile(archive_path, "r") as zf:
                zf.extractall(BIN_DIR)
        else:
            with tarfile.open(archive_path, "r:gz") as tf:
                tf.extractall(BIN_DIR)

        archive_path.unlink(missing_ok=True)

        if target_binary.exists():
            if os_name != "windows":
                target_binary.chmod(0o755)
            log_success(f"Gemini Web2API installed to: {target_binary}")
            return True
        else:
            # Check if extracted inside subdirectory
            extracted = list(BIN_DIR.glob(f"*{binary_name}*"))
            if extracted and extracted[0].is_file():
                shutil.move(str(extracted[0]), str(target_binary))
                if os_name != "windows":
                    target_binary.chmod(0o755)
                log_success(f"Gemini Web2API installed to: {target_binary}")
                return True
    except Exception as e:
        log_warn(f"Binary download failed: {e}")

    # Fallback: check if Go is installed and build from source
    go_bin = shutil.which("go")
    if go_bin:
        log_info("Go compiler found! Attempting to build gemini-web2api via 'go install'...")
        try:
            cmd = [go_bin, "install", f"github.com/{WEB2API_REPO}@latest"]
            subprocess.run(cmd, check=True)
            # Find built binary in GOPATH/bin
            gopath = os.getenv("GOPATH") or str(Path.home() / "go")
            built_path = Path(gopath) / "bin" / binary_name
            if built_path.exists():
                shutil.copy2(built_path, target_binary)
                if os_name != "windows":
                    target_binary.chmod(0o755)
                log_success(f"Successfully built and installed Gemini Web2API: {target_binary}")
                return True
        except Exception as go_err:
            log_warn(f"Go build failed: {go_err}")

    log_warn("Could not download or build gemini-web2api automatically.")
    log_info(f"You can manually place '{binary_name}' in: {BIN_DIR}")
    return False


def setup_python_environment():
    """Sets up Python venv in backend/.venv and installs backend dependencies."""
    log_info("Setting up Python virtual environment...")
    venv_dir = BACKEND_DIR / ".venv"

    # Find python3 or python
    python_cmd = sys.executable

    # Check if uv is available for 10x faster installation
    uv_cmd = shutil.which("uv")

    if not venv_dir.exists():
        if uv_cmd:
            log_info("Using uv to create virtual environment...")
            subprocess.run([uv_cmd, "venv", str(venv_dir)], check=True)
        else:
            log_info("Creating virtual environment with python -m venv...")
            subprocess.run([python_cmd, "-m", "venv", str(venv_dir)], check=True)

    # Determine pip and python binaries in venv
    if platform.system().lower() == "windows":
        venv_python = venv_dir / "Scripts" / "python.exe"
        venv_pip = venv_dir / "Scripts" / "pip.exe"
    else:
        venv_python = venv_dir / "bin" / "python"
        venv_pip = venv_dir / "bin" / "pip"

    req_file = BACKEND_DIR / "requirements.txt"
    if req_file.exists():
        log_info(f"Installing backend dependencies from {req_file.name}...")
        if uv_cmd:
            subprocess.run([uv_cmd, "pip", "install", "-r", str(req_file), "--python", str(venv_python)], check=True)
        else:
            subprocess.run([str(venv_python), "-m", "pip", "install", "--upgrade", "pip"], check=False)
            subprocess.run([str(venv_python), "-m", "pip", "install", "-r", str(req_file)], check=True)

    log_success("Python backend environment ready.")
    return str(venv_python)


def setup_frontend_dependencies():
    """Installs Next.js dependencies using bun or npm."""
    log_info("Setting up frontend dependencies...")
    bun_cmd = shutil.which("bun")
    npm_cmd = shutil.which("npm")
    is_win = platform.system().lower() == "windows"

    if bun_cmd:
        log_info("Using Bun package manager...")
        subprocess.run([bun_cmd, "install"], cwd=str(ROOT_DIR), check=True, shell=is_win)
    elif npm_cmd:
        log_info("Using npm package manager...")
        subprocess.run([npm_cmd, "install"], cwd=str(ROOT_DIR), check=True, shell=is_win)
    else:
        log_error("Neither bun nor npm was found. Please install Node.js (v18+) or Bun (v1+).")
        return False

    log_success("Frontend dependencies installed.")
    return True


def build_frontend():
    """Builds optimized production Next.js bundle for fast startup."""
    log_info("Compiling production frontend bundle (next build)...")
    bun_cmd = shutil.which("bun")
    npm_cmd = shutil.which("npm")
    is_win = platform.system().lower() == "windows"
    cmd = [bun_cmd or npm_cmd, "run", "build"]
    subprocess.run(cmd, cwd=str(ROOT_DIR), check=True, shell=is_win)
    log_success("Frontend compiled successfully.")


def initialize_sqlite_database(python_bin: str):
    """Initializes local SQLite tables and seeds templates."""
    log_info("Initializing local SQLite database (overbranch.db)...")
    init_script = (
        "import sys; sys.path.insert(0, 'backend'); "
        "from database import init_sqlite_schema; init_sqlite_schema(); "
        "print('SQLite Database initialized successfully.')"
    )
    subprocess.run([python_bin, "-c", init_script], cwd=str(ROOT_DIR), check=True)
    log_success("Local SQLite database initialized.")


def check_or_install_latex():
    """Checks for LaTeX engine (pdflatex/latexmk) and installs MiKTeX automatically on Windows if missing."""
    log_info("Checking for LaTeX engine (pdflatex / latexmk)...")

    # 1. First check if pdflatex or latexmk is already available
    compiler_bin = shutil.which("pdflatex") or shutil.which("latexmk")
    if compiler_bin:
        log_success(f"Found LaTeX compiler: {compiler_bin}")
        return True

    # 2. On Windows, check common MiKTeX and TeX Live paths before attempting installation
    system = platform.system().lower()
    if system == "windows":
        home = os.path.expanduser("~")
        local_app_data = os.getenv("LOCALAPPDATA") or os.path.join(home, "AppData", "Local")
        prog_files = os.getenv("ProgramFiles") or r"C:\Program Files"
        prog_files_x86 = os.getenv("ProgramFiles(x86)") or r"C:\Program Files (x86)"

        candidate_dirs = [
            os.path.join(local_app_data, r"Programs\MiKTeX\miktex\bin\x64"),
            os.path.join(local_app_data, r"Programs\MiKTeX\miktex\bin"),
            os.path.join(prog_files, r"MiKTeX\miktex\bin\x64"),
            os.path.join(prog_files_x86, r"MiKTeX\miktex\bin\x64"),
            os.path.join(prog_files, r"MiKTeX\miktex\bin"),
            r"C:\texlive\2026\bin\windows",
            r"C:\texlive\2025\bin\windows",
            r"C:\texlive\2024\bin\windows",
            r"C:\texlive\2023\bin\windows",
        ]

        # Check Windows registry for custom installation
        try:
            import winreg
            for root in (winreg.HKEY_CURRENT_USER, winreg.HKEY_LOCAL_MACHINE):
                for subkey in (
                    r"Software\MiKTeX.org\MiKTeX\CurrentVersion\Setup",
                    r"Software\MiKTeX.org\MiKTeX\CurrentVersion\Core",
                ):
                    try:
                        with winreg.OpenKey(root, subkey) as key:
                            val, _ = winreg.QueryValueEx(key, "Install")
                            if val:
                                for sub in (os.path.join(val, "miktex", "bin", "x64"), os.path.join(val, "miktex", "bin")):
                                    if sub not in candidate_dirs:
                                        candidate_dirs.insert(0, sub)
                    except Exception:
                        pass
        except Exception:
            pass

        for c_dir in candidate_dirs:
            if os.path.isfile(os.path.join(c_dir, "pdflatex.exe")):
                os.environ["PATH"] = f"{c_dir}{os.path.pathsep}{os.environ.get('PATH', '')}"
                log_success(f"Found MiKTeX compiler at: {c_dir}")
                return True

        # Not found on Windows: trigger automated MiKTeX installation
        log_warn("LaTeX compiler (pdflatex / MiKTeX) not detected on Windows.")
        log_info("Installing MiKTeX automatically (enables offline LaTeX compilation & Beamer presentations)...")

        installed = False

        # Attempt A: winget
        winget_bin = shutil.which("winget")
        if winget_bin:
            log_info("Installing MiKTeX via Windows Package Manager (winget)...")
            try:
                winget_cmd = [
                    winget_bin, "install",
                    "--id", "MiKTeX.MiKTeX",
                    "-e",
                    "--source", "winget",
                    "--accept-package-agreements",
                    "--accept-source-agreements",
                    "--silent",
                    "--scope", "user",
                    "--custom", "--unattended --private"
                ]
                proc = subprocess.run(winget_cmd, timeout=400)
                if proc.returncode == 0:
                    installed = True
            except Exception as e:
                log_warn(f"winget installation encountered an issue: {e}")

        # Attempt B: Direct standalone setup utility download (miktexsetup_standalone.exe)
        if not installed:
            import tempfile
            temp_dir = Path(tempfile.gettempdir())
            zip_dest = temp_dir / "miktexsetup-x64.zip"
            setup_dir = temp_dir / "miktexsetup_unpacked"
            setup_url = "https://miktex.org/download/win/miktexsetup-x64.zip"

            log_info(f"Downloading official MiKTeX setup utility from {setup_url}...")
            try:
                req = urllib.request.Request(
                    setup_url,
                    headers={"User-Agent": "Mozilla/5.0 OverBranch-SelfHost-Installer"}
                )
                with urllib.request.urlopen(req, timeout=120) as resp, open(zip_dest, "wb") as out:
                    shutil.copyfileobj(resp, out)

                shutil.rmtree(setup_dir, ignore_errors=True)
                with zipfile.ZipFile(zip_dest, "r") as zf:
                    zf.extractall(setup_dir)

                # Locate miktexsetup_standalone.exe or miktexsetup.exe
                setup_exe = next(setup_dir.glob("*miktexsetup*.exe"), None)
                if setup_exe and setup_exe.is_file():
                    log_info("Running silent MiKTeX unattended installation (this may take 2-4 minutes)...")
                    subprocess.run(
                        [str(setup_exe), "--quiet", "--package-set=basic", "install"],
                        check=True,
                        timeout=480
                    )
                    installed = True
            except Exception as zip_err:
                log_warn(f"Standalone MiKTeX setup failed: {zip_err}")
                # Fallback to basic-miktex-x64.exe installer
                log_info("Attempting basic-miktex-x64.exe fallback...")
                basic_dest = temp_dir / "basic-miktex-installer.exe"
                try:
                    req = urllib.request.Request(
                        "https://miktex.org/download/win/basic-miktex-x64.exe",
                        headers={"User-Agent": "Mozilla/5.0 OverBranch-SelfHost-Installer"}
                    )
                    with urllib.request.urlopen(req, timeout=120) as resp, open(basic_dest, "wb") as out:
                        shutil.copyfileobj(resp, out)
                    subprocess.run(
                        [str(basic_dest), "--unattended", "--auto-install=yes"],
                        check=True,
                        timeout=480
                    )
                    installed = True
                except Exception as dl_err:
                    log_warn(f"Direct MiKTeX installation fallback failed: {dl_err}")
                finally:
                    basic_dest.unlink(missing_ok=True)
            finally:
                zip_dest.unlink(missing_ok=True)
                shutil.rmtree(setup_dir, ignore_errors=True)

        # After installation, locate the newly installed binary and add to PATH
        for c_dir in candidate_dirs:
            if os.path.isfile(os.path.join(c_dir, "pdflatex.exe")):
                os.environ["PATH"] = f"{c_dir}{os.path.pathsep}{os.environ.get('PATH', '')}"

                # Persist to Windows User PATH environment
                try:
                    subprocess.run(
                        ["powershell", "-NoProfile", "-Command",
                         f"$p = [Environment]::GetEnvironmentVariable('Path', 'User'); if ($p -notlike '*{c_dir}*') {{ [Environment]::SetEnvironmentVariable('Path', '{c_dir};' + $p, 'User') }}"],
                        check=False, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL
                    )
                except Exception:
                    pass

                # Configure auto-install of missing packages on-the-fly without prompts
                initexmf_bin = os.path.join(c_dir, "initexmf.exe")
                if os.path.isfile(initexmf_bin):
                    subprocess.run([initexmf_bin, "--set-config-value=[MPM]AutoInstall=1"], check=False, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

                log_success(f"MiKTeX installed and configured successfully at: {c_dir}")
                return True

        log_warn("MiKTeX installer finished but pdflatex was not found immediately.")
        log_info("You can also install manually from: https://miktex.org/download")
        return False
    else:
        # Non-Windows systems: log advice
        log_warn("LaTeX engine (pdflatex / latexmk) not found on PATH.")
        log_info("Install TeX Live for your system:")
        log_info("  • Ubuntu/Debian: sudo apt install -y texlive-latex-base texlive-latex-extra latexmk")
        log_info("  • Arch Linux:    sudo pacman -S --noconfirm texlive-basic texlive-latexextra")
        log_info("  • macOS:         brew install --cask mactex-no-gui")
        return False


def main():
    print(f"""{BOLD}{GREEN}
============================================================
       OverBranch Self-Host Installation & Setup
       100% Local TeX Editor • Local Gemini Web2API • SQLite
============================================================{RESET}
""")
    # 1. Download Gemini Web2API binary
    download_gemini_web2api()

    # 2. Setup Python environment
    python_bin = setup_python_environment()

    # 3. Setup Frontend dependencies & compile production build
    setup_frontend_dependencies()
    build_frontend()

    # 4. Initialize SQLite database
    initialize_sqlite_database(python_bin)

    # 5. Check and install LaTeX compiler (MiKTeX on Windows)
    check_or_install_latex()

    print(f"""
{BOLD}{GREEN}============================================================
   OverBranch Self-Host Installation Complete!
============================================================{RESET}

To run the entire app (Frontend + Backend + Gemini Web2API):

  {BOLD}python run.py{RESET}
  or:
  {BOLD}./run.sh{RESET}   (Linux / macOS)
  {BOLD}run.bat{RESET}    (Windows)

Access points once running:
  • Web Editor:   {CYAN}http://localhost:3000{RESET}
  • TeX Backend:  {CYAN}http://localhost:8000{RESET}
  • Gemini Proxy: {CYAN}http://localhost:8081{RESET}
""")

if __name__ == "__main__":
    main()
