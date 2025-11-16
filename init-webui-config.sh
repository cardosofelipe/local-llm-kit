#!/bin/bash
# Local-LLM-Kit: Initialize Open-WebUI web search configuration
# Run this after first container start: ./init-webui-config.sh

echo "🔧 Initializing Open-WebUI web search configuration..."

docker run --rm -v $(pwd)/data/open-webui:/data python:3.11-slim python3 << 'PYEOF'
import sqlite3
import json
import sys

try:
    conn = sqlite3.connect('/data/webui.db')
    cursor = conn.cursor()
    
    cursor.execute("SELECT * FROM config WHERE id = 1")
    row = cursor.fetchone()
    
    if not row:
        print("❌ No config found. Please start Open-WebUI first.")
        sys.exit(1)
        
    data = json.loads(row[1])
    
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
    
    print("✅ Web search configured successfully!")
    print("   Engine: searxng")
    print("   URL: http://searxng:8080/search?q=<query>")
    
except Exception as e:
    print(f"❌ Error: {e}")
    sys.exit(1)
PYEOF

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ Configuration complete! Restarting Open-WebUI..."
    docker compose restart open-webui
    echo ""
    echo "🎉 Done! Web search is now enabled by default."
    echo "   Visit: http://localhost:11300/admin/settings/web to verify"
else
    echo ""
    echo "❌ Configuration failed. Please check the error above."
    exit 1
fi
