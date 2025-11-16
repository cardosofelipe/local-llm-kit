#!/bin/bash
# Initialize Open-WebUI web search configuration
# Uses Open-WebUI API to import configuration

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
CONFIG_FILE="$PROJECT_ROOT/config-templates/default-config.json"
WEBUI_URL="${WEBUI_URL:-http://localhost:11300}"
MAX_WAIT=30

# Parse arguments
VERBOSE=false
if [ "$1" = "--verbose" ]; then
    VERBOSE=true
fi

# Logging
log_verbose() {
    if $VERBOSE; then
        echo "$1"
    fi
}

log_error() {
    echo "ERROR: $1" >&2
}

# Check if config file exists
if [ ! -f "$CONFIG_FILE" ]; then
    log_error "Config file not found: $CONFIG_FILE"
    exit 1
fi

# Wait for Open-WebUI to be responsive
log_verbose "Waiting for Open-WebUI to be ready..."
elapsed=0
while [ $elapsed -lt $MAX_WAIT ]; do
    if curl -s -f "$WEBUI_URL/health" >/dev/null 2>&1 || \
       curl -s -f "$WEBUI_URL/" >/dev/null 2>&1; then
        log_verbose "Open-WebUI is ready"
        break
    fi
    sleep 2
    elapsed=$((elapsed + 2))
done

if [ $elapsed -ge $MAX_WAIT ]; then
    log_error "Open-WebUI not ready after ${MAX_WAIT}s"
    exit 1
fi

# Import configuration using API
log_verbose "Importing configuration via API..."

# Try to import config using the /api/v1/configs/import endpoint
response=$(curl -s -w "\n%{http_code}" -X POST \
    "$WEBUI_URL/api/v1/configs/import" \
    -H "Content-Type: application/json" \
    -d @"$CONFIG_FILE" 2>/dev/null || echo "000")

http_code=$(echo "$response" | tail -n1)
body=$(echo "$response" | sed '$d')

if [ "$http_code" = "200" ] || [ "$http_code" = "201" ]; then
    if ! $VERBOSE; then
        echo "✓ Web search configured"
    else
        echo "Web search configuration imported successfully!"
        echo "  Engine: SearXNG"
        echo "  URL: http://searxng:8080/search?q=<query>"
    fi

    # Restart open-webui to ensure config is loaded
    if $VERBOSE; then
        echo "Restarting Open-WebUI..."
    fi
    docker compose restart open-webui >/dev/null 2>&1

    exit 0
else
    log_verbose "API import failed (HTTP $http_code), trying direct database update..."

    # Fallback to direct database manipulation
    DB_PATH="$PROJECT_ROOT/data/open-webui/webui.db"

    if [ ! -f "$DB_PATH" ]; then
        log_error "Database not found: $DB_PATH"
        exit 1
    fi

    docker run --rm -v "$PROJECT_ROOT/data/open-webui:/data" \
        -v "$PROJECT_ROOT/config-templates:/config" \
        python:3.11-slim python3 << 'PYEOF'
import sqlite3
import json
import sys

try:
    # Read the config file
    with open('/config/default-config.json', 'r') as f:
        new_config = json.load(f)

    # Connect to database
    conn = sqlite3.connect('/data/webui.db')
    cursor = conn.cursor()

    # Get existing config
    cursor.execute("SELECT data FROM config WHERE id = 1")
    row = cursor.fetchone()

    if not row:
        print("ERROR: No config found in database", file=sys.stderr)
        sys.exit(1)

    # Merge configs
    data = json.loads(row[0])

    # Deep merge rag config
    if 'rag' in new_config:
        if 'rag' not in data:
            data['rag'] = {}

        # Merge web search config
        if 'web' in new_config['rag']:
            if 'web' not in data['rag']:
                data['rag']['web'] = {}

            if 'search' in new_config['rag']['web']:
                if 'search' not in data['rag']['web']:
                    data['rag']['web']['search'] = {}
                data['rag']['web']['search'].update(new_config['rag']['web']['search'])

            if 'loader' in new_config['rag']['web']:
                if 'loader' not in data['rag']['web']:
                    data['rag']['web']['loader'] = {}
                data['rag']['web']['loader'].update(new_config['rag']['web']['loader'])

    # Update database
    cursor.execute(
        "UPDATE config SET data = ?, updated_at = CURRENT_TIMESTAMP WHERE id = 1",
        (json.dumps(data),)
    )
    conn.commit()
    conn.close()

    print("SUCCESS")
    sys.exit(0)

except Exception as e:
    print(f"ERROR: {e}", file=sys.stderr)
    sys.exit(1)
PYEOF

    if [ $? -eq 0 ]; then
        if ! $VERBOSE; then
            echo "✓ Web search configured"
        else
            echo "Web search configuration complete!"
            echo "  Engine: SearXNG"
            echo "  URL: http://searxng:8080/search?q=<query>"
        fi

        # Restart open-webui
        if $VERBOSE; then
            echo "Restarting Open-WebUI..."
        fi
        docker compose restart open-webui >/dev/null 2>&1

        exit 0
    else
        log_error "Failed to configure web search"
        exit 1
    fi
fi
