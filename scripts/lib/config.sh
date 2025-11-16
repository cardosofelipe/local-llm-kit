#!/bin/bash
# Configuration file management for Local-LLM-Kit

# Source common utilities (use local var to not overwrite caller's SCRIPT_DIR)
_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$_LIB_DIR/common.sh"

# Initialize SearXNG configuration from template
# Usage: init_searxng_config "secret_key_value"
init_searxng_config() {
    local secret_key="$1"
    local template_dir="config-templates/searxng"
    local config_dir="config/searxng"

    if [ -z "$secret_key" ]; then
        log_error "Secret key is required"
        return 1
    fi

    # Create config directory
    mkdir -p "$config_dir"

    # Copy template files if they don't exist or if forced
    if [ ! -f "$config_dir/settings.yml" ]; then
        log_info "Initializing SearXNG configuration..."

        # Copy limiter.toml
        if [ -f "$template_dir/limiter.toml" ]; then
            cp "$template_dir/limiter.toml" "$config_dir/limiter.toml"
        fi

        # Copy and update settings.yml with secret
        if [ -f "$template_dir/settings.yml" ]; then
            cp "$template_dir/settings.yml" "$config_dir/settings.yml"

            # Replace placeholder with actual secret
            if [[ "$OSTYPE" == "darwin"* ]]; then
                sed -i '' "s|secret_key:.*|secret_key: \"${secret_key}\"|" "$config_dir/settings.yml"
            else
                sed -i "s|secret_key:.*|secret_key: \"${secret_key}\"|" "$config_dir/settings.yml"
            fi

            log_success "SearXNG configuration initialized"
        else
            log_error "Template not found: $template_dir/settings.yml"
            return 1
        fi
    else
        # Configuration already exists, skip
        return 0
    fi

    return 0
}

# Initialize Ollama configuration
# Usage: init_ollama_config
init_ollama_config() {
    local config_dir="config/ollama"

    # Create config directory
    mkdir -p "$config_dir"
    return 0
}

# Initialize all configuration directories
# Usage: init_all_configs "searxng_secret"
init_all_configs() {
    local searxng_secret="$1"

    init_ollama_config
    init_searxng_config "$searxng_secret"

    return $?
}
