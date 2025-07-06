#!/bin/sh

# Download monitor script for browser containers
# Monitors Downloads directory and notifies session manager of new files

export DISPLAY=:1
DOWNLOADS_DIR="/home/chrome/Downloads"
SESSION_API_URL="${SESSION_API_URL:-http://host.docker.internal:3000}"

echo "Starting download monitor for session: ${SESSION_ID}"
echo "Monitoring directory: ${DOWNLOADS_DIR}"
echo "API URL: ${SESSION_API_URL}"

# Create downloads directory if it doesn't exist
mkdir -p "${DOWNLOADS_DIR}"

# Monitor downloads directory for new files
inotifywait -m -e create -e moved_to "${DOWNLOADS_DIR}" --format '%w%f' | while read file; do
    if [ -f "$file" ]; then
        filename=$(basename "$file")
        filesize=$(stat -c%s "$file" 2>/dev/null || echo "0")
        timestamp=$(date +%s)
        
        echo "New download detected: $filename ($filesize bytes)"
        
        # Notify session manager of new download
        if [ -n "$SESSION_ID" ] && [ -n "$SESSION_API_URL" ]; then
            curl -X POST "$SESSION_API_URL/download-notification" \
                -H "Content-Type: application/json" \
                -d "{
                    \"sessionId\": \"$SESSION_ID\",
                    \"filename\": \"$filename\",
                    \"filepath\": \"$file\",
                    \"filesize\": $filesize,
                    \"timestamp\": $timestamp
                }" \
                --max-time 5 \
                --silent || echo "Failed to notify session manager"
        fi
    fi
done