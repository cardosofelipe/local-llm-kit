# AGENTS.md

AI coding assistant context for Local-LLM-Kit.

## Quick Start

```bash
make setup          # First-time setup (detects hardware, generates secrets)
make start          # Start all services
```

Access Open-WebUI at **http://localhost:11300** after startup completes.

## Critical Implementation Notes

### Web Search Configuration
- Settings stored in **SQLite database**, NOT environment variables
- Automatically initialized by `start.sh` on first run
- Manual init: `./scripts/internal/init-webui.sh --verbose`
- Database path: `data/open-webui/webui.db`

### GPU Support
- **AMD** (default): Vulkan acceleration, requires `/dev/dri` access, `HSA_OVERRIDE_GFX_VERSION=11.0.0`
- **NVIDIA**: Uncomment `runtime: nvidia` in docker-compose.yml, requires NVIDIA Container Toolkit
- **macOS**: Native Ollama with Metal (not in Docker)
- Changes require restart: `docker compose down && docker compose up -d`

### Service Architecture
- **Dependencies**: Open-WebUI → Ollama + SearXNG
- **Network**: `ollama-network` (172.28.0.0/16)
- **Service references**: Use container names (`http://ollama:11434`, `http://searxng:8080`)

### Hardware Templates
`setup.sh` auto-selects from `config-templates/`:
- `docker-compose.cpu.yml` - CPU-only
- `docker-compose.nvidia.yml` - NVIDIA GPU
- `docker-compose.amd.yml` - AMD GPU
- `docker-compose.macos.yml` - macOS native Ollama

## Documentation

See [README.md](./README.md) for comprehensive documentation and [SETUP.md](./SETUP.md) for detailed setup instructions.
