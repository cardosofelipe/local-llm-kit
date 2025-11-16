#!/bin/bash
# Local-LLM-Kit Stop Script
# Clean shutdown of all services

set -e

# Source library functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/scripts/lib/common.sh"
source "$SCRIPT_DIR/scripts/lib/state.sh"

# Parse arguments
VERBOSE=false
if [ "$1" = "--verbose" ]; then
    VERBOSE=true
fi

# Check if Docker is available
if ! check_docker_available; then
    log_error "Docker is not running"
    exit 1
fi

# Check if services are running
if ! check_containers_running; then
    log_info "No services are currently running"
    exit 0
fi

# Stop containers
if $VERBOSE; then
    log_info "Stopping services..."
    docker compose down
else
    docker compose down > /dev/null 2>&1
fi

log_success "Services stopped"
