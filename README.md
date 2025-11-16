# Local-LLM-Kit

**Self-hosted LLM stack, batteries included.**

A complete, ready-to-deploy stack for running local Large Language Models with a modern web interface. Built on Open-WebUI, Ollama, and SearXNG for a private, ChatGPT-like experience that runs entirely on your own hardware.

## What's Included

- **Open-WebUI** - Beautiful, extensible web interface for interacting with AI models
- **Ollama** - Local LLM inference engine with CPU and GPU acceleration
- **SearXNG** - Privacy-respecting meta-search engine for web-enriched responses
- **Web search enabled by default** - Real-time web search integration out of the box
- **Multi-platform GPU support** - Pre-configured for AMD (Vulkan) and NVIDIA (CUDA)
- **Batteries-included setup** - Everything you need in one package, ready to run

## Quick Start

```bash
# 1. Clone the repository
git clone https://github.com/yourusername/local-llm-kit.git
cd local-llm-kit

# 2. Configure environment (required on first run)
cp .env.example .env
# Generate secrets and customize paths in .env
sed -i "s/CHANGE_ME_GENERATE_WITH_OPENSSL/$(openssl rand -hex 32)/" .env

# 3. Update SearXNG secret key
SECRET=$(openssl rand -hex 32)
sed -i "s/CHANGE_ME_GENERATE_WITH_OPENSSL_RAND_HEX_32/$SECRET/" config/searxng/settings.yml

# 4. Start the stack
docker compose up -d

# 5. Initialize web search configuration
./init-webui-config.sh

# 6. Access Open-WebUI
open http://localhost:11300
```

Create your admin account on first visit. Web search will be enabled by default.

## Requirements

- Docker & Docker Compose
- 8GB+ RAM (16GB+ recommended)
- 10GB+ free disk space

### GPU Support (Optional)

**AMD GPU:**
- Already configured for AMD GPUs with Vulkan
- Tested on: Radeon 8060S (RDNA 3.5)

**NVIDIA GPU:**
- Uncomment NVIDIA runtime configuration in `docker-compose.yml`
- Requires: NVIDIA Container Toolkit

## Configuration

### Storage Paths

Edit `.env` to customize where models and data are stored:

```bash
# Use /data partition (recommended for large models)
OLLAMA_MODELS_PATH=/data/models/ollama

# Or keep everything in project directory (portable)
OLLAMA_MODELS_PATH=./data/models/ollama
```

### Web Search

Web search is automatically enabled after running `init-webui-config.sh`.

Verify at: http://localhost:11300/admin/settings/web

### GPU Configuration

**For AMD GPUs (current setup):**
- Set `OLLAMA_VULKAN=1` in `.env` (already configured)
- Adjust `HSA_OVERRIDE_GFX_VERSION` for your GPU architecture

**For NVIDIA GPUs:**
1. Uncomment `runtime: nvidia` in `docker-compose.yml`
2. Remove AMD-specific configuration
3. See [GPU setup guide](SETUP.md#gpu-support)

## Ports

| Service | Port | Description |
|---------|------|-------------|
| Open-WebUI | 11300 | Web interface |
| SearXNG | 11380 | Search engine |
| Ollama | 11434 | Internal API |

## Project Structure

```
.
├── docker-compose.yml       # Service definitions
├── .env                     # Configuration variables
├── init-webui-config.sh     # Web search initialization
├── config/
│   ├── ollama/             # Ollama configuration
│   └── searxng/            # SearXNG settings
├── config-templates/       # Reference configurations
└── data/                   # User data and models (gitignored)
```

## Troubleshooting

### Web search not working?

```bash
# Re-run initialization
./init-webui-config.sh

# Check services
docker compose ps

# View logs
docker compose logs -f open-webui
```

### GPU not detected?

```bash
# Check Ollama logs
docker compose logs ollama | grep -i vulkan  # AMD
docker compose logs ollama | grep -i cuda    # NVIDIA

# Verify device access
ls -la /dev/dri  # AMD
nvidia-smi       # NVIDIA
```

### Database issues?

```bash
# Restart services
docker compose restart

# Full reset (WARNING: deletes all data)
docker compose down
rm -rf data/open-webui/webui.db
docker compose up -d
./init-webui-config.sh
```

## Documentation

- [Detailed Setup Guide](SETUP.md)
- [Open-WebUI Docs](https://docs.openwebui.com/)
- [Ollama Documentation](https://github.com/ollama/ollama)
- [SearXNG Documentation](https://docs.searxng.org/)

## License

MIT License - See [LICENSE](LICENSE) file for details.

## Contributing

Issues and pull requests welcome!

## Acknowledgments

- [Open-WebUI](https://github.com/open-webui/open-webui)
- [Ollama](https://github.com/ollama/ollama)
- [SearXNG](https://github.com/searxng/searxng)
