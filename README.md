# OverBranch Self-Host Edition

> **100% Local, Single-User, Zero-Configuration Agentic LaTeX IDE**
> Powered by Local SQLite with Vector Search & Embedding, and Local Gemini Web2API.

---

## 🌟 Key Features of the Self-Host Edition

- **Zero `.env` Files & Zero Configuration**:
  - No environment files (`.env`) needed or used. All database paths, local ports, service URLs (`http://localhost:3000`, `http://localhost:8000`, `http://localhost:8081`), and AI routing are hardcoded directly into the application.
- **Zero API Keys & Zero External Cloud Dependencies**:
  - Operates completely on your local device.
  - No OpenAI, Groq, Nvidia, Supabase, or external cloud accounts required.
- **Embedded Local Gemini Web2API Proxy**:
  - Automatically runs [gemini-web2api](https://github.com/ikhsan3adi/gemini-web2api) as a lightweight local Go binary on port `8081`.
  - Provides full agentic AI editing and completions.
- **Local SQLite Database with Vector Search & Embeddings**:
  - Stores all projects, files, templates, and preferences in a single SQLite database file (`overbranch.db`).
  - Includes a local semantic vector search engine with dense chunk embeddings and cosine similarity (`/api/sync-file` and `/api/vector-search`).
- **Single-User Zero-Auth**:
  - No registration or login needed. You are automatically signed in as **Local Author**.
  - All dashboard, templates, and editor routes open instantly.
- **Standalone Editor**:
  - Monaco LaTeX editor with full syntax highlighting, PDF synchronization (SyncTeX), diagnostics, and auto-compilation (`pdflatex` & `latexmk`).
  - Realtime collaboration layer disabled for distraction-free single-user workflows.
- **Single-Command Launcher**:
  - A single script concurrently starts the Web2API proxy, FastAPI Python backend, and Next.js frontend with unified logs and graceful shutdown.
  - Compatible with **Windows, macOS, and all Linux distributions** (Arch, Ubuntu, Debian, CentOS, Fedora, etc.).

---

## 🐳 Instant Docker Compose Launch (1-Click • Zero Configuration)

Run OverBranch Self-Host instantly inside Docker with the complete, **non-breakable LaTeX compiler**, all typography/fonts, embedded Gemini Web2API, and zero configuration.

### ⚡ 1-Click Command:
```bash
docker compose up -d
```

> ### **Access overbranch through localhost:3000**
> Direct Link: **[http://localhost:3000](http://localhost:3000)**

### ⚡ 1-Click Launcher Scripts (Auto-Installs Docker If Missing):
- **Windows (Double-Click)**: `docker-up.bat` (or PowerShell: `.\docker-up.ps1`)
- **Linux / macOS**: `./docker-up.sh` (or `./start.sh --docker`)

> 💡 **Automatic Docker Installation**:  
> If Docker is not installed on your system, running any of the 1-click launcher scripts will **automatically detect your OS and install Docker for you**:
> - **Windows**: Installs Docker Desktop via `winget` (or direct silent installer) and starts the daemon.
> - **Linux**: Installs Docker Engine via the official Docker installer (`get.docker.com`), enables the service, and configures user permissions.
> - **macOS**: Installs Docker Desktop via Homebrew Cask or official DMG and launches the app.

### 📦 Included Compiler & Dockerfile Packages (From Parent App):
- **Full LaTeX Engine Suite**: `pdflatex`, `xelatex`, `lualatex`, `latexmk`, and `biber`.
- **All Document Classes & Packages**: `beamer` (with metropolis theme), `tikz`/`pgf`, `pgfplots`, `amsmath`, `mathtools`, `siunitx`, `newtx`, `tcolorbox`, `titlesec`, `fancyhdr`, `booktabs`, `caption`, `minted` (with Pygments syntax highlighter), and `glossaries`.
- **Complete Font Coverage Gate**:
  - **Metric-Compatible Fonts**: Carlito (Calibri), Caladea (Cambria), Arimo (Arial), Tinos (Times New Roman), Cousine (Courier New), Liberation, and DejaVu.
  - **TeX Typography**: TeX Gyre (Termes, Heros, Pagella, Bonum, Schola, Cursor), Latin Modern, EB Garamond, Fira Sans & Fira Math, Source Serif 4 & Source Sans 3, Roboto, Lato, Inconsolata, IBM Plex, and STIX Two.
  - **CJK & Global Script Coverage**: Noto CJK, IPA Gothic/Mincho, Nanum, WQY Microhei/Zenhei, Arphic Uming/Ukai, Indic (Rachana, Meera, Lohit), Arabic (Amiri), Thai (TLWG), and SIL families.
  - **Microsoft Core Fonts**: Preseeded EULA acceptance with retry resilience (`ttf-mscorefonts-installer`).
- **Zero Configuration**:
  - Automatically launches **Gemini Web2API** on port `8081` (no cloud keys needed).
  - Automatically initializes **SQLite Schema & Vector DB** (`overbranch.db`).
  - Automatically launches **FastAPI TeX Backend** on port `8000`.
  - Automatically launches **Next.js Web App** on port `3000`.

---

## 🚀 1-Line Quick Installation (Lightning Install)

Install and setup OverBranch Self-Host completely with a single command from anywhere:

### **Linux / macOS / Windows (Git Bash & WSL):**
```bash
curl -fsSL https://raw.githubusercontent.com/abin-karukappallil/overbranch-selfhost/main/install.sh | bash
```
*(Or alternatively: `bash <(curl -fsSL https://raw.githubusercontent.com/abin-karukappallil/overbranch-selfhost/main/install.sh)`)*

### **Windows (PowerShell):**
```powershell
irm https://raw.githubusercontent.com/abin-karukappallil/overbranch-selfhost/main/install.ps1 | iex
```

### **What the 1-Line Command Does Automatically:**
1. **Clones Repository**: Clones `https://github.com/abin-karukappallil/overbranch-selfhost.git` into `overbranch-selfhost`.
2. **Downloads Gemini Web2API**: Detects OS and CPU architecture (`amd64` / `arm64`) and downloads the official precompiled Go proxy into `bin/gemini-web2api`.
3. **Sets Up Python Backend**: Creates `.venv`, installs requirements, and configures the local vector search engine.
4. **Installs Frontend**: Automatically installs all Next.js dependencies with Bun or npm.
5. **Initializes SQLite**: Creates `overbranch.db` with all tables, vector embeddings, and LaTeX templates.
6. **Installs & Configures the LaTeX Compiler**: Detects `pdflatex` / `latexmk` and, if missing, installs a TeX toolchain for the host OS — complete with beamer, TikZ/PGF and the AMS packages, so Beamer decks and figures compile offline:
   - **Windows** — **MiKTeX** via winget or the silent installer, with on-the-fly package installation.
   - **macOS** — **BasicTeX** via Homebrew, then the `beamer`, `pictures`, `mathscience` and `latexextra` collections via `tlmgr`.
   - **Linux** — **TeX Live** via the system package manager (`apt`, `dnf`, `pacman`, `zypper`, `apk` or `yum`).

   On macOS and Linux the install needs root. If you are root, or `sudo` needs no password, it runs unattended; in a terminal it asks first; and in a piped `curl | bash` install, where there is no terminal to type a password into, it prints the exact command instead of hanging on an invisible prompt.
7. **Zero-Configuration**: 100% hardcoded defaults — no `.env` file or cloud API keys required.

---

### Manual Installation (If Already Cloned)

If you have already cloned the repository manually:

```bash
git clone https://github.com/abin-karukappallil/overbranch-selfhost.git
cd overbranch-selfhost
```

**Linux / macOS:**
```bash
./install.sh
# or: python3 install.py
```

**Windows (Command Prompt / PowerShell):**
```cmd
cd overbranch-selfhost
install.bat
rem or: python install.py
```

---

---

### 2. Run OverBranch Anytime

After installation, you can launch OverBranch anytime without re-cloning:

#### ⚡ Option A: Universal Command (Fastest)
From **any terminal window or directory**, simply type:
```bash
overbranch
```

#### ⚡ Option B: Single-Line Instant Launcher
Run without changing directories:
```bash
# Linux / macOS
curl -fsSL https://raw.githubusercontent.com/abin-karukappallil/overbranch-selfhost/main/start.sh | bash
```

#### ⚡ Option C: Direct Script
```bash
# Linux / macOS:
cd overbranch-selfhost && ./run.sh
# or: python3 run.py

# Windows (Command Prompt / PowerShell):
cd overbranch-selfhost
run.bat
rem or: python run.py
```

> **🔄 Automatic Updates:**
> Every time you start OverBranch, it automatically checks and pulls the latest updates from GitHub (`git pull origin main`). If updates are found, it recompiles the production frontend automatically so you are always running the latest version!

Once running:
- **Web Editor Workspace:** [http://localhost:3000](http://localhost:3000)
- **TeX Python Engine API:** [http://localhost:8000](http://localhost:8000)
- **Gemini Web2API Proxy:** [http://localhost:8081](http://localhost:8081)

Press `Ctrl+C` to stop all services.

---

## 🛠️ Architecture

```
overbranch-selfhost/
├── run.py                 # Cross-platform single launcher (starts all 3 services)
├── install.py             # Universal cross-platform installer
├── run.sh / run.bat       # Platform convenience scripts
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
└── overbranch.db          # Unified local SQLite database file
```

---

## 📄 License

Licensed under the [MIT License](LICENSE).
