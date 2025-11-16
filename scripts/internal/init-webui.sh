#!/bin/bash
# Initialize Open-WebUI web search configuration
# Handles both first-boot (no users) and existing installations

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

# Check if this is first boot (no users in database)
DB_PATH="$PROJECT_ROOT/data/open-webui/webui.db"
if [ ! -f "$DB_PATH" ]; then
    log_verbose "Database not found, waiting for first boot..."
    exit 0
fi

# Check if users exist
USER_COUNT=$(docker run --rm -v "$PROJECT_ROOT/data/open-webui:/data" \
    python:3.11-slim python3 -c "
import sqlite3
try:
    conn = sqlite3.connect('/data/webui.db')
    cursor = conn.cursor()
    cursor.execute('SELECT COUNT(*) FROM user')
    count = cursor.fetchone()[0]
    conn.close()
    print(count)
except:
    print(0)
" 2>/dev/null || echo "0")

if [ "$USER_COUNT" = "0" ]; then
    if ! $VERBOSE; then
        echo "✓ First boot - environment variables will configure web search"
    else
        echo "No users detected - first boot scenario"
        echo "Web search will be configured via environment variables"
        echo "  ENABLE_RAG_WEB_SEARCH=true"
        echo "  RAG_WEB_SEARCH_ENGINE=searxng"
    fi
    exit 0
fi

# Users exist - need authenticated API call or manual import
log_verbose "Existing installation detected (${USER_COUNT} users)"
log_verbose "Web search configuration requires manual setup:"
echo ""
echo "════════════════════════════════════════════════════════════════"
echo "  Manual Configuration Required"
echo "════════════════════════════════════════════════════════════════"
echo ""
echo "Your installation already has users configured."
echo "To enable web search, please import the configuration manually:"
echo ""
echo "1. Open Open-WebUI: http://localhost:11300"
echo "2. Login as admin"
echo "3. Go to Settings → Admin Settings → General"
echo "4. Click 'Import Config' button"
echo "5. Upload: $CONFIG_FILE"
echo ""
echo "Or use the API with your admin token:"
echo ""
echo "  export WEBUI_ADMIN_TOKEN='your-api-key-here'"
echo "  curl -X POST http://localhost:11300/api/v1/configs/import \\"
echo "       -H \"Authorization: Bearer \$WEBUI_ADMIN_TOKEN\" \\"
echo "       -H \"Content-Type: application/json\" \\"
echo "       -d @$CONFIG_FILE"
echo ""
echo "Get your API key from: Settings → Account → API Keys"
echo "════════════════════════════════════════════════════════════════"
echo ""

exit 0
