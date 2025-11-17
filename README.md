# Local-LLM-Kit

**Self-hosted LLM stack, batteries included.**

A complete, ready-to-deploy stack for running local Large Language Models with a modern web interface. Built on Open-WebUI, Ollama, and SearXNG for a private, ChatGPT-like experience that runs entirely on your own hardware.

## What's Included

- **Open-WebUI** - Beautiful, extensible web interface for interacting with AI models
- **Ollama** - Local LLM inference engine with CPU and GPU acceleration
- **SearXNG** - Privacy-respecting meta-search engine with 30+ search engines
- **Valkey** - High-performance open-source caching for faster search results
- **Automated setup** - Hardware detection, config generation, admin account creation
- **Web search enabled by default** - Real-time web search integration out of the box
- **Multi-platform GPU support** - Pre-configured for AMD (Vulkan) and NVIDIA (CUDA)

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

**Access Open-WebUI at http://localhost:11300**

**Default admin credentials (change after first login!):**
- Email: `admin@localhost`
- Password: `admin123`

That's it! The setup automatically:
- Detects your OS and GPU
- Selects the optimal Docker Compose template
- Generates all secrets (WEBUI_SECRET_KEY, SEARXNG_SECRET)
- Creates admin account and imports configuration
- Configures web search with SearXNG
- Persists Ollama SSH keys
- Opens your browser (use `--headless` to skip)

## Requirements

- Docker & Docker Compose
- 8GB+ RAM (16GB+ recommended)
- 10GB+ free disk space for models
- `openssl` (for secret generation)

## Hardware Support

The `setup.sh` script auto-detects your hardware and configures the optimal template:

| Platform | Description | Notes |
|----------|-------------|-------|
| **CPU-Only** | Works on any system | Slower inference, no GPU required |
| **NVIDIA GPU** | RTX/GTX series, datacenter GPUs | Requires NVIDIA Container Toolkit |
| **AMD GPU** | RDNA 2/3 (RX 6000/7000/8000) | Uses Vulkan acceleration |
| **macOS** | Apple Silicon / Intel | Native Ollama + Docker WebUI for Metal GPU |

See [config-templates/README.md](config-templates/README.md) for details on each template.

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
make clean          # Remove generated files only
```

Or use scripts directly:
```bash
./setup.sh                  # Interactive setup
./start.sh                  # Start services
./start.sh --headless       # Start without opening browser
./start.sh --verbose        # Detailed output
./stop.sh                   # Stop services
```

---

## Configuration

### Storage Paths

During setup, you'll be prompted for storage paths. To change them later, edit `.env`:

```bash
# Models can be large (4GB-100GB per model)
OLLAMA_MODELS_PATH=./data/models/ollama

# Ollama config (SSH keys, settings)
OLLAMA_CONFIG_PATH=./config/ollama

# Web UI data (database, uploads)
OPENWEBUI_DATA_PATH=./data/open-webui

# SearXNG config
SEARXNG_CONFIG_PATH=./config/searxng

# Valkey cache data (search results cache)
VALKEY_DATA_PATH=./data/valkey
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

### Admin Account

Default credentials are set via environment variables (change in `.env` before setup):

```bash
WEBUI_ADMIN_NAME=admin
WEBUI_ADMIN_EMAIL=admin@localhost
WEBUI_ADMIN_PASSWORD=admin123
```

**⚠️ Change the password after first login!**
Go to Settings → Account → Change Password

### Web Search

Web search is automatically configured on first start. The system:
1. Creates default admin user
2. Authenticates to get API token
3. Imports config with web search enabled
4. Configures SearXNG as search engine

Verify at: http://localhost:11300/admin/settings → Documents → Web Search

### SearXNG Enhancements

The stack includes an optimized SearXNG configuration with enterprise-grade features:

**Valkey-Backed Caching:**
- Valkey is a fully open-source fork of Redis (recommended by SearXNG)
- Search results cached for 10 minutes (configurable)
- Significantly faster repeated searches
- Reduced load on search engines
- Persistent across container restarts

**30+ Search Engines:**
- **General**: Google, Bing, DuckDuckGo, Brave, Qwant, Startpage
- **Images**: Google Images, Bing Images, DuckDuckGo Images
- **Videos**: YouTube, Google Videos, Bing Videos
- **News**: Google News, Bing News
- **IT/Programming**: GitHub, GitLab, Codeberg, Stack Overflow
- **Science**: Wikipedia, Wikidata, arXiv, PubMed
- **Files**: Archive.org
- **Maps**: OpenStreetMap
- **Social**: Reddit
- **Music**: SoundCloud
- **Dictionaries**: Wiktionary, DictZone, Currency Converter

**Privacy Features:**
- Image proxy enabled (proxies all images through SearXNG)
- Tracker URL removal
- No search logs by default
- Respects robots.txt disabled (internal use only)

**Performance Optimizations:**
- Connection pooling (100 connections, pool size 20)
- HTTP/2 enabled for faster connections
- Intelligent timeout management (5s default, 15s max)
- Rate limiting with Valkey backend (30 req/min per IP)
- Docker network whitelisted for unlimited Open-WebUI requests

**Customization:**
Access SearXNG directly at http://localhost:11380 to:
- Choose specific search engines
- Use engine shortcuts (e.g., `!gh` for GitHub, `!wp` for Wikipedia)
- Filter by category (general, images, news, videos, etc.)
- Enable/disable safe search

**Configuration Files:**
- `config/searxng/settings.yml` - Main configuration with engine list
- `config/searxng/limiter.toml` - Rate limiting and bot detection

### Secrets

All secrets are auto-generated during `make setup`:

```bash
WEBUI_SECRET_KEY=<64-char hex>      # Open-WebUI session secret
SEARXNG_SECRET=<64-char hex>        # SearXNG encryption key
```

To regenerate secrets:
```bash
# Generate new secrets
openssl rand -hex 32

# Update in .env
nano .env

# Restart services
make restart
```

---

## Ports

| Service | Port | Description |
|---------|------|-------------|
| Open-WebUI | 11300 | Web interface |
| SearXNG | 11380 | Search engine |
| Ollama | 11434 | Internal API (not exposed by default) |
| Valkey | 6379 | Internal cache (not exposed outside Docker network) |

Ports use the 11xxx range to avoid conflicts with common development servers (3000, 8080).

---

## Project Structure

```
.
├── docker-compose.yml          # Generated from template
├── .env                        # Configuration (gitignored)
├── setup.sh                    # Interactive setup
├── start.sh                    # Smart startup
├── stop.sh                     # Clean shutdown
├── Makefile                    # Convenience commands
├── config/                     # Runtime config (gitignored)
│   ├── ollama/                 # Ollama SSH keys, config
│   └── searxng/                # Generated SearXNG settings
├── config-templates/           # Templates (tracked in git)
│   ├── docker-compose.*.yml    # Hardware-specific templates
│   ├── searxng/               # SearXNG config templates
│   ├── default-config.json     # Default Open-WebUI config
│   └── README.md              # Template documentation
├── scripts/
│   ├── lib/                    # Shared library functions
│   │   ├── common.sh          # Logging, OS detection
│   │   ├── hardware.sh        # GPU detection
│   │   ├── secrets.sh         # Secret generation
│   │   ├── state.sh           # State management
│   │   ├── interactive.sh     # User prompts
│   │   └── config.sh          # Config file management
│   └── internal/              # Internal automation
│       ├── wait-for-db.sh     # Wait for database
│       └── init-webui.sh      # Create admin + import config
└── data/                      # User data (gitignored)
    ├── models/ollama/         # Downloaded models
    ├── open-webui/            # Database, uploads, cache
    └── valkey/                # Valkey cache data
```

---

## Script Reference

### Main Scripts

**setup.sh** - Interactive first-time setup
- Detects OS and GPU hardware
- Prompts for template selection
- Configures storage paths
- Generates secrets automatically
- Initializes config files from templates

**start.sh** - Smart startup with auto-initialization
- Checks prerequisites (setup complete, Docker running)
- Starts containers
- Waits for database initialization
- Creates admin user (first boot only)
- Imports configuration via API
- Opens browser (unless `--headless`)

Flags: `--headless`, `--verbose`

**stop.sh** - Clean shutdown
- Stops all containers gracefully
- Preserves data and configuration

### Internal Scripts

**scripts/internal/init-webui.sh** - Admin creation and config import
- Checks if users exist in database
- Creates default admin via signup API (if no users)
- Authenticates to get JWT token
- Imports configuration via authenticated API
- Displays credentials

**scripts/internal/wait-for-db.sh** - Database readiness check
- Polls for webui.db file
- Verifies database is accessible
- Timeout: 60 seconds

---

## Troubleshooting

### Setup Issues

**Setup script fails:**
```bash
# Check prerequisites
docker info                  # Docker running?
docker compose version       # Compose installed?
openssl version             # OpenSSL available?

# View detailed errors
./setup.sh
```

**Wrong template selected:**
```bash
make clean      # Remove generated files
make setup      # Re-run interactive setup
```

### Services Won't Start

```bash
# Check service status
make status

# View all logs
make logs

# View specific service
make logs-ollama
make logs-open-webui
make logs-searxng

# Check Docker
docker info
docker compose ps
```

### Web Search Not Working

```bash
# Check if configured
curl -s http://localhost:11300/api/v1/configs | jq '.rag.web.search'

# Restart (will reinitialize if needed)
make restart

# Manual config import (if needed)
# 1. Get API key from Settings → Account → API Keys
# 2. Run:
./scripts/import-config.sh 'your-api-key-here'

# Or import via UI:
# Settings → Admin Settings → General → Import Config
# Upload: config-templates/default-config.json
```

### SearXNG Issues

**Search results slow or timing out:**
```bash
# Check Valkey is running
docker compose ps valkey

# Check Valkey logs
docker compose logs valkey

# Test Valkey connection
docker compose exec valkey valkey-cli ping
# Should return: PONG

# Restart SearXNG to reconnect to Valkey
docker compose restart searxng
```

**Want to customize search engines:**
```bash
# Edit the SearXNG configuration
nano config/searxng/settings.yml

# Restart SearXNG to apply changes
docker compose restart searxng

# Check SearXNG logs for errors
docker compose logs searxng
```

**Clear search cache:**
```bash
# Clear Valkey cache
docker compose exec valkey valkey-cli FLUSHDB

# Or restart Valkey (clears cache on restart)
docker compose restart valkey
```

**Access SearXNG directly:**
- Open http://localhost:11380 in your browser
- Test searches directly
- View available engines and their status

### GPU Not Detected (AMD)

```bash
# Check group membership
groups | grep -E 'video|render'

# If missing, add yourself
sudo usermod -aG video $USER
sudo usermod -aG render $USER
# Log out and back in

# Verify group IDs in docker-compose.yml
grep -A 2 "group_add:" docker-compose.yml

# Check Ollama logs
make logs-ollama | grep -i vulkan
```

### GPU Not Detected (NVIDIA)

```bash
# Test NVIDIA runtime
nvidia-smi
docker run --rm --runtime=nvidia nvidia/cuda:12.0-base nvidia-smi

# Check Ollama logs
make logs-ollama | grep -i cuda

# Verify NVIDIA runtime
docker info | grep -i runtime
```

### macOS: Can't Connect to Ollama

```bash
# Check native Ollama is running
curl http://localhost:11434/api/tags

# If not running, start it
ollama serve

# Install if needed
brew install ollama
```

### Admin Login Not Working

Default credentials:
- Email: `admin@localhost`
- Password: `admin123`

If you changed these in `.env` before setup, use those credentials instead.

To reset admin password:
```bash
# Stop services
make stop

# Remove database (WARNING: deletes all data)
rm -rf data/open-webui/webui.db

# Restart (will recreate admin)
make start
```

### Need to Start Over?

```bash
# Full reset (WARNING: deletes all data and configuration)
make reset

# Then re-run setup
make setup
make start
```

---

## Advanced Configuration

### Manual Template Selection

If auto-detection selects the wrong template:

```bash
# During setup, choose manually when prompted
make setup

# Or copy template directly
cp config-templates/docker-compose.nvidia.yml docker-compose.yml
cp .env.example .env
# Edit .env and generate secrets
make start
```

### Custom Admin Credentials

Edit `.env` before running `make setup`:

```bash
WEBUI_ADMIN_NAME=myadmin
WEBUI_ADMIN_EMAIL=admin@mydomain.com
WEBUI_ADMIN_PASSWORD=SuperSecurePassword123!
```

### Disable Signup After Setup

Edit `.env` after creating your admin account:

```bash
ENABLE_SIGNUP=false
```

Then restart: `make restart`

### AMD GPU: Custom Group IDs

The setup script auto-detects group IDs, but if you need to set them manually:

```bash
# Get IDs
getent group video | cut -d: -f3
getent group render | cut -d: -f3

# Edit docker-compose.yml
nano docker-compose.yml
# Find and replace VIDEO_GROUP_ID and RENDER_GROUP_ID
```

---

## Documentation

- [Template Documentation](config-templates/README.md) - Details on each Docker Compose template
- [Claude Code Integration](CLAUDE.md) - For AI coding assistants
- [Open-WebUI Docs](https://docs.openwebui.com/)
- [Ollama Documentation](https://github.com/ollama/ollama)
- [SearXNG Documentation](https://docs.searxng.org/)

---

## License

MIT License - See [LICENSE](LICENSE) file for details.

## Contributing

Issues and pull requests welcome!

## Acknowledgments

- [Open-WebUI](https://github.com/open-webui/open-webui) - Beautiful web interface
- [Ollama](https://github.com/ollama/ollama) - Local LLM inference
- [SearXNG](https://github.com/searxng/searxng) - Privacy-respecting search
