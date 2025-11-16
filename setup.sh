#!/bin/bash
# Local-LLM-Kit Setup Script
# Interactive hardware detection and configuration

set -e

# Source library functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/scripts/lib/common.sh"
source "$SCRIPT_DIR/scripts/lib/hardware.sh"
source "$SCRIPT_DIR/scripts/lib/secrets.sh"
source "$SCRIPT_DIR/scripts/lib/state.sh"
source "$SCRIPT_DIR/scripts/lib/interactive.sh"

# Check not running as sudo
check_not_sudo

# Header
echo ""
echo "══════════════════════════════════════════════════════════════"
echo "  Local-LLM-Kit Setup"
echo "  Self-hosted LLM Stack Configuration"
echo "══════════════════════════════════════════════════════════════"
echo ""

# Check if already set up
if check_setup_complete; then
    log_warning "Setup already completed"
    echo ""
    if confirm_yes_no "Run setup again? This will overwrite your configuration." "n"; then
        rm -f .setup-complete docker-compose.yml
        log_info "Re-running setup..."
    else
        log_info "Setup cancelled. Use './start.sh' to start services."
        exit 0
    fi
fi

# Check prerequisites
log_header "Checking Prerequisites"

if ! check_docker_available; then
    log_error "Docker is not installed or not running"
    echo ""
    log_info "Install Docker:"
    log_info "  Linux:  https://docs.docker.com/engine/install/"
    log_info "  macOS:  https://docs.docker.com/desktop/install/mac-install/"
    exit 1
fi
log_success "Docker is available"

if ! check_docker_compose_available; then
    log_error "Docker Compose is not available"
    log_info "Install: https://docs.docker.com/compose/install/"
    exit 1
fi
log_success "Docker Compose is available"

if ! is_command_available openssl; then
    log_error "openssl not found"
    log_info "Install openssl to generate secrets"
    exit 1
fi
log_success "openssl is available"

# Detect hardware
log_header "Detecting Hardware"

OS=$(detect_os)
log_info "Operating system: $OS"

if [ "$OS" = "unknown" ]; then
    log_error "Unsupported operating system: $OSTYPE"
    exit 1
fi

# GPU detection (Linux only)
GPU_TYPE="none"
if [ "$OS" = "linux" ] || [ "$OS" = "wsl" ]; then
    GPU_TYPE=$(detect_gpu_linux)
    log_info "GPU detected: $GPU_TYPE"
elif [ "$OS" = "macos" ]; then
    GPU_TYPE="macos"
    log_info "macOS detected - will use native Ollama"
fi

# Recommend template based on detection
if [ "$GPU_TYPE" = "macos" ]; then
    RECOMMENDED_TEMPLATE="docker-compose.macos.yml"
elif [ "$GPU_TYPE" = "nvidia" ]; then
    RECOMMENDED_TEMPLATE="docker-compose.nvidia.yml"
elif [ "$GPU_TYPE" = "amd" ]; then
    RECOMMENDED_TEMPLATE="docker-compose.amd.yml"
else
    RECOMMENDED_TEMPLATE="docker-compose.cpu.yml"
fi

log_success "Recommended template: $(basename $RECOMMENDED_TEMPLATE .yml | sed 's/docker-compose\.//' | sed 's/-/ /g')"

# Template selection
SELECTED_TEMPLATE=$(prompt_template_selection "$GPU_TYPE")
log_success "Selected: $SELECTED_TEMPLATE"

# Special handling for different templates
if [ "$SELECTED_TEMPLATE" = "docker-compose.macos.yml" ]; then
    display_macos_instructions
elif [ "$SELECTED_TEMPLATE" = "docker-compose.amd.yml" ]; then
    display_amd_group_instructions
elif [ "$SELECTED_TEMPLATE" = "docker-compose.nvidia.yml" ]; then
    display_nvidia_verification
fi

# Copy template
log_header "Configuring Docker Compose"

cp "config-templates/$SELECTED_TEMPLATE" docker-compose.yml
log_success "Created docker-compose.yml from template"

# AMD-specific: Fix group IDs
if [ "$SELECTED_TEMPLATE" = "docker-compose.amd.yml" ]; then
    log_info "Detecting AMD GPU group IDs..."

    VIDEO_GID=$(get_video_group_id)
    RENDER_GID=$(get_render_group_id)

    if [ -z "$VIDEO_GID" ] || [ -z "$RENDER_GID" ]; then
        log_warning "Could not detect video/render group IDs"
        log_info "You may need to manually edit docker-compose.yml"
    else
        log_info "  video group: $VIDEO_GID"
        log_info "  render group: $RENDER_GID"

        # Replace placeholders in docker-compose.yml
        if [[ "$OSTYPE" == "darwin"* ]]; then
            sed -i '' "s/VIDEO_GROUP_ID/$VIDEO_GID/g" docker-compose.yml
            sed -i '' "s/RENDER_GROUP_ID/$RENDER_GID/g" docker-compose.yml
        else
            sed -i "s/VIDEO_GROUP_ID/$VIDEO_GID/g" docker-compose.yml
            sed -i "s/RENDER_GROUP_ID/$RENDER_GID/g" docker-compose.yml
        fi

        log_success "Group IDs configured"
    fi
fi

# Storage paths configuration
prompt_storage_paths

# Performance tier configuration
RECOMMENDED_TIER=$(recommend_performance_tier "$GPU_TYPE")
PERF_TIER=$(prompt_performance_tier "$RECOMMENDED_TIER")
PERF_SETTINGS=$(get_performance_settings "$PERF_TIER")
NUM_PARALLEL=$(echo $PERF_SETTINGS | cut -d' ' -f1)
MAX_LOADED=$(echo $PERF_SETTINGS | cut -d' ' -f2)

log_success "Performance: $PERF_TIER (parallel=$NUM_PARALLEL, max_loaded=$MAX_LOADED)"

# Create .env file
log_header "Generating Configuration"

if [ -f .env ]; then
    log_warning ".env file already exists"
    if confirm_yes_no "Overwrite?" "n"; then
        rm -f .env
    else
        log_info "Keeping existing .env file"
    fi
fi

if [ ! -f .env ]; then
    cp .env.example .env
    log_success "Created .env file"

    # Generate and update secrets
    generate_all_secrets

    # Initialize config files from templates
    # Get the generated secret from .env
    SEARXNG_SECRET=$(grep "^SEARXNG_SECRET=" .env | cut -d'=' -f2)
    source "$SCRIPT_DIR/scripts/lib/config.sh"
    init_all_configs "$SEARXNG_SECRET"

    # Update storage paths
    update_env_secret "OLLAMA_MODELS_PATH" "$OLLAMA_MODELS_PATH"
    update_env_secret "OPENWEBUI_DATA_PATH" "$OPENWEBUI_DATA_PATH"

    # Update performance settings
    update_env_secret "OLLAMA_NUM_PARALLEL" "$NUM_PARALLEL"
    update_env_secret "OLLAMA_MAX_LOADED_MODELS" "$MAX_LOADED"

    log_success "Configuration complete"
fi

# Create directories
log_header "Creating Directories"

mkdir -p "$OLLAMA_MODELS_PATH" "$OPENWEBUI_DATA_PATH" config/ollama
log_success "Directories created"

# Mark setup as complete
mark_setup_complete
log_success "Setup marker created"

# Done!
echo ""
echo "══════════════════════════════════════════════════════════════"
log_success "Setup Complete!"
echo "══════════════════════════════════════════════════════════════"
echo ""

if [ "$SELECTED_TEMPLATE" = "docker-compose.macos.yml" ]; then
    log_info "Next steps:"
    echo "  1. Ensure Ollama is running: ollama serve"
    echo "  2. Start services: ./start.sh  (or 'make start')"
else
    log_info "Next steps:"
    echo "  ./start.sh        (or 'make start')"
fi

echo ""
log_info "For help, see README.md and SETUP.md"
echo ""
