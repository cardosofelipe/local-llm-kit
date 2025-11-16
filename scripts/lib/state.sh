#!/bin/bash
# State checking utilities for Local-LLM-Kit

# Source common utilities (use local var to not overwrite caller's SCRIPT_DIR)
_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$_LIB_DIR/common.sh"

# Check if setup has been completed
check_setup_complete() {
    [ -f ".setup-complete" ]
}

# Mark setup as complete
mark_setup_complete() {
    touch ".setup-complete"
}

# Check if Docker is installed and running
check_docker_available() {
    if ! is_command_available docker; then
        return 1
    fi

    if ! docker info &>/dev/null; then
        return 1
    fi

    return 0
}

# Check if docker compose is available
check_docker_compose_available() {
    # Try docker compose (new way)
    if docker compose version &>/dev/null; then
        return 0
    fi

    # Try docker-compose (old way)
    if is_command_available docker-compose; then
        return 0
    fi

    return 1
}

# Check if containers are currently running
check_containers_running() {
    if ! check_docker_available; then
        return 1
    fi

    if docker compose ps 2>/dev/null | grep -q "Up\|running"; then
        return 0
    fi

    return 1
}

# Check if web search is configured in database
# Returns: 0 if configured, 1 if not or can't check
check_webui_configured() {
    local db_path="data/open-webui/webui.db"

    # Check if database exists
    if [ ! -f "$db_path" ]; then
        return 1
    fi

    # Query database for web search config
    docker run --rm -v "$(pwd)/data/open-webui:/data" python:3.11-slim python3 -c "
import sqlite3
import json
import sys

try:
    conn = sqlite3.connect('/data/webui.db')
    cursor = conn.cursor()
    cursor.execute('SELECT data FROM config WHERE id = 1')
    row = cursor.fetchone()
    conn.close()

    if row:
        data = json.loads(row[0])
        if data.get('rag', {}).get('web', {}).get('search', {}).get('enable'):
            sys.exit(0)

    sys.exit(1)
except:
    sys.exit(1)
" 2>/dev/null
}

# Check if docker-compose.yml exists
check_compose_file_exists() {
    [ -f "docker-compose.yml" ]
}

# Check if .env file exists
check_env_file_exists() {
    [ -f ".env" ]
}

# Get list of running containers
get_running_containers() {
    if check_docker_available; then
        docker compose ps --format "{{.Name}}" 2>/dev/null | grep -v "^$"
    fi
}

# Check if a specific service is healthy
# Usage: check_service_health "ollama"
check_service_health() {
    local service="$1"

    if ! check_docker_available; then
        return 1
    fi

    # Get health status from docker compose
    local status=$(docker compose ps "$service" --format "{{.Health}}" 2>/dev/null)

    if [ "$status" = "healthy" ]; then
        return 0
    fi

    # If no health check defined, check if it's running
    status=$(docker compose ps "$service" --format "{{.State}}" 2>/dev/null)
    if [ "$status" = "running" ]; then
        return 0
    fi

    return 1
}

# Wait for all services to be healthy/running
# Usage: wait_for_services 60 (timeout in seconds)
wait_for_services() {
    local timeout="${1:-60}"
    local elapsed=0
    local interval=2

    while [ $elapsed -lt $timeout ]; do
        if docker compose ps | grep -qE "Up|running"; then
            # At least one service is up, check if all expected services are up
            local expected=3  # ollama, open-webui, searxng (or 2 for macOS)
            local actual=$(docker compose ps --format "{{.State}}" 2>/dev/null | grep -c "running")

            if [ "$actual" -ge 2 ]; then  # At least 2 services (flexible for macos)
                return 0
            fi
        fi

        sleep $interval
        elapsed=$((elapsed + interval))
    done

    return 1
}
