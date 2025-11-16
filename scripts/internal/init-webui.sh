#!/bin/bash
# Initialize Open-WebUI web search configuration
# Configures SearXNG integration in the Open-WebUI database

set -e

DB_PATH="data/open-webui/webui.db"

# Parse arguments
VERBOSE=false
if [ "$1" = "--verbose" ]; then
    VERBOSE=true
fi

# Check if database exists
if [ ! -f "$DB_PATH" ]; then
    echo "ERROR: Database not found at $DB_PATH" >&2
    echo "Start containers first: docker compose up -d" >&2
    exit 1
fi

# Check if already configured (idempotency)
if $VERBOSE; then
    echo "Checking if web search is already configured..."
fi

ALREADY_CONFIGURED=$(docker run --rm -v "$(pwd)/data/open-webui:/data" python:3.11-slim python3 << 'PYEOF'
import sqlite3
import json
import sys

try:
    conn = sqlite3.connect('/data/webui.db')
    cursor = conn.cursor()
    cursor.execute("SELECT data FROM config WHERE id = 1")
    row = cursor.fetchone()
    conn.close()

    if row:
        data = json.loads(row[0])
        if data.get('rag', {}).get('web', {}).get('search', {}).get('enable'):
            print("yes")
            sys.exit(0)

    print("no")
except:
    print("no")
PYEOF
)

if [ "$ALREADY_CONFIGURED" = "yes" ]; then
    if $VERBOSE; then
        echo "Web search already configured, skipping"
    fi
    exit 0
fi

# Configure web search
if $VERBOSE; then
    echo "Configuring web search in database..."
fi

docker run --rm -v "$(pwd)/data/open-webui:/data" python:3.11-slim python3 << 'PYEOF'
import sqlite3
import json
import sys

try:
    conn = sqlite3.connect('/data/webui.db')
    cursor = conn.cursor()

    cursor.execute("SELECT data FROM config WHERE id = 1")
    row = cursor.fetchone()

    if not row:
        print("ERROR: No config found. Database may not be initialized.", file=sys.stderr)
        sys.exit(1)

    data = json.loads(row[0])

    # Initialize nested structure
    if 'rag' not in data:
        data['rag'] = {}
    if 'web' not in data['rag']:
        data['rag']['web'] = {}
    if 'search' not in data['rag']['web']:
        data['rag']['web']['search'] = {}

    # Set web search configuration
    data['rag']['web']['search'].update({
        'enable': True,
        'engine': 'searxng',
        'searxng_query_url': 'http://searxng:8080/search?q=<query>',
        'result_count': 5,
        'concurrent_requests': 10,
        'trust_env': False,
        'bypass_embedding_and_retrieval': False,
        'bypass_web_loader': False,
        'domain': {'filter_list': []}
    })

    cursor.execute(
        "UPDATE config SET data = ?, updated_at = CURRENT_TIMESTAMP WHERE id = 1",
        (json.dumps(data),)
    )
    conn.commit()
    conn.close()

    print("SUCCESS")

except Exception as e:
    print(f"ERROR: {e}", file=sys.stderr)
    sys.exit(1)
PYEOF

if [ $? -eq 0 ]; then
    if $VERBOSE; then
        echo "Restarting Open-WebUI to apply changes..."
    fi

    docker compose restart open-webui >/dev/null 2>&1

    if ! $VERBOSE; then
        echo "✓ Web search configured"
    else
        echo "Web search configuration complete!"
        echo "  Engine: SearXNG"
        echo "  URL: http://searxng:8080/search?q=<query>"
    fi

    exit 0
else
    echo "ERROR: Failed to configure web search" >&2
    exit 1
fi
