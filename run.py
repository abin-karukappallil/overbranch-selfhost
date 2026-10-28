#!/usr/bin/env python3
"""
run.py — Universal Cross-Platform Single Runner for OverBranch Self-Host (Docker Compose)
========================================================================================
Runs OverBranch inside Docker using docker-compose.yml across all operating systems:
  - Windows: 10 / 11 / Server
  - macOS: Intel & Apple Silicon
  - Linux: Ubuntu, Debian, Arch Linux, Fedora, CentOS, etc.

Usage:
  python run.py              (starts containers in background and opens browser)
  python run.py stop         (stops containers)
  python run.py down         (stops and removes containers)
  python run.py logs         (tails live container logs)
  python run.py restart      (restarts containers)
  python run.py status       (checks container status)
  python run.py build        (rebuilds Docker image and starts)
  python run.py --bare-metal (runs legacy bare-metal processes on host OS)
"""

import os
import sys
import time
import shutil
import platform
import subprocess
import webbrowser
from pathlib import Path

ROOT_DIR = Path(__file__).resolve().parent

# ANSI Colors
CYAN = "\033[96m"
GREEN = "\033[92m"
YELLOW = "\033[93m"
RED = "\033[91m"
BOLD = "\033[1m"
RESET = "\033[0m"

def log_runner(msg: str):
    print(f"{BOLD}{GREEN}[OverBranch]{RESET} {msg}")

def log_warn(msg: str):
    print(f"{BOLD}{YELLOW}[OverBranch WARN]{RESET} {msg}")

def log_error(msg: str):
    print(f"{BOLD}{RED}[OverBranch ERROR]{RESET} {msg}")


def get_compose_command():
    """Returns the available Docker Compose command array."""
    try:
        res = subprocess.run(["docker", "compose", "version"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=False)
        if res.returncode == 0:
            return ["docker", "compose"]
    except Exception:
        pass

    if shutil.which("docker-compose"):
        return ["docker-compose"]

    return None


def ensure_docker_daemon_running():
    """Verifies that the Docker daemon is responsive, attempting to start it if inactive."""
    system = platform.system().lower()

    try:
        res = subprocess.run(["docker", "info"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=False)
        if res.returncode == 0:
            return True
    except Exception:
        pass

    log_runner("Docker daemon is inactive. Starting Docker service...")
    if system == "windows":
        app = Path("C:/Program Files/Docker/Docker/Docker Desktop.exe")
        if app.exists():
            subprocess.Popen([str(app)], shell=True)
        else:
            log_warn("Could not find Docker Desktop.exe. Please launch Docker Desktop manually.")
    elif system == "darwin":
        subprocess.run(["open", "-a", "Docker"], check=False)
    elif system == "linux":
        if os.geteuid() == 0:
            subprocess.run(["systemctl", "start", "docker"], check=False)
        elif shutil.which("sudo"):
            log_runner("Starting Docker service (sudo password may be required)...")
            subprocess.run(["sudo", "systemctl", "start", "docker"], check=False)

    for i in range(20):
        time.sleep(2)
        try:
            if subprocess.run(["docker", "info"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=False).returncode == 0:
                log_runner("Docker daemon is active and responsive.")
                return True
        except Exception:
            pass

    return False


def prepare_local_files():
    """Ensures database file and uploads directory exist to avoid Docker directory-mount bug."""
    db_file = ROOT_DIR / "overbranch.db"
    if db_file.is_dir():
        log_warn("Detected 'overbranch.db' as a directory. Correcting to SQLite database file...")
        shutil.rmtree(db_file)
    if not db_file.exists():
        db_file.touch()

    uploads_dir = ROOT_DIR / "uploads"
    uploads_dir.mkdir(parents=True, exist_ok=True)


def run_docker_compose(args):
    """Executes Docker Compose with the requested arguments."""
    compose_cmd = get_compose_command()

    # If Docker Compose is missing or Docker is not installed, delegate to shell/bat launcher
    if not shutil.which("docker") or not compose_cmd:
        system = platform.system().lower()
        log_warn("Docker or Docker Compose not found in PATH.")
        if system == "windows":
            bat = ROOT_DIR / "docker-up.bat"
            if bat.exists():
                log_runner("Handing over to Windows Docker installer (docker-up.bat)...")
                sys.exit(subprocess.call([str(bat)] + args))
        else:
            sh = ROOT_DIR / "docker-up.sh"
            if sh.exists():
                sh.chmod(0o755)
                log_runner("Handing over to Linux/macOS Docker installer (docker-up.sh)...")
                sys.exit(subprocess.call([str(sh)] + args))

        log_error("Docker is required to run OverBranch Self-Host.")
        log_error("Please install Docker: https://docs.docker.com/get-docker/")
        sys.exit(1)

    # Subcommands
    action = args[0] if args else "up"
    if action in ("down", "stop"):
        log_runner("Stopping OverBranch containers...")
        sys.exit(subprocess.call(compose_cmd + ["down"]))
    elif action == "logs":
        sys.exit(subprocess.call(compose_cmd + ["logs", "-f"] + args[1:]))
    elif action in ("ps", "status"):
        sys.exit(subprocess.call(compose_cmd + ["ps"]))
    elif action == "restart":
        log_runner("Restarting OverBranch containers...")
        sys.exit(subprocess.call(compose_cmd + ["restart"]))

    # Spin up daemon if inactive
    if not ensure_docker_daemon_running():
        log_error("Could not connect to Docker daemon. Please start Docker and try again.")
        sys.exit(1)

    prepare_local_files()

    if action == "build" or "--build" in args:
        cmd = compose_cmd + ["up", "--build", "-d"]
    else:
        cmd = compose_cmd + ["up", "-d"]

    log_runner(f"Starting OverBranch via Docker Compose ({' '.join(cmd)})...")
    res = subprocess.call(cmd, cwd=str(ROOT_DIR))
    if res != 0:
        log_error("Docker Compose failed to start container.")
        sys.exit(res)

    print(f"""
{BOLD}{GREEN}============================================================
       OverBranch Self-Host is running successfully!
============================================================{RESET}

  {BOLD}{CYAN}Access overbranch through localhost:3000{RESET}

  • Web Editor Workspace:  {CYAN}http://localhost:3000{RESET}
  • TeX Engine API:        {CYAN}http://localhost:8000{RESET}
  • Gemini Web2API Proxy:  {CYAN}http://localhost:8081{RESET}
{BOLD}{GREEN}============================================================{RESET}

  Management commands:
    python run.py stop     - Stop containers
    python run.py logs     - View live container logs
    python run.py restart  - Restart services
{BOLD}{GREEN}============================================================{RESET}
""")

    # Open browser
    try:
        webbrowser.open("http://localhost:3000")
    except Exception:
        pass


def run_bare_metal_legacy(args):
    """Legacy bare-metal launcher for developers who specifically pass --bare-metal."""
    log_runner("Running in legacy bare-metal mode on host OS...")
    python_bin = sys.executable
    processes = []

    def cleanup():
        for p in processes:
            try:
                p.terminate()
            except Exception:
                pass

    try:
        # 1. Gemini Web2API
        web2api = ROOT_DIR / "bin" / ("gemini-web2api.exe" if platform.system().lower() == "windows" else "gemini-web2api")
        if web2api.exists():
            cfg_flag = ["-config", str(ROOT_DIR / "bin" / "config.json")] if (ROOT_DIR / "bin" / "config.json").exists() else []
            p_web2 = subprocess.Popen([str(web2api), "-port", "8081"] + cfg_flag)
            processes.append(p_web2)

        # 2. FastAPI backend
        backend_dir = ROOT_DIR / "backend"
        p_back = subprocess.Popen([python_bin, "-m", "uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"], cwd=str(backend_dir))
        processes.append(p_back)

        # 3. Next.js frontend
        node_pkg = "bun" if shutil.which("bun") else "npm"
        p_front = subprocess.Popen([node_pkg, "run", "start"], cwd=str(ROOT_DIR))
        processes.append(p_front)

        p_front.wait()
    except KeyboardInterrupt:
        log_runner("Shutting down bare-metal processes...")
    finally:
        cleanup()


def main():
    args = sys.argv[1:]
    if "--bare-metal" in args:
        args.remove("--bare-metal")
        run_bare_metal_legacy(args)
    else:
        run_docker_compose(args)


if __name__ == "__main__":
    main()
