#!/bin/bash
# Helper script to import configuration using admin API token
# Usage: ./scripts/import-config.sh <API_TOKEN>

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CONFIG_FILE="$PROJECT_ROOT/config-templates/default-config.json"
WEBUI_URL="${WEBUI_URL:-http://localhost:11300}"

# Check for API token argument
if [ $# -eq 0 ]; then
    echo "Usage: $0 <API_TOKEN>"
    echo ""
    echo "Get your API token from Open-WebUI:"
    echo "  1. Login to Open-WebUI (http://localhost:11300)"
    echo "  2. Go to Settings → Account → API Keys"
    echo "  3. Create a new API key"
    echo "  4. Run: $0 'your-api-key-here'"
    echo ""
    exit 1
fi

API_TOKEN="$1"

# Check if config file exists
if [ ! -f "$CONFIG_FILE" ]; then
    echo "ERROR: Config file not found: $CONFIG_FILE"
    exit 1
fi

echo "Importing configuration to Open-WebUI..."
echo "  URL: $WEBUI_URL"
echo "  Config: $CONFIG_FILE"
echo ""

# Import config via API
response=$(curl -s -w "\n%{http_code}" -X POST \
    "$WEBUI_URL/api/v1/configs/import" \
    -H "Authorization: Bearer $API_TOKEN" \
    -H "Content-Type: application/json" \
    -d @"$CONFIG_FILE" 2>/dev/null)

http_code=$(echo "$response" | tail -n1)
body=$(echo "$response" | sed '$d')

if [ "$http_code" = "200" ] || [ "$http_code" = "201" ]; then
    echo "✓ Configuration imported successfully!"
    echo ""
    echo "Web search is now enabled with SearXNG"
    echo "  Engine: searxng"
    echo "  URL: http://searxng:8080/search?q=<query>"
    echo ""
    echo "Please refresh your Open-WebUI page to see the changes."
    exit 0
else
    echo "ERROR: Failed to import configuration (HTTP $http_code)"
    echo ""
    echo "Response:"
    echo "$body"
    echo ""

    if [ "$http_code" = "401" ] || [ "$http_code" = "403" ]; then
        echo "Authentication failed. Please check:"
        echo "  - API token is correct"
        echo "  - Token has admin privileges"
        echo "  - Token hasn't expired"
    fi

    exit 1
fi
