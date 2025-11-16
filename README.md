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

# 2. Run interactive setup (detects hardware, generates config)
make setup

# 3. Start services
make start
```

Access Open-WebUI at **http://localhost:11300** and create your admin account.

That's it! The setup script automatically:
- Detects your OS and GPU
- Selects the optimal Docker Compose template
- Generates all secrets
- Configures web search
- Opens your browser (use `--headless` to skip)

## Common Commands

```bash
make setup          # Interactive setup (first time only)
make start          # Start all services
make stop           # Stop all services
make restart        # Restart services
make status         # Check service health
make logs           # View all logs
make logs-ollama    # View specific service logs
make reset          # Full reset (deletes all data)
```

Or use scripts directly:
```bash
./setup.sh                  # Interactive setup
./start.sh                  # Start services
./start.sh --headless       # Start without opening browser
./stop.sh                   # Stop services
```

## Requirements

- Docker & Docker Compose
- 8GB+ RAM (16GB+ recommended)
- 10GB+ free disk space

## Hardware Support

The `setup.sh` script auto-detects your hardware and configures the optimal template:

**CPU-Only** - Works on any system, slower inference
**NVIDIA GPU** - RTX/GTX series, requires NVIDIA Container Toolkit
**AMD GPU** - RDNA 2/3 (RX 6000/7000/8000), uses Vulkan acceleration
**macOS** - Native Ollama + Docker WebUI for full Metal GPU acceleration

See [config-templates/README.md](config-templates/README.md) for details on each template.

## Configuration

Configuration is handled by `setup.sh`, but you can customize after setup:

### Storage Paths

During setup, you'll be prompted for storage paths. To change them later, edit `.env`:

```bash
# Models can be large (4GB-100GB per model)
OLLAMA_MODELS_PATH=./data/models/ollama

# Web UI data (database, uploads)
OPENWEBUI_DATA_PATH=./data/open-webui
```

### Performance Tuning

The setup script recommends settings based on your hardware. To adjust, edit `.env`:

```bash
# Performance tiers:
# Low (CPU):    OLLAMA_NUM_PARALLEL=1, MAX_LOADED=1
# Medium:       OLLAMA_NUM_PARALLEL=2, MAX_LOADED=1
# High (GPU):   OLLAMA_NUM_PARALLEL=4, MAX_LOADED=2

OLLAMA_NUM_PARALLEL=2
OLLAMA_MAX_LOADED_MODELS=1
```

### Web Search

Web search is automatically configured by `start.sh` on first run.

Verify at: http://localhost:11300/admin/settings/web

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

### Services won't start?

```bash
# Check service status
make status

# View logs
make logs              # All services
make logs-ollama       # Specific service
make logs-open-webui
```

### Web search not working?

```bash
# Restart services (will reinitialize web search if needed)
make restart

# Or manually reinitialize
./scripts/internal/init-webui.sh --verbose
```

### GPU not detected?

```bash
# Check Ollama logs for GPU info
make logs-ollama | grep -i vulkan  # AMD
make logs-ollama | grep -i cuda    # NVIDIA

# Verify device access
ls -la /dev/dri  # AMD
nvidia-smi       # NVIDIA

# Re-run setup to change template
make clean
make setup
```

### Need to start over?

```bash
# Full reset (WARNING: deletes all data and configuration)
make reset

# Then re-run setup
make setup
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
