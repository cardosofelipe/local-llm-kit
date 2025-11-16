# Local-LLM-Kit Setup Guide

Complete setup instructions for your self-hosted LLM stack.

## Automated Setup (Recommended)

The easiest way to get started is using the automated setup:

```bash
# 1. Run interactive setup
make setup

# 2. Start services
make start
```

The setup script will:
- Detect your OS and GPU
- Select the optimal Docker Compose template
- Generate all secrets automatically
- Configure storage paths
- Set performance parameters
- Initialize web search on first start

## Manual Setup

If you prefer manual configuration or the automated setup doesn't work:

1. **Choose a template:**
   ```bash
   cp config-templates/docker-compose.cpu.yml docker-compose.yml
   # Or: nvidia.yml, amd.yml, macos.yml
   ```

2. **Configure environment:**
   ```bash
   cp .env.example .env
   # Generate and add secrets
   sed -i "s/CHANGE_ME_GENERATE_WITH_OPENSSL/$(openssl rand -hex 32)/" .env
   ```

3. **Update SearXNG secret:**
   ```bash
   SECRET=$(openssl rand -hex 32)
   sed -i "s/CHANGE_ME_GENERATE_WITH_OPENSSL_RAND_HEX_32/$SECRET/" config/searxng/settings.yml
   ```

4. **For AMD GPUs:** Edit docker-compose.yml and replace VIDEO_GROUP_ID and RENDER_GROUP_ID:
   ```bash
   getent group video | cut -d: -f3    # Get video GID
   getent group render | cut -d: -f3   # Get render GID
   ```

5. **Start services:**
   ```bash
   docker compose up -d
   ./scripts/internal/wait-for-db.sh
   ./scripts/internal/init-webui.sh
   ```

6. **Access Open-WebUI:**
   - URL: http://localhost:11300
   - Create your admin account

## What's Included

- **Open-WebUI**: Beautiful web interface for AI chat
- **Ollama**: Local LLM inference engine
- **SearXNG**: Privacy-respecting meta-search engine

## Script Reference

### Main Scripts

- **setup.sh** - Interactive first-time setup with hardware detection
  - Flags: none (interactive prompts)

- **start.sh** - Smart startup with auto-initialization
  - Flags: `--headless` (skip browser), `--verbose` (detailed output)

- **stop.sh** - Clean shutdown
  - Flags: `--verbose` (show details)

### Internal Scripts

- **scripts/internal/wait-for-db.sh** - Wait for database initialization
- **scripts/internal/init-webui.sh** - Configure web search in database

### Library Scripts

All shared functions are in `scripts/lib/`:
- `common.sh` - Logging, OS detection, browser opening
- `hardware.sh` - GPU detection, group ID resolution
- `secrets.sh` - Secret generation
- `state.sh` - State checks (setup complete, services running)
- `interactive.sh` - Interactive prompts

## Configuration

### Hardware Templates

The setup script auto-selects templates based on detection. See [config-templates/README.md](config-templates/README.md) for details on each template.

### Storage Paths

Configured during `setup.sh`, or edit `.env` manually:
```bash
OLLAMA_MODELS_PATH=./data/models/ollama
OPENWEBUI_DATA_PATH=./data/open-webui
```

### Performance Settings

Set during setup based on hardware, or edit `.env`:
```bash
OLLAMA_NUM_PARALLEL=2
OLLAMA_MAX_LOADED_MODELS=1
```

### Web Search

Automatically configured by `start.sh` on first run.

Verify at: http://localhost:11300/admin/settings/web

## Ports

- **11300**: Open-WebUI
- **11380**: SearXNG
- **11434**: Ollama API (internal)

## Troubleshooting

### Setup Issues

**Setup script fails:**
```bash
# Check prerequisites
docker info              # Docker running?
docker compose version   # Compose installed?
openssl version         # openssl available?

# Re-run with verbose output
./setup.sh
```

**Wrong template selected:**
```bash
# Clean and re-run setup
make clean
make setup
```

### Runtime Issues

**Services won't start:**
```bash
# Check logs
make logs

# Check specific service
make logs-ollama
make logs-open-webui
```

**Web search not working:**
```bash
# Restart (re-initializes if needed)
make restart

# Or manually
./scripts/internal/init-webui.sh --verbose
```

**GPU not detected (AMD):**
```bash
# Check group membership
groups | grep -E 'video|render'

# If missing, add yourself
sudo usermod -aG video $USER
sudo usermod -aG render $USER
# Log out and back in

# Check group IDs were set correctly
grep -A 2 "group_add:" docker-compose.yml
```

**GPU not detected (NVIDIA):**
```bash
# Test NVIDIA toolkit
nvidia-smi
docker run --rm --gpus all nvidia/cuda:12.0-base nvidia-smi

# If fails, reinstall toolkit
# https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/install-guide.html
```

**macOS: Can't connect to Ollama:**
```bash
# Check native Ollama is running
curl http://localhost:11434/api/tags

# If not running, start it
ollama serve
```

### Complete Reset

```bash
# Nuclear option: delete everything and start over
make reset
make setup
make start
```
