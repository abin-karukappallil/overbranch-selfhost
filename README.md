# OverBranch Self-Host Edition

> **100% local, single-user, zero-configuration agentic LaTeX IDE.**
> Runs in Docker on Linux, macOS (Intel + Apple Silicon) and Windows. Nothing to install on your machine except Docker.

---

## Install

**Linux / macOS / WSL / Git Bash**
```bash
curl -fsSL https://raw.githubusercontent.com/overbranch/overbranch-selfhost/main/install.sh | bash
```

**Windows (PowerShell)**
```powershell
irm https://raw.githubusercontent.com/overbranch/overbranch-selfhost/main/install.ps1 | iex
```

Then open **<http://localhost:3000>**.

The installer installs Docker if it is missing, **pulls a prebuilt, CI-tested image** (no compiling on your machine), starts it, and adds an `overbranch` command. The first pull is a few GB (a complete TeX Live and font set); later updates are small.

> **Windows:** a fresh Docker Desktop install needs a restart and a one-time launch to accept its licence and enable WSL2. The installer stops and tells you when that is needed; run `overbranch` again afterwards.

### Already have Docker?

```bash
docker compose up -d
```

`docker-compose.yml` is pull-only: it never silently falls back to a local build.

## The `overbranch` command

| Command | Action |
| :-- | :-- |
| `overbranch` | Pull (if needed), start, open the browser |
| `overbranch stop` | Stop the containers (data is kept) |
| `overbranch restart` / `status` / `logs` | Restart / show state / follow logs |
| `overbranch update` | Pull the latest image and restart |
| `overbranch backup [file.tgz]` | Export your database and projects |
| `overbranch restore file.tgz` | Replace current data from a backup |
| `overbranch build` | Build the app image locally instead of pulling (needs `git`) |

`run.sh`, `run.bat`, `run.py`, `start.sh` and `docker-up.*` still work; they forward to the installers.

## Where your data lives

Two Docker named volumes, identical on every OS: `overbranch-data` (SQLite database) and `overbranch-uploads` (projects). They survive `stop`, `update` and image upgrades. Use `overbranch backup` to copy them to a host file. Upgrading from an older install that kept `overbranch.db` beside the compose file? The installer migrates it automatically.

## Building from source

| Goal | Command |
| :-- | :-- |
| Rebuild just the app (minutes; still pulls the TeX base) | `docker compose -f docker-compose.yml -f docker-compose.build.yml up -d --build` |
| Build everything incl. TeX Live (30-60 min, ~20 GB free) | `docker build -f docker/texlive.Dockerfile -t overbranch-texlive:local .` then `docker compose -f docker-compose.yml -f docker-compose.texlive.yml up -d --build` |

## What's in the image

- **TeX Live 2026, scheme-full** from the upstream installer: `pdflatex`, `xelatex`, `lualatex`, `latexmk`, `biber`, `makeindex`, `makeglossaries`, `synctex`, plus every CTAN package (beamer, tikz/pgf, pgfplots, siunitx, newtx, tcolorbox, glossaries, ...). `minted` works under TeX Live's restricted shell-escape via `latexminted`; no special flags needed.
- **Fonts**: metric-compatible Carlito, Caladea, Arimo, Tinos, Cousine, Liberation, DejaVu; TeX Gyre, Latin Modern, EB Garamond, Fira, Roboto, Lato, Inconsolata, IBM Plex, STIX Two; Noto (incl. CJK), IPA, Nanum, WenQuanYi, Arphic, Indic, Arabic, Thai and SIL families; Microsoft core fonts. Missing proprietary fonts are substituted automatically at compile time.
- **Services** (one container): Next.js on `3000`, FastAPI TeX engine on `8000`, Gemini Web2API proxy on `8081`.

Every release is built natively for amd64 and arm64 in CI, which fails if the font gate, any of the engine smoke compiles (including minted without `-shell-escape`), or the runtime health checks fail.

## Troubleshooting

- **"image is not publicly readable yet"**: the maintainer has not made the GHCR package public. Use `overbranch build` meanwhile.
- **"you appear to be offline"**: connect and retry; an already-pulled image starts offline with `overbranch up`.
- **Port in use**: `PORT=3100 overbranch` (also `BACKEND_PORT`, `WEB2API_PORT`).
- **Docker not reachable**: start Docker Desktop and wait for "Engine running".

## Repository layout

```
docker-compose.yml          pull-only default (GHCR image + named volumes)
docker-compose.build.yml    opt-in: build the app image locally
docker-compose.texlive.yml  opt-in: build the TeX base locally too
Dockerfile                  app image (FROM the published TeX base)
docker/texlive.Dockerfile   TeX Live + fonts base, with font gate and smoke compiles
docker/texlive-base.lock    the base image the app image is built from
.github/workflows/          CI: multi-arch base + app images -> GHCR
install.sh / install.ps1    installer and `overbranch` CLI
entrypoint.sh               starts Web2API, FastAPI and Next.js
backend/ app/ components/   FastAPI engine and Next.js UI
```

## License

[MIT](LICENSE)
