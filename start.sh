#!/bin/bash
# Local-LLM-Kit Start Script
# Smart startup with auto-initialization

set -e

# Source library functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/scripts/lib/common.sh"
source "$SCRIPT_DIR/scripts/lib/hardware.sh"
source "$SCRIPT_DIR/scripts/lib/state.sh"

# Parse command line arguments
HEADLESS=false
VERBOSE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --headless)
            HEADLESS=true
            shift
            ;;
        --verbose)
            VERBOSE=true
            shift
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: $0 [--headless] [--verbose]"
            exit 1
            ;;
    esac
done

# Check if setup was completed
if ! check_setup_complete; then
    log_error "Setup not completed"
    echo ""
    log_info "Run setup first:"
    echo "  ./setup.sh    (or 'make setup')"
    exit 1
fi

# Check if docker-compose.yml exists
if ! check_compose_file_exists; then
    log_error "docker-compose.yml not found"
    log_info "Run setup: ./setup.sh"
    exit 1
fi

# Check Docker is available
if ! check_docker_available; then
    log_error "Docker is not running"
    log_info "Start Docker and try again"
    exit 1
fi

# Check if already running
if check_containers_running; then
    log_warning "Services are already running"
    echo ""
    log_info "Service status:"
    docker compose ps
    echo ""
    log_info "Use 'make restart' or './stop.sh && ./start.sh' to restart"
    exit 0
fi

# Detect if using macOS template (check if ollama service exists in compose)
USING_MACOS_TEMPLATE=false
if ! grep -q "^  ollama:" docker-compose.yml 2>/dev/null; then
    USING_MACOS_TEMPLATE=true
fi

# macOS-specific: Check native Ollama is running
if $USING_MACOS_TEMPLATE; then
    if $VERBOSE; then
        log_info "macOS configuration detected, checking native Ollama..."
    fi

    if ! check_native_ollama; then
        log_error "Native Ollama is not running"
        echo ""
        log_info "Start Ollama first:"
        echo "  ollama serve"
        echo ""
        log_info "Or install it:"
        echo "  brew install ollama"
        exit 1
    fi

    if $VERBOSE; then
        log_success "Native Ollama is running"
    fi
fi

# Start containers
if $VERBOSE; then
    log_header "Starting Services"
    docker compose up -d
else
    log_info "Starting services..."
    docker compose up -d > /dev/null 2>&1
fi

log_success "Containers started"

# Wait for database
if $VERBOSE; then
    log_info "Waiting for database initialization..."
    "$SCRIPT_DIR/scripts/internal/wait-for-db.sh" --verbose
else
    "$SCRIPT_DIR/scripts/internal/wait-for-db.sh"
fi

log_success "Database ready"

# Initialize web search if needed
if $VERBOSE; then
    log_info "Checking web search configuration..."
fi

if check_webui_configured; then
    if $VERBOSE; then
        log_success "Web search already configured"
    fi
else
    if $VERBOSE; then
        log_info "Configuring web search..."
        "$SCRIPT_DIR/scripts/internal/init-webui.sh" --verbose
    else
        "$SCRIPT_DIR/scripts/internal/init-webui.sh"
    fi
fi

# Health check
if $VERBOSE; then
    log_header "Service Health"
    docker compose ps
    echo ""
fi

# Display URLs
echo ""
echo "══════════════════════════════════════════════════════════════"
log_success "All services running"
echo "══════════════════════════════════════════════════════════════"
echo ""
log_info "Access points:"
echo "  → Open-WebUI: http://localhost:${OPEN_WEBUI_PORT:-11300}"
echo "  → SearXNG:    http://localhost:${SEARXNG_PORT:-11380}"
echo ""

if $USING_MACOS_TEMPLATE; then
    log_info "Using native Ollama on macOS for GPU acceleration"
fi
log_info "First time? Click \"Getting Started\" and create your admin account at Open-WebUI"

echo ""

# Wait for Open-WebUI to be fully ready before opening browser
if ! $HEADLESS; then
    log_info "Waiting for Open-WebUI to be fully ready..."
    sleep 7
    echo ""
fi

# Open browser (if not headless)
if ! $HEADLESS; then
    if $VERBOSE; then
        log_info "Attempting to open browser..."
    fi

    WEBUI_URL="http://localhost:${OPEN_WEBUI_PORT:-11300}"

    if open_browser "$WEBUI_URL"; then
        if $VERBOSE; then
            log_success "Browser opened"
        fi
    else
        if $VERBOSE; then
            log_warning "Could not open browser automatically"
            log_info "Open manually: $WEBUI_URL"
        fi
    fi
fi

# Show logs reminder
if $VERBOSE; then
    echo ""
    log_info "View logs: docker compose logs -f"
    log_info "Stop services: ./stop.sh  (or 'make stop')"
fi
