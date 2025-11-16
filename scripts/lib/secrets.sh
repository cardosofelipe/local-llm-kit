#!/bin/bash
# Secret generation and management for Local-LLM-Kit

# Source common utilities (use local var to not overwrite caller's SCRIPT_DIR)
_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$_LIB_DIR/common.sh"

# Generate a random secret using openssl
# Returns: 64-character hexadecimal string
generate_secret() {
    if ! is_command_available openssl; then
        log_error "openssl not found. Please install openssl."
        return 1
    fi

    openssl rand -hex 32
}

# Update secret in .env file
# Usage: update_env_secret "WEBUI_SECRET_KEY" "abc123..."
update_env_secret() {
    local key="$1"
    local value="$2"
    local env_file="${3:-.env}"

    if [ ! -f "$env_file" ]; then
        log_error ".env file not found: $env_file"
        return 1
    fi

    # Use different sed syntax for macOS vs Linux
    if [[ "$OSTYPE" == "darwin"* ]]; then
        sed -i '' "s|^${key}=.*|${key}=${value}|" "$env_file"
    else
        sed -i "s|^${key}=.*|${key}=${value}|" "$env_file"
    fi
}

# Update SearXNG secret in settings.yml
# Usage: update_searxng_secret "abc123..."
update_searxng_secret() {
    local secret="$1"
    local config_file="config/searxng/settings.yml"

    if [ ! -f "$config_file" ]; then
        log_error "SearXNG config not found: $config_file"
        return 1
    fi

    # Replace the secret_key line in YAML
    # Use different sed syntax for macOS vs Linux
    if [[ "$OSTYPE" == "darwin"* ]]; then
        sed -i '' "s|secret_key:.*|secret_key: \"${secret}\"|" "$config_file"
    else
        sed -i "s|secret_key:.*|secret_key: \"${secret}\"|" "$config_file"
    fi
}

# Validate that secret is not a placeholder
# Returns: 0 if valid, 1 if placeholder
validate_secret() {
    local secret="$1"

    if [ -z "$secret" ]; then
        return 1
    fi

    if [[ "$secret" == *"CHANGE_ME"* ]]; then
        return 1
    fi

    if [[ "$secret" == *"GENERATE"* ]]; then
        return 1
    fi

    if [ ${#secret} -lt 16 ]; then
        return 1
    fi

    return 0
}

# Generate and update all secrets
# Usage: generate_all_secrets
generate_all_secrets() {
    log_info "Generating secrets..."

    # Generate WEBUI secret
    local webui_secret=$(generate_secret)
    if [ $? -ne 0 ]; then
        log_error "Failed to generate WEBUI secret"
        return 1
    fi

    # Generate SearXNG secret
    local searxng_secret=$(generate_secret)
    if [ $? -ne 0 ]; then
        log_error "Failed to generate SearXNG secret"
        return 1
    fi

    # Update .env file
    update_env_secret "WEBUI_SECRET_KEY" "$webui_secret"
    if [ $? -ne 0 ]; then
        log_error "Failed to update WEBUI secret in .env"
        return 1
    fi

    # Update SearXNG config
    update_searxng_secret "$searxng_secret"
    if [ $? -ne 0 ]; then
        log_error "Failed to update SearXNG secret"
        return 1
    fi

    log_success "Secrets generated"
    return 0
}
