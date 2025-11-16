#!/bin/bash
# Initialize Open-WebUI web search configuration
# Fully automated: creates admin user, authenticates, imports config

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
CONFIG_FILE="$PROJECT_ROOT/config-templates/default-config.json"
WEBUI_URL="${WEBUI_URL:-http://localhost:11300}"
MAX_WAIT=60

# Default admin credentials (user should change after first login)
DEFAULT_ADMIN_NAME="${WEBUI_ADMIN_NAME:-admin}"
DEFAULT_ADMIN_EMAIL="${WEBUI_ADMIN_EMAIL:-admin@localhost}"
DEFAULT_ADMIN_PASSWORD="${WEBUI_ADMIN_PASSWORD:-admin123}"

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

log_info() {
    echo "$1"
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

# Check if users already exist
DB_PATH="$PROJECT_ROOT/data/open-webui/webui.db"
if [ -f "$DB_PATH" ]; then
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

    if [ "$USER_COUNT" != "0" ]; then
        log_verbose "Users already exist (${USER_COUNT} users)"
        log_info "✓ Environment variables will handle web search config"
        exit 0
    fi
fi

# No users exist - create default admin and import config
log_verbose "No users found, creating default admin..."

# Try to create admin user via signup API
signup_response=$(curl -s -w "\n%{http_code}" -X POST \
    "$WEBUI_URL/api/v1/auths/signup" \
    -H "Content-Type: application/json" \
    -d "{\"name\":\"$DEFAULT_ADMIN_NAME\",\"email\":\"$DEFAULT_ADMIN_EMAIL\",\"password\":\"$DEFAULT_ADMIN_PASSWORD\"}" \
    2>/dev/null || echo -e "\n000")

signup_http_code=$(echo "$signup_response" | tail -n1)
signup_body=$(echo "$signup_response" | sed '$d')

if [ "$signup_http_code" != "200" ] && [ "$signup_http_code" != "201" ]; then
    log_verbose "Signup failed (HTTP $signup_http_code), checking if environment variables will handle config..."

    # If signup is disabled, environment variables should handle config on first boot
    if [ "$signup_http_code" = "403" ] || [ "$signup_http_code" = "401" ]; then
        log_info "✓ Signup disabled - environment variables will configure web search"
        exit 0
    fi

    log_error "Failed to create admin user (HTTP $signup_http_code)"
    log_verbose "Response: $signup_body"
    exit 1
fi

# Extract token from signup response
TOKEN=$(echo "$signup_body" | grep -o '"token":"[^"]*"' | cut -d'"' -f4)

if [ -z "$TOKEN" ]; then
    log_error "Failed to extract token from signup response"
    log_verbose "Response: $signup_body"
    exit 1
fi

log_verbose "Admin user created successfully"
log_verbose "Token: ${TOKEN:0:20}..."

# Import configuration using the token
log_verbose "Importing configuration..."

import_response=$(curl -s -w "\n%{http_code}" -X POST \
    "$WEBUI_URL/api/v1/configs/import" \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" \
    -d @"$CONFIG_FILE" \
    2>/dev/null || echo -e "\n000")

import_http_code=$(echo "$import_response" | tail -n1)
import_body=$(echo "$import_response" | sed '$d')

if [ "$import_http_code" = "200" ] || [ "$import_http_code" = "201" ]; then
    if ! $VERBOSE; then
        echo "✓ Web search configured"
    else
        echo "Web search configuration imported successfully!"
        echo "  Engine: SearXNG"
        echo "  URL: http://searxng:8080/search?q=<query>"
    fi

    # Display admin credentials
    echo ""
    echo "════════════════════════════════════════════════════════════════"
    echo "  Default Admin Account Created"
    echo "════════════════════════════════════════════════════════════════"
    echo ""
    echo "  Email:    $DEFAULT_ADMIN_EMAIL"
    echo "  Password: $DEFAULT_ADMIN_PASSWORD"
    echo ""
    echo "  ⚠️  IMPORTANT: Change this password after first login!"
    echo "     Go to Settings → Account → Change Password"
    echo ""
    echo "════════════════════════════════════════════════════════════════"
    echo ""

    exit 0
else
    log_error "Failed to import configuration (HTTP $import_http_code)"
    echo ""
    echo "API Response:"
    echo "$import_body"
    echo ""

    echo ""
    echo "Admin user was created but config import failed."
    echo "You can import manually:"
    echo "  1. Login: $DEFAULT_ADMIN_EMAIL / $DEFAULT_ADMIN_PASSWORD"
    echo "  2. Settings → Admin Settings → Import Config"
    echo "  3. Upload: $CONFIG_FILE"
    echo ""

    exit 1
fi
