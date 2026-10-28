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
import tempfile
import time
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


# ---------------------------------------------------------------------------
# LaTeX toolchain
# ---------------------------------------------------------------------------
# What a TeX install has to carry for OverBranch. The compiler refuses to
# auto-disable these (backend/compiler.py `_CRITICAL_PACKAGES`), because a
# Beamer deck compiled without beamer, or a figure without tikz, produces a
# corrupted PDF rather than a readable one. A TeX install missing them does not
# degrade — it fails the compile. So install a scheme that includes them up
# front rather than a bare engine.
#
# One command per package manager, deliberately not the smallest possible set:
# re-running an installer because a deck needed pgfplots is worse than the
# download.
LINUX_TEX_PACKAGES = {
    # Debian family: beamer lives in -recommended, tikz/pgf in -pictures.
    "apt": ["texlive-latex-base", "texlive-latex-recommended", "texlive-latex-extra",
            "texlive-pictures", "texlive-fonts-recommended", "texlive-science", "latexmk"],
    # Arch split TeX Live into these collections in 2023; latexmk is in -binextra.
    "pacman": ["texlive-basic", "texlive-latex", "texlive-latexrecommended",
               "texlive-latexextra", "texlive-pictures", "texlive-fontsrecommended",
               "texlive-mathscience", "texlive-binextra"],
    # scheme-medium already carries beamer, pgf/tikz and the AMS packages.
    "dnf": ["texlive-scheme-medium", "latexmk"],
    "yum": ["texlive-scheme-medium", "latexmk"],
    "zypper": ["texlive-scheme-medium", "texlive-latexmk"],
    "apk": ["texlive", "texmf-dist-latexextra", "texmf-dist-pictures",
            "texmf-dist-fontsrecommended", "texmf-dist-science"],
}

# Installed on top of macOS BasicTeX, which ships an engine and little else.
# Collections rather than ~40 individual package names: one tlmgr run, and a
# renamed upstream package cannot silently drop a template's requirement.
MACOS_TLMGR_COLLECTIONS = [
    "collection-latexrecommended",   # beamer, booktabs, caption …
    "collection-latexextra",         # tcolorbox, titlesec, fancyhdr, enumitem …
    "collection-pictures",           # pgf, tikz, pgfplots
    "collection-mathscience",        # amsmath, amssymb, mathtools, siunitx
    "collection-fontsrecommended",
    "latexmk",
]

# BasicTeX and MacTeX both symlink their binaries here.
MACOS_TEXBIN = "/Library/TeX/texbin"


def _is_root() -> bool:
    return hasattr(os, "geteuid") and os.geteuid() == 0


def _sudo_available_without_password() -> bool:
    """True when ``sudo`` runs without prompting (NOPASSWD or a live credential cache)."""
    if not shutil.which("sudo"):
        return False
    try:
        return subprocess.run(["sudo", "-n", "true"], check=False,
                              stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode == 0
    except Exception:
        return False


def _interactive() -> bool:
    """True when there is a terminal to ask a question on and read an answer from."""
    try:
        return sys.stdin.isatty() and sys.stdout.isatty()
    except Exception:
        return False


def _confirm(question: str) -> bool:
    if not _interactive():
        return False
    try:
        return (input(f"{CYAN}[INPUT]{RESET} {question} [Y/n] ").strip().lower() or "y") in ("y", "yes")
    except (EOFError, KeyboardInterrupt):
        print()
        return False


def _run_privileged(cmd: list, *, what: str) -> bool:
    """
    Runs ``cmd`` as root, without ever blocking on an invisible password prompt.

    A piped installer (``curl … | bash``) has no terminal, so a plain ``sudo``
    there waits for a password nobody can see or type and the install appears to
    hang. Root and a cached/NOPASSWD sudo run straight through; a terminal is
    asked first, since the password prompt is the user's to answer; and with
    neither, the exact command is printed and the installer carries on.
    """
    if _is_root():
        full = cmd
    elif _sudo_available_without_password():
        full = ["sudo", "-n", *cmd]
    elif _interactive() and shutil.which("sudo"):
        log_info(f"{what} needs administrator rights; sudo will ask for your password.")
        if not _confirm(f"Run: {' '.join(cmd)} ?"):
            log_warn("Skipped at your request.")
            return False
        full = ["sudo", *cmd]
    else:
        log_warn(f"{what} needs root and this installer cannot ask for a password here.")
        log_info(f"Run it yourself with:  sudo {' '.join(cmd)}")
        return False

    try:
        return subprocess.run(full, check=False).returncode == 0
    except Exception as exc:
        log_warn(f"{what} failed to run: {exc}")
        return False


def _detect_linux_package_manager() -> "tuple[str, list] | tuple[None, None]":
    """The first available package manager and the argv that installs with it unattended."""
    for name, argv in (
        ("apt", ["apt-get", "install", "-y"]),
        ("dnf", ["dnf", "install", "-y"]),
        ("pacman", ["pacman", "-S", "--needed", "--noconfirm"]),
        ("zypper", ["zypper", "--non-interactive", "install"]),
        ("apk", ["apk", "add", "--no-cache"]),
        ("yum", ["yum", "install", "-y"]),
    ):
        if shutil.which(argv[0]):
            return name, argv
    return None, None


def _install_latex_linux() -> bool:
    manager, install_argv = _detect_linux_package_manager()
    if not manager:
        log_warn("No supported package manager found (apt, dnf, pacman, zypper, apk, yum).")
        log_info("Install TeX Live with your system's package manager, or from https://tug.org/texlive/")
        return False

    packages = LINUX_TEX_PACKAGES[manager]
    log_info(f"Installing TeX Live via {manager} ({len(packages)} package(s)); this can take several minutes...")

    if manager == "apt":
        # Without a package index this is "Unable to locate package" on a fresh container.
        _run_privileged(["apt-get", "update"], what="Refreshing the apt package index")

    if not _run_privileged([*install_argv, *packages], what="Installing TeX Live"):
        log_warn("Automatic TeX Live installation did not complete.")
        return False
    return True


def _install_latex_macos() -> bool:
    if not shutil.which("brew"):
        log_warn("Homebrew was not found, and it is how TeX is installed on macOS.")
        log_info('Install it with:  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"')
        log_info("Then re-run this installer, or install TeX directly from https://tug.org/mactex/")
        return False

    # brew must not run under sudo; the cask's installer asks for the password
    # itself when it needs one, which only works with a terminal attached.
    if not (_interactive() or _is_root()):
        log_warn("Installing BasicTeX needs a terminal to confirm an administrator prompt.")
        log_info("Run it yourself with:  brew install --cask basictex")
        return False

    log_info("Installing BasicTeX via Homebrew (~100 MB)...")
    try:
        if subprocess.run(["brew", "install", "--cask", "basictex"], check=False).returncode != 0:
            log_warn("brew install --cask basictex did not succeed.")
            log_info("For a complete TeX instead, try:  brew install --cask mactex-no-gui")
            return False
    except Exception as exc:
        log_warn(f"Could not run Homebrew: {exc}")
        return False

    # BasicTeX's binaries are not on PATH until a new shell starts, and tlmgr is
    # needed right now, so put them in front for the rest of this process.
    if os.path.isdir(MACOS_TEXBIN):
        os.environ["PATH"] = f"{MACOS_TEXBIN}{os.pathsep}{os.environ.get('PATH', '')}"

    tlmgr = shutil.which("tlmgr") or os.path.join(MACOS_TEXBIN, "tlmgr")
    if not os.path.isfile(tlmgr):
        log_warn("BasicTeX installed but tlmgr was not found; skipping the extra packages.")
        return bool(shutil.which("pdflatex"))

    log_info("Adding the packages OverBranch needs (beamer, tikz/pgfplots, amsmath, ...)...")
    _run_privileged([tlmgr, "update", "--self"], what="Updating tlmgr")
    if not _run_privileged([tlmgr, "install", *MACOS_TLMGR_COLLECTIONS], what="Installing TeX packages"):
        log_warn("BasicTeX is installed, but the extra collections did not all install.")
        log_info(f"Finish with:  sudo tlmgr install {' '.join(MACOS_TLMGR_COLLECTIONS)}")
    else:
        log_info("For the fonts a few bundled templates use (EB Garamond, Roboto, Font Awesome), "
                 "add:  sudo tlmgr install collection-fontsextra")
    return True


def check_or_install_latex():
    """
    Ensures a LaTeX engine is present, installing one for the host OS if not:
    MiKTeX on Windows, TeX Live via the system package manager on Linux,
    BasicTeX via Homebrew on macOS.
    """
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

    # macOS / Linux. TeX being installed but not yet on PATH is the common case
    # right after installing it: BasicTeX symlinks into /Library/TeX/texbin and a
    # running shell has not picked that up, and upstream TeX Live installs to
    # /usr/local/texlive/<year>/bin/<arch>/. Look there before installing again.
    tex_dirs = [MACOS_TEXBIN]
    for base in ("/usr/local/texlive", "/opt/texlive"):
        tex_dirs += sorted((str(p.parent) for p in Path(base).glob("*/bin/*/pdflatex")), reverse=True)
    for tex_dir in tex_dirs:
        candidate = os.path.join(tex_dir, "pdflatex")
        if os.path.isfile(candidate):
            os.environ["PATH"] = f"{tex_dir}{os.pathsep}{os.environ.get('PATH', '')}"
            log_success(f"Found LaTeX compiler: {candidate}")
            return True

    log_warn("LaTeX engine (pdflatex / latexmk) not found on PATH.")
    if system == "darwin":
        installed = _install_latex_macos()
    elif system == "linux":
        installed = _install_latex_linux()
    else:
        log_info(f"Automatic TeX installation is not supported on {system or 'this platform'}.")
        log_info("Install TeX Live from https://tug.org/texlive/ to enable offline PDF builds.")
        return False

    compiler_bin = shutil.which("pdflatex") or shutil.which("latexmk")
    if compiler_bin:
        log_success(f"LaTeX compiler installed and ready: {compiler_bin}")
        return True

    if installed:
        # The packages landed but this process's PATH predates them.
        log_warn("TeX installed, but pdflatex is not on this shell's PATH yet.")
        log_info("Open a new terminal (or re-run this installer) and it will be picked up.")
    else:
        log_warn("OverBranch will run, but PDF compilation stays unavailable until TeX is installed.")
    return False


# ---------------------------------------------------------------------------
# Docker toolchain & Auto-Installer
# ---------------------------------------------------------------------------

def check_or_install_docker() -> bool:
    """Detects if Docker is installed. If missing, automatically installs Docker for the respective OS."""
    docker_bin = shutil.which("docker")
    if docker_bin:
        log_success(f"Docker is already installed: {docker_bin}")
        _ensure_docker_daemon_running()
        return True

    system = platform.system().lower()
    log_info(f"Docker is not detected on PATH. Installing Docker automatically for {platform.system()}...")

    if system == "windows":
        std_bin = Path("C:/Program Files/Docker/Docker/resources/bin/docker.exe")
        if std_bin.exists():
            os.environ["PATH"] = f"{std_bin.parent};{os.environ.get('PATH', '')}"
            log_success(f"Found Docker at: {std_bin}")
            _ensure_docker_daemon_running()
            return True

        winget = shutil.which("winget")
        if winget:
            log_info("Installing Docker Desktop via Windows Package Manager (winget)...")
            try:
                res = subprocess.run(
                    [winget, "install", "--id", "Docker.DockerDesktop", "-e", "--source", "winget",
                     "--accept-package-agreements", "--accept-source-agreements", "--silent"],
                    check=False
                )
                if res.returncode == 0 or std_bin.exists():
                    os.environ["PATH"] = f"{std_bin.parent};{os.environ.get('PATH', '')}"
                    log_success("Docker Desktop installed successfully via winget.")
                    _ensure_docker_daemon_running()
                    return True
            except Exception as e:
                log_warn(f"winget error: {e}")

        # Fallback to direct installer download
        log_info("Downloading official Docker Desktop installer...")
        installer = Path(tempfile.gettempdir()) / "DockerDesktopInstaller.exe"
        try:
            urllib.request.urlretrieve("https://desktop.docker.com/win/main/amd64/Docker%20Desktop%20Installer.exe", installer)
            log_info("Running silent Docker Desktop installer (this may take 2-3 minutes)...")
            subprocess.run([str(installer), "install", "--quiet", "--accept-license"], check=True)
            installer.unlink(missing_ok=True)
            if std_bin.exists():
                os.environ["PATH"] = f"{std_bin.parent};{os.environ.get('PATH', '')}"
                log_success("Docker Desktop installed successfully.")
                _ensure_docker_daemon_running()
                return True
        except Exception as e:
            log_error(f"Failed to install Docker Desktop on Windows: {e}")
            return False

    elif system == "darwin":
        brew = shutil.which("brew")
        if brew:
            log_info("Installing Docker Desktop via Homebrew Cask...")
            try:
                subprocess.run([brew, "install", "--cask", "docker"], check=True)
                log_success("Docker Desktop installed via Homebrew.")
                _ensure_docker_daemon_running()
                return True
            except Exception as e:
                log_warn(f"brew error: {e}")

        arch = "arm64" if platform.machine().lower() in ("arm64", "aarch64") else "amd64"
        dmg_path = Path("/tmp/Docker.dmg")
        try:
            log_info(f"Downloading Docker Desktop DMG ({arch})...")
            urllib.request.urlretrieve(f"https://desktop.docker.com/mac/main/{arch}/Docker.dmg", dmg_path)
            subprocess.run(["hdiutil", "attach", str(dmg_path), "-nobrowse", "-quiet"], check=True)
            subprocess.run(["cp", "-R", "/Volumes/Docker/Docker.app", "/Applications/"], check=True)
            subprocess.run(["hdiutil", "detach", "/Volumes/Docker", "-quiet"], check=False)
            dmg_path.unlink(missing_ok=True)
            log_success("Docker Desktop installed to /Applications/Docker.app")
            _ensure_docker_daemon_running()
            return True
        except Exception as e:
            log_error(f"Failed to install Docker on macOS: {e}")
            return False

    elif system == "linux":
        curl = shutil.which("curl") or shutil.which("wget")
        if curl:
            log_info("Installing Docker Engine via official get.docker.com script...")
            cmd = "curl -fsSL https://get.docker.com | sh" if shutil.which("curl") else "wget -qO- https://get.docker.com | sh"
            if not _is_root() and shutil.which("sudo"):
                cmd = "curl -fsSL https://get.docker.com | sudo sh" if shutil.which("curl") else "wget -qO- https://get.docker.com | sudo sh"
            try:
                subprocess.run(cmd, shell=True, check=True)
                log_success("Docker Engine installed successfully.")
                _ensure_docker_daemon_running()
                return True
            except Exception as e:
                log_warn(f"get.docker.com error: {e}")

        for mgr, update, install in [
            ("apt-get", ["apt-get", "update"], ["apt-get", "install", "-y", "docker.io", "docker-compose-plugin"]),
            ("pacman", [], ["pacman", "-Sy", "--noconfirm", "docker", "docker-compose"]),
            ("dnf", [], ["dnf", "install", "-y", "docker-ce", "docker-compose-plugin"]),
            ("apk", [], ["apk", "add", "--no-cache", "docker", "docker-cli-compose"]),
        ]:
            if shutil.which(mgr):
                log_info(f"Installing Docker using {mgr}...")
                prefix = [] if _is_root() or not shutil.which("sudo") else ["sudo"]
                try:
                    if update:
                        subprocess.run(prefix + update, check=False)
                    subprocess.run(prefix + install, check=True)
                    log_success(f"Docker installed via {mgr}.")
                    _ensure_docker_daemon_running()
                    return True
                except Exception as e:
                    log_warn(f"{mgr} error: {e}")

    return bool(shutil.which("docker"))


def _ensure_docker_daemon_running():
    """Starts the Docker daemon if not currently active."""
    system = platform.system().lower()
    try:
        res = subprocess.run(["docker", "info"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=False)
        if res.returncode == 0:
            return True
    except Exception:
        pass

    log_info("Starting Docker service daemon...")
    if system == "windows":
        app = Path("C:/Program Files/Docker/Docker/Docker Desktop.exe")
        if app.exists():
            subprocess.Popen([str(app)], shell=True)
    elif system == "darwin":
        subprocess.run(["open", "-a", "Docker"], check=False)
    elif system == "linux":
        prefix = [] if _is_root() or not shutil.which("sudo") else ["sudo"]
        subprocess.run(prefix + ["systemctl", "start", "docker"], check=False)

    for _ in range(15):
        time.sleep(2)
        try:
            if subprocess.run(["docker", "info"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=False).returncode == 0:
                log_success("Docker daemon is active and responsive.")
                return True
        except Exception:
            pass
    return False


def main():
    import argparse
    parser = argparse.ArgumentParser(description="OverBranch Self-Host Installer")
    parser.add_argument("--docker", action="store_true", help="Install Docker for host OS and setup Docker stack")
    args, _ = parser.parse_known_args()

    print(f"""{BOLD}{GREEN}
============================================================
       OverBranch Self-Host Installation & Setup
       100% Local TeX Editor • Local Gemini Web2API • SQLite
============================================================{RESET}
""")
    if args.docker:
        check_or_install_docker()
        print(f"""
{BOLD}{GREEN}============================================================
   Docker Environment Installed & Ready!
============================================================{RESET}

{BOLD}{CYAN}>>> Access overbranch through localhost:3000 <<<{RESET}

To start OverBranch via Docker Compose:
  {BOLD}docker compose up -d{RESET}
  or double-click:
  {BOLD}docker-up.bat{RESET} (Windows) / {BOLD}./docker-up.sh{RESET} (Linux/macOS)
""")
        return

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

{BOLD}{CYAN}>>> Access overbranch through localhost:3000 <<<{RESET}

To run the entire app (Frontend + Backend + Gemini Web2API):

  {BOLD}python run.py{RESET}
  or:
  {BOLD}./run.sh{RESET}   (Linux / macOS)
  {BOLD}run.bat{RESET}    (Windows)

Or run with Docker Compose (1-Click, Zero Configuration):
  {BOLD}docker compose up -d{RESET}
  (or use: {BOLD}docker-up.bat{RESET} / {BOLD}./docker-up.sh{RESET})

Access points once running:
  • Web Editor Workspace:  {CYAN}http://localhost:3000{RESET}
  • TeX Engine API:        {CYAN}http://localhost:8000{RESET}
  • Gemini Web2API Proxy:  {CYAN}http://localhost:8081{RESET}
""")

if __name__ == "__main__":
    main()
