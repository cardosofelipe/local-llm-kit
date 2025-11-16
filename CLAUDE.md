# CLAUDE.md

Claude Code context for Local-LLM-Kit.

**See [AGENTS.md](./AGENTS.md) for project context and development commands.**

## Claude Code-Specific Guidance

### When Working with This Stack

**Database Configuration:**
- Web search settings are in SQLite, not env vars
- Never suggest modifying `ENABLE_RAG_WEB_SEARCH` in `.env` to enable/disable web search
- Use `./scripts/internal/init-webui.sh` for web search configuration changes
- Database modifications require Open-WebUI restart: `docker compose restart open-webui`

**GPU Runtime Changes:**
- Switching between AMD/NVIDIA requires editing `docker-compose.yml`
- Must restart containers: `docker compose down && docker compose up -d`
- Don't use `restart` - GPU changes need full container recreation

**Script Architecture:**
- Main scripts: `setup.sh`, `start.sh`, `stop.sh` (user-facing)
- Internal scripts: `scripts/internal/*.sh` (called by main scripts)
- Libraries: `scripts/lib/*.sh` (shared functions, sourced by other scripts)
- Always check script dependencies before suggesting modifications

**Makefile Commands:**
- Prefer suggesting `make` commands over direct script execution
- Users are more likely familiar with `make start` than `./start.sh`
- Exception: When flags are needed (e.g., `./start.sh --headless`)

### Important Implementation Details

**Secret Generation:**
Two secrets required before first run:
1. `WEBUI_SECRET_KEY` in `.env`
2. `secret_key` in `config/searxng/settings.yml`

Both generated via `openssl rand -hex 32` during `setup.sh`.

**Template System:**
- Templates in `config-templates/` are READ-ONLY references
- Active config is `docker-compose.yml` (copied from template during setup)
- To switch hardware: `make clean && make setup` (re-runs detection)

**AMD Template - Dynamic Group IDs:**
AMD GPU access requires `video` and `render` groups. Group IDs vary by distro, so the AMD template uses placeholders (`VIDEO_GROUP_ID`, `RENDER_GROUP_ID`) that `setup.sh` replaces with actual IDs from `getent group`.

**macOS Template - No Ollama Container:**
Docker on macOS cannot access GPU. The macOS template runs ONLY Open-WebUI and SearXNG, connecting to native Ollama via `http://host.docker.internal:11434` for full Metal acceleration (5-6x faster than Docker CPU mode).

**Performance Settings:**
Set automatically by `setup.sh` based on detected hardware:
- CPU: `OLLAMA_NUM_PARALLEL=1, OLLAMA_MAX_LOADED_MODELS=1`
- Balanced: `OLLAMA_NUM_PARALLEL=2, OLLAMA_MAX_LOADED_MODELS=1`
- GPU: `OLLAMA_NUM_PARALLEL=4, OLLAMA_MAX_LOADED_MODELS=2`

**First-Run Detection:**
- `setup.sh` creates `.setup-complete` marker file
- `start.sh` checks marker and refuses to run if missing
- `scripts/internal/init-webui.sh` queries database to check if web search already configured (idempotent)

## Custom Skills

No Claude Code Skills installed yet. To create one, invoke the built-in "skill-creator" skill.

Potential skill ideas for this project:
- Docker Compose troubleshooting workflow
- GPU detection and validation helper
- Database configuration inspector

---

**For comprehensive documentation, see [README.md](./README.md) and [SETUP.md](./SETUP.md).**
