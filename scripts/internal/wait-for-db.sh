#!/bin/bash
# Wait for Open-WebUI database to be ready
# This script polls for the database file and verifies it's accessible

set -e

# Configuration
MAX_WAIT=60
CHECK_INTERVAL=2
DB_PATH="data/open-webui/webui.db"

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

# Wait for database
elapsed=0
log_verbose "Waiting for Open-WebUI database..."

while [ $elapsed -lt $MAX_WAIT ]; do
    # Check if database file exists
    if [ -f "$DB_PATH" ]; then
        log_verbose "Database file found, verifying accessibility..."

        # Try to query the database to ensure it's ready
        if docker run --rm -v "$(pwd)/data/open-webui:/data" python:3.11-slim \
           python3 -c "import sqlite3; sqlite3.connect('/data/webui.db').cursor().execute('SELECT 1')" 2>/dev/null; then

            log_verbose "Database is ready!"
            exit 0
        fi

        log_verbose "Database file exists but not yet ready, waiting..."
    fi

    sleep $CHECK_INTERVAL
    elapsed=$((elapsed + CHECK_INTERVAL))

    if $VERBOSE; then
        echo -n "."
    fi
done

# Timeout reached
echo "" >&2
echo "ERROR: Database not ready after ${MAX_WAIT} seconds" >&2
echo "Check container logs: docker compose logs open-webui" >&2
exit 1
