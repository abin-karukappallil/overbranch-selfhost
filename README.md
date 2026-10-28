# OverBranch Self-Host Edition

> **100% Local, Single-User, Zero-Configuration Agentic LaTeX IDE**
> Powered by Docker Compose, Local SQLite with Vector Search & Embedding, and Local Gemini Web2API.

---

## 🌟 Key Features of the Self-Host Edition

- **100% Containerized via Docker Compose across All Operating Systems**:
  - OverBranch runs completely inside Docker via `docker compose`.
  - Zero host clutter: No need to install TeX Live, MiKTeX, Python virtual environments, or Node.js on your host OS.
  - Consistent and non-breakable compiler runtime whether you are on **Windows, macOS, or Linux** (Ubuntu, Debian, Arch Linux, Fedora, CentOS, etc.).
- **Zero `.env` Files & Zero Configuration**:
  - Ready to use immediately with zero configuration. Database paths, local ports, internal service URLs (`http://localhost:3000`, `http://localhost:8000`, `http://localhost:8081`), and AI routing are pre-configured.
- **Zero API Keys & Zero External Cloud Dependencies**:
  - Operates completely on your local device.
  - No OpenAI, Groq, Nvidia, Supabase, or external cloud accounts required.
- **Embedded Local Gemini Web2API Proxy**:
  - Automatically runs [gemini-web2api](https://github.com/ikhsan3adi/gemini-web2api) as a lightweight local proxy on port `8081`.
  - Provides full agentic AI editing and completions.
- **Local SQLite Database with Vector Search & Embeddings**:
  - Stores all projects, files, templates, and preferences in a single SQLite database file (`overbranch.db`).
  - Includes a local semantic vector search engine with dense chunk embeddings and cosine similarity (`/api/sync-file` and `/api/vector-search`).
- **Single-User Zero-Auth**:
  - No registration or login needed. You are automatically signed in as **Local Author**.
  - All dashboard, templates, and editor routes open instantly.
- **Standalone Editor**:
  - Monaco LaTeX editor with full syntax highlighting, PDF synchronization (SyncTeX), diagnostics, and auto-compilation (`pdflatex` & `latexmk`).

---

## 🐳 Instant Launch via Docker Compose (All OS)

Run OverBranch Self-Host instantly inside Docker with the complete, **non-breakable LaTeX compiler**, all typography/fonts, embedded Gemini Web2API, and zero configuration.

### ⚡ 1-Click Command:
```bash
docker compose up -d
```

> ### **Access overbranch through localhost:3000**
> Direct Link: **[http://localhost:3000](http://localhost:3000)**

---

### ⚡ Cross-Platform Launcher Scripts (Auto-Installs Docker If Missing)

If you prefer using convenient scripts, every launcher script delegates directly to Docker Compose:

- **Linux / macOS**:
  ```bash
  ./run.sh
  # or: ./docker-up.sh
  ```
- **Windows (Command Prompt / Double-Click)**:
  ```cmd
  run.bat
  REM or: docker-up.bat
  ```
- **Windows (PowerShell)**:
  ```powershell
  .\docker-up.ps1
  ```
- **Universal Python Launcher**:
  ```bash
  python run.py
  ```

> 💡 **Automatic Docker Installation**:  
> If Docker is not installed on your system, running any of the 1-click launcher scripts will **automatically detect your OS and install Docker for you**:
> - **Windows**: Installs Docker Desktop via `winget` (or direct silent installer) and starts the daemon.
> - **Linux**: Installs Docker Engine via the official Docker installer (`get.docker.com`), enables the service, and configures user permissions.
> - **macOS**: Installs Docker Desktop via Homebrew Cask or official DMG and launches the app.

---

## 🚀 1-Line Quick Installation (Lightning Install)

Install and setup OverBranch Self-Host completely with a single command from anywhere:

### **Linux / macOS / Windows (Git Bash & WSL):**
```bash
curl -fsSL https://raw.githubusercontent.com/abin-karukappallil/overbranch-selfhost/main/install.sh | bash
```

### **Windows (PowerShell):**
```powershell
irm https://raw.githubusercontent.com/abin-karukappallil/overbranch-selfhost/main/install.ps1 | iex
```

### **What the 1-Line Command Does Automatically:**
1. **Checks / Installs Docker**: Detects your OS and installs Docker Engine or Docker Desktop if not already installed.
2. **Clones Repository**: Clones `https://github.com/abin-karukappallil/overbranch-selfhost.git` into `overbranch-selfhost`.
3. **Prepares Volume Storage**: Prepares SQLite database (`overbranch.db`) and project storage (`uploads/`).
4. **Installs Global `overbranch` Command**: Creates a global CLI command in your PATH so you can control OverBranch from anywhere.
5. **Starts via Docker Compose**: Launches the complete containerized stack in detached mode (`docker compose up -d`).
6. **Opens Browser**: Automatically opens [http://localhost:3000](http://localhost:3000).

---

## 💻 Global CLI Usage

After installation, you can control OverBranch anytime from **any terminal or folder**:

| Command | Action |
| :--- | :--- |
| `overbranch` | Start OverBranch container in background & open browser |
| `overbranch stop` (or `overbranch down`) | Stop and shut down OverBranch containers |
| `overbranch logs` | Tail live container logs from all 3 services |
| `overbranch restart` | Restart container services |
| `overbranch status` (or `overbranch ps`) | Show status of running containers |
| `overbranch build` | Rebuild the Docker image with latest changes |

*(All launcher scripts `./run.sh`, `run.bat`, and `python run.py` accept these exact same subcommands!)*

---

## 📦 What's Inside the Docker Container

The OverBranch container is fully self-contained and pre-packaged with:

- **Complete LaTeX Engine Suite**: `pdflatex`, `xelatex`, `lualatex`, `latexmk`, and `biber`.
- **All Document Classes & Packages**: `beamer` (with metropolis theme), `tikz`/`pgf`, `pgfplots`, `amsmath`, `mathtools`, `siunitx`, `newtx`, `tcolorbox`, `titlesec`, `fancyhdr`, `booktabs`, `caption`, `minted` (with Pygments syntax highlighter), and `glossaries`.
- **Complete Typography & Fonts**:
  - **Metric-Compatible Fonts**: Carlito (Calibri), Caladea (Cambria), Arimo (Arial), Tinos (Times New Roman), Cousine (Courier New), Liberation, and DejaVu.
  - **TeX Typography**: TeX Gyre (Termes, Heros, Pagella, Bonum, Schola, Cursor), Latin Modern, EB Garamond, Fira Sans & Fira Math, Source Serif 4 & Source Sans 3, Roboto, Lato, Inconsolata, IBM Plex, and STIX Two.
  - **CJK & Global Script Coverage**: Noto CJK, IPA Gothic/Mincho, Nanum, WQY Microhei/Zenhei, Arphic Uming/Ukai, Indic (Rachana, Meera, Lohit), Arabic (Amiri), Thai (TLWG), and SIL families.
  - **Microsoft Core Fonts**: Preseeded EULA acceptance with retry resilience (`ttf-mscorefonts-installer`).
- **Zero Configuration Microservices**:
  - **Next.js Web App** on port `3000` (Monaco editor + PDF preview + dashboard).
  - **FastAPI TeX Backend** on port `8000` (compilation queue + SyncTeX + vector database).
  - **Gemini Web2API Proxy** on port `8081` (local agentic AI completions).

Once running:
- **Web Editor Workspace:** [http://localhost:3000](http://localhost:3000)
- **TeX Python Engine API:** [http://localhost:8000](http://localhost:8000)
- **Gemini Web2API Proxy:** [http://localhost:8081](http://localhost:8081)

---

## 🛠️ Architecture

```
overbranch-selfhost/
├── docker-compose.yml     # Primary deployment configuration
├── Dockerfile             # Multi-stage container with complete TeX Live & Fonts
├── entrypoint.sh          # Container supervisor (starts Web2API, FastAPI & Next.js)
├── run.sh / run.bat       # Cross-platform Docker Compose runners
├── docker-up.sh / .bat    # Auto-installer & Docker Compose launcher
├── run.py                 # Universal Python Docker Compose controller
├── install.sh / .ps1      # 1-line curl/PowerShell installers
├── bin/
│   ├── gemini-web2api     # High-performance local Gemini Go proxy (port 8081)
│   └── config.json        # Web2API configuration
├── backend/
│   ├── main.py            # FastAPI entrypoint (port 8000)
│   ├── database.py        # Local SQLite asynchronous database engine
│   ├── vector_db.py       # Semantic vector index & embedding engine
│   ├── project_storage.py # Disk and SQLite project storage
│   ├── compiler.py        # pdflatex / latexmk compiler
│   └── providers/         # Routes AI to local Gemini Web2API (zero cloud keys)
├── db/                    # Next.js Drizzle SQLite schema & LibSQL client
├── app/                   # Next.js App Router (port 3000)
├── components/            # React UI components (Editor, Viewer, Dashboard)
├── uploads/               # Persistent project disk storage
└── overbranch.db          # Unified local SQLite database file
```

---

## 📄 License

Licensed under the [MIT License](LICENSE).
