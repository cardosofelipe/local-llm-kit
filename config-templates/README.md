# Docker Compose Templates

This directory contains hardware-optimized Docker Compose templates for Local-LLM-Kit. The `setup.sh` script automatically detects your hardware and uses the appropriate template.

## Available Templates

### 1. `docker-compose.cpu.yml` - CPU-Only Mode
**Use when:**
- No compatible GPU available
- Testing or development
- Low-resource environments

**Performance:** 2-10 tokens/second for small models (7B)

**No prerequisites** beyond Docker

---

### 2. `docker-compose.nvidia.yml` - NVIDIA GPU
**Use when:**
- System has NVIDIA GPU (RTX, GTX, datacenter)

**Performance:** 20-60 tokens/second for small models (7B)

**Prerequisites:**
1. NVIDIA Driver (525.x or newer)
2. NVIDIA Container Toolkit
   ```bash
   # Installation guide:
   # https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/install-guide.html
   ```

**Verify setup:**
```bash
nvidia-smi
docker run --rm --gpus all nvidia/cuda:12.0-base nvidia-smi
```

---

### 3. `docker-compose.amd.yml` - AMD GPU
**Use when:**
- System has AMD Radeon GPU (RDNA 2/3: RX 6000/7000/8000 series)

**Performance:** 15-50 tokens/second for small models (7B)

**Prerequisites:**
1. AMD GPU drivers (amdgpu)
2. Vulkan support
3. User in `video` and `render` groups

**Verify setup:**
```bash
ls -la /dev/dri                    # Should show card* and render* devices
groups                             # Should include video and render
vulkaninfo | grep -i amd           # Verify Vulkan sees GPU
```

**Important:** Group IDs vary by Linux distribution. The `setup.sh` script automatically detects and configures correct IDs.

**GPU Architecture:**
The `HSA_OVERRIDE_GFX_VERSION` setting must match your GPU:
- RDNA 3.5 (gfx1151 - Radeon 8060S): `11.0.0`
- RDNA 3 (gfx1100 - RX 7900): `11.0.0` or `11.5.1`
- RDNA 2 (gfx1030 - RX 6800): `10.3.0`

Customize in `.env` if needed.

---

### 4. `docker-compose.macos.yml` - macOS (Native Ollama)
**Use when:**
- Running on macOS (Apple Silicon or Intel)

**Performance:** 20-80 tokens/second (with native Ollama + Metal)

**Important:** This template runs ONLY Open-WebUI and SearXNG in Docker. Ollama must run natively on macOS for GPU acceleration.

**Why native Ollama?**
Docker on macOS cannot access GPU, resulting in 5-6x slower performance. Native Ollama uses Metal acceleration for full GPU speed.

**Setup:**
```bash
# 1. Install native Ollama
brew install ollama

# 2. Start Ollama service
ollama serve

# 3. Verify it's running
curl http://localhost:11434/api/tags

# 4. Then start Docker services
docker compose up -d
```

---

## Manual Template Selection

If not using `setup.sh`, you can manually select a template:

```bash
# Copy your chosen template
cp config-templates/docker-compose.nvidia.yml docker-compose.yml

# For AMD: manually fix group IDs
# Edit docker-compose.yml and replace VIDEO_GROUP_ID and RENDER_GROUP_ID
# with output from:
getent group video | cut -d: -f3    # video group ID
getent group render | cut -d: -f3   # render group ID

# Configure .env file
cp .env.example .env
# Edit .env to set secrets and paths

# Start services
docker compose up -d
```

---

## Switching Templates

To switch hardware configurations:

```bash
# Stop current setup
docker compose down

# Copy new template
cp config-templates/docker-compose.cpu.yml docker-compose.yml

# Restart
docker compose up -d
```

Your data in `data/` directory is preserved.

---

## Performance Comparison

| Template | Small Model (7B) | Large Model (13B+) | VRAM Required |
|----------|------------------|-------------------|---------------|
| CPU      | 2-10 tok/s      | Too slow         | 0GB (RAM only)|
| NVIDIA   | 20-60 tok/s     | 10-30 tok/s      | 6GB+          |
| AMD      | 15-50 tok/s     | 8-25 tok/s       | 6GB+          |
| macOS    | 20-80 tok/s     | 10-40 tok/s      | Shared memory |

*Performance varies by specific hardware model and model size*

---

## Troubleshooting

### NVIDIA: GPU not detected
```bash
# Check driver
nvidia-smi

# Test container toolkit
docker run --rm --gpus all nvidia/cuda:12.0-base nvidia-smi

# Check docker-compose config
docker compose config | grep -A 10 "runtime:"
```

### AMD: Group permission errors
```bash
# Check your groups
groups

# Add yourself to groups (replace $USER with your username)
sudo usermod -aG video $USER
sudo usermod -aG render $USER

# Log out and back in for changes to take effect
```

### macOS: Can't connect to Ollama
```bash
# Verify Ollama is running
curl http://localhost:11434/api/tags

# Start Ollama if needed
ollama serve

# Check Docker can reach host
docker run --rm --add-host=host.docker.internal:host-gateway \
  alpine ping -c 3 host.docker.internal
```

---

## Advanced: Custom Template

You can create custom templates by copying an existing one and modifying:
- GPU device mappings
- Performance settings
- Environment variables

Keep your custom templates outside this directory to avoid conflicts with updates.
