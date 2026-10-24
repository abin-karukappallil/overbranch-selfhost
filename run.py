#!/usr/bin/env python3
"""
run.py — Universal Cross-Platform Single Runner for OverBranch Self-Host
========================================================================
Runs the whole stack in a single command on Windows, macOS, and Linux:
  1. Gemini Web2API local Go proxy  (port 8081)
  2. FastAPI Python LaTeX engine     (port 8000)
  3. Next.js App Router frontend     (port 3000)

Features:
  - Automatic graceful shutdown on Ctrl+C (SIGINT / SIGTERM)
  - Color-coded prefix logs for all 3 services
  - Self-healing checks (auto-triggers install.py if dependencies missing)
"""

import os
import sys
import time
import signal
import shutil
import platform
import subprocess
import threading
from pathlib import Path

ROOT_DIR = Path(__file__).resolve().parent
BIN_DIR = ROOT_DIR / "bin"
BACKEND_DIR = ROOT_DIR / "backend"

# ANSI Colors
CYAN = "\033[96m"
GREEN = "\033[92m"
YELLOW = "\033[93m"
RED = "\033[91m"
MAGENTA = "\033[95m"
BLUE = "\033[94m"
BOLD = "\033[1m"
RESET = "\033[0m"

processes = []
is_shutting_down = False


def log_runner(msg: str):
    print(f"{BOLD}{GREEN}[OverBranch]{RESET} {msg}")

def log_error(msg: str):
    print(f"{BOLD}{RED}[OverBranch ERROR]{RESET} {msg}")


def get_backend_python() -> Path:
    """Finds Python executable in backend venv or falls back to system Python."""
    if platform.system().lower() == "windows":
        venv_py = BACKEND_DIR / ".venv" / "Scripts" / "python.exe"
    else:
        venv_py = BACKEND_DIR / ".venv" / "bin" / "python"
    
    if venv_py.exists():
        return venv_py
    return Path(sys.executable)


def get_web2api_binary() -> Optional[Path]:
    """Finds gemini-web2api binary."""
    binary_name = "gemini-web2api.exe" if platform.system().lower() == "windows" else "gemini-web2api"
    p = BIN_DIR / binary_name
    if p.exists():
        if platform.system().lower() != "windows":
            p.chmod(0o755)
        return p
    return None


def get_frontend_cmd() -> list[str]:
    """Selects package manager command for Next.js frontend."""
    if shutil.which("bun"):
        return ["bun", "run", "dev"]
    elif shutil.which("npm"):
        return ["npm", "run", "dev"]
    elif shutil.which("pnpm"):
        return ["pnpm", "dev"]
    elif shutil.which("yarn"):
        return ["yarn", "dev"]
    return ["npm", "run", "dev"]


def stream_logs(pipe, prefix: str, color: str):
    """Streams child process stdout/stderr with colorized service prefixes."""
    try:
        for line in iter(pipe.readline, ""):
            if not line:
                break
            stripped = line.rstrip("\r\n")
            if stripped:
                print(f"{color}{prefix}{RESET} {stripped}")
    except Exception:
        pass


def start_service(name: str, cmd: list[str], cwd: Path, color: str) -> subprocess.Popen:
    """Starts a subprocess with piped outputs and cross-platform process isolation."""
    log_runner(f"Starting {name} ({' '.join(cmd)})...")
    
    # Process group handling for clean termination
    kwargs = {
        "stdout": subprocess.PIPE,
        "stderr": subprocess.STDOUT,
        "text": True,
        "bufsize": 1,
        "cwd": str(cwd),
    }

    if platform.system().lower() == "windows":
        kwargs["creationflags"] = subprocess.CREATE_NEW_PROCESS_GROUP
    else:
        kwargs["preexec_fn"] = os.setsid

    proc = subprocess.Popen(cmd, **kwargs)
    processes.append(proc)

    # Background thread to stream logs
    t = threading.Thread(target=stream_logs, args=(proc.stdout, f"[{name}]", color), daemon=True)
    t.start()
    return proc


def shutdown_all(signum=None, frame=None):
    """Gracefully shuts down all spawned background services."""
    global is_shutting_down
    if is_shutting_down:
        return
    is_shutting_down = True
    print("\n")
    log_runner("Shutting down all OverBranch services gracefully...")

    for p in processes:
        if p.poll() is None:
            try:
                if platform.system().lower() == "windows":
                    p.terminate()
                else:
                    os.killpg(os.getpgid(p.pid), signal.SIGTERM)
            except Exception:
                pass

    time.sleep(1)

    for p in processes:
        if p.poll() is None:
            try:
                if platform.system().lower() == "windows":
                    subprocess.run(["taskkill", "/F", "/T", "/PID", str(p.pid)], check=False, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
                else:
                    os.killpg(os.getpgid(p.pid), signal.SIGKILL)
            except Exception:
                pass

    log_runner("All OverBranch services stopped. Goodbye!")
    sys.exit(0)


def main():
    signal.signal(signal.SIGINT, shutdown_all)
    signal.signal(signal.SIGTERM, shutdown_all)

    # Ensure dependencies installed
    web2api_bin = get_web2api_binary()
    python_bin = get_backend_python()

    if not web2api_bin:
        log_runner("Gemini Web2API binary missing. Running install.py...")
        subprocess.run([sys.executable, str(ROOT_DIR / "install.py")], check=True)
        web2api_bin = get_web2api_binary()

    print(f"""{BOLD}{GREEN}
============================================================
              OverBranch Self-Host Launcher
   100% Local • Zero API Keys • SQLite • Gemini Web2API
============================================================{RESET}
""")

    # 1. Start Gemini Web2API Proxy (Port 8081)
    if web2api_bin:
        cfg_arg = ["-config", str(BIN_DIR / "config.json")] if (BIN_DIR / "config.json").exists() else []
        start_service(
            name="Web2API",
            cmd=[str(web2api_bin), "-port", "8081"] + cfg_arg,
            cwd=BIN_DIR,
            color=MAGENTA,
        )
    else:
        log_error("Could not start Gemini Web2API. Please verify bin/gemini-web2api exists.")

    time.sleep(1.5)

    # 2. Start FastAPI LaTeX Backend (Port 8000)
    backend_cmd = [
        str(python_bin),
        "-m", "uvicorn",
        "main:app",
        "--host", "0.0.0.0",
        "--port", "8000",
    ]
    start_service(
        name="Backend",
        cmd=backend_cmd,
        cwd=BACKEND_DIR,
        color=BLUE,
    )

    time.sleep(1.5)

    # 3. Start Next.js Frontend (Port 3000)
    frontend_cmd = get_frontend_cmd()
    start_service(
        name="Frontend",
        cmd=frontend_cmd,
        cwd=ROOT_DIR,
        color=CYAN,
    )

    print(f"""
{BOLD}{GREEN}============================================================
       OverBranch Self-Host is running successfully!
============================================================{RESET}

  {BOLD}• Web Editor Workspace:{RESET}  {CYAN}http://localhost:3000{RESET}
  {BOLD}• TeX Engine API:{RESET}        {BLUE}http://localhost:8000{RESET}
  {BOLD}• Gemini Web2API Proxy:{RESET}  {MAGENTA}http://localhost:8081{RESET}

Press {BOLD}Ctrl+C{RESET} at any time to stop all services.
""")

    # Keep main thread alive and monitor processes
    try:
        while not is_shutting_down:
            time.sleep(0.5)
            # Check if any critical process died
            for p in processes:
                if p.poll() is not None and not is_shutting_down:
                    log_error(f"Process {p.pid} exited with code {p.returncode}")
    except KeyboardInterrupt:
        shutdown_all()


if __name__ == "__main__":
    main()
