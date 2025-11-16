#!/bin/bash
# Interactive prompt utilities for Local-LLM-Kit setup

# Source dependencies (use local var to not overwrite caller's SCRIPT_DIR)
_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$_LIB_DIR/common.sh"
source "$_LIB_DIR/hardware.sh"

# Prompt for template selection
# Usage: template=$(prompt_template_selection "detected-type")
# Returns: template filename (e.g., "docker-compose.nvidia.yml")
prompt_template_selection() {
    local detected="$1"
    local default_idx=1

    # All prompts to stderr so they're not captured by command substitution
    echo "" >&2
    log_header "Select Docker Compose Template" >&2
    echo "" >&2

    # Set default based on detection
    case "$detected" in
        nvidia) default_idx=2 ;;
        amd) default_idx=3 ;;
        macos) default_idx=4 ;;
        *) default_idx=1 ;;
    esac

    echo "1) CPU-only (works on any system)" >&2
    echo "2) NVIDIA GPU (requires NVIDIA Container Toolkit)" >&2
    echo "3) AMD GPU (Vulkan acceleration)" >&2
    echo "4) macOS (native Ollama + Docker WebUI)" >&2
    echo "" >&2
    read -p "Select template [${default_idx}]: " -r choice

    # Use default if empty
    if [ -z "$choice" ]; then
        choice=$default_idx
    fi

    case "$choice" in
        1) echo "docker-compose.cpu.yml" ;;
        2) echo "docker-compose.nvidia.yml" ;;
        3) echo "docker-compose.amd.yml" ;;
        4) echo "docker-compose.macos.yml" ;;
        *)
            echo "Invalid selection" >&2
            prompt_template_selection "$detected"
            ;;
    esac
}

# Prompt for storage paths
# Usage: prompt_storage_paths
# Sets global variables: OLLAMA_MODELS_PATH, OPENWEBUI_DATA_PATH
prompt_storage_paths() {
    echo "" >&2
    log_header "Storage Configuration" >&2
    echo "" >&2

    log_info "Where should Ollama store downloaded models?" >&2
    log_info "Models can be large (4GB-100GB per model)" >&2
    echo "" >&2

    read -p "Model storage path [./data/models/ollama]: " -r models_path
    if [ -z "$models_path" ]; then
        OLLAMA_MODELS_PATH="./data/models/ollama"
    else
        OLLAMA_MODELS_PATH="$models_path"
    fi

    echo "" >&2
    read -p "WebUI data path [./data/open-webui]: " -r webui_path
    if [ -z "$webui_path" ]; then
        OPENWEBUI_DATA_PATH="./data/open-webui"
    else
        OPENWEBUI_DATA_PATH="$webui_path"
    fi

    export OLLAMA_MODELS_PATH
    export OPENWEBUI_DATA_PATH
}

# Prompt for performance tier
# Usage: tier=$(prompt_performance_tier "recommended-tier")
# Returns: low, medium, or high
prompt_performance_tier() {
    local recommended="$1"
    local default_idx=2

    # All prompts to stderr
    echo "" >&2
    log_header "Performance Configuration" >&2
    echo "" >&2

    case "$recommended" in
        low) default_idx=1 ;;
        medium) default_idx=2 ;;
        high) default_idx=3 ;;
    esac

    echo "1) Low    - Conservative (1 parallel, 1 model loaded)" >&2
    echo "2) Medium - Balanced    (2 parallel, 1 model loaded)" >&2
    echo "3) High   - Aggressive  (4 parallel, 2 models loaded)" >&2
    echo "" >&2
    log_info "Recommended for your hardware: ${recommended}" >&2
    echo "" >&2
    read -p "Select performance tier [${default_idx}]: " -r choice

    if [ -z "$choice" ]; then
        choice=$default_idx
    fi

    case "$choice" in
        1) echo "low" ;;
        2) echo "medium" ;;
        3) echo "high" ;;
        *)
            echo "Invalid selection" >&2
            prompt_performance_tier "$recommended"
            ;;
    esac
}

# Prompt to confirm template choice
# Usage: if prompt_confirm_template "docker-compose.nvidia.yml"; then ...
prompt_confirm_template() {
    local template="$1"
    local template_name=$(basename "$template" .yml | sed 's/docker-compose\.//' | sed 's/-/ /g')

    echo ""
    log_info "Selected: ${template_name}"
    echo ""

    confirm_yes_no "Use this template?" "y"
}

# Display macOS native Ollama instructions
display_macos_instructions() {
    echo "" >&2
    log_header "macOS Setup Requirements" >&2
    echo "" >&2
    log_warning "Docker on macOS cannot access GPU acceleration" >&2
    echo "" >&2
    log_info "For best performance, install Ollama natively:" >&2
    echo "" >&2
    echo "  1. Install Ollama:" >&2
    echo "     brew install ollama" >&2
    echo "" >&2
    echo "  2. Start Ollama service:" >&2
    echo "     ollama serve" >&2
    echo "" >&2
    echo "  3. Then run this setup to configure Docker WebUI" >&2
    echo "" >&2

    if ! is_command_available ollama; then
        log_warning "Ollama is not installed" >&2
        echo "" >&2
        if ! confirm_yes_no "Continue anyway?" "n"; then
            echo "" >&2
            log_info "Install Ollama and run setup again" >&2
            exit 0
        fi
    elif ! check_native_ollama; then
        log_warning "Ollama is installed but not running" >&2
        echo "" >&2
        log_info "Start Ollama with: ollama serve" >&2
        echo "" >&2
        if ! confirm_yes_no "Continue anyway?" "n"; then
            exit 0
        fi
    else
        log_success "Native Ollama detected and running!" >&2
    fi
}

# Display AMD group setup instructions
display_amd_group_instructions() {
    if ! check_user_in_gpu_groups; then
        echo "" >&2
        log_warning "You are not in 'video' and 'render' groups" >&2
        echo "" >&2
        log_info "Add yourself to these groups for GPU access:" >&2
        echo "" >&2
        echo "  sudo usermod -aG video \$USER" >&2
        echo "  sudo usermod -aG render \$USER" >&2
        echo "" >&2
        log_warning "You must log out and back in for group changes to take effect" >&2
        echo "" >&2

        if ! confirm_yes_no "Continue anyway?" "y"; then
            exit 0
        fi
    fi
}

# Display NVIDIA runtime info
display_nvidia_verification() {
    echo "" >&2
    log_info "Checking NVIDIA GPU configuration..." >&2

    # Check if nvidia runtime is available (check both grep patterns to be safe)
    if docker info 2>/dev/null | grep -E "Runtimes.*nvidia|nvidia.*Runtime" >/dev/null; then
        log_success "NVIDIA runtime detected in Docker ✓" >&2
        echo "" >&2
        log_info "Your Docker is properly configured for NVIDIA GPUs" >&2
    else
        echo "" >&2
        log_warning "Could not confirm NVIDIA runtime in Docker" >&2
        echo "" >&2
        log_info "If you previously had GPU working, this is probably fine." >&2
        log_info "The setup will continue - verify GPU access after starting services:" >&2
        echo "  docker compose logs ollama | grep -i cuda" >&2
    fi
}
