#!/bin/sh

echo "Starting optimized VNC container..."

# Function to wait for service readiness instead of arbitrary sleeps
wait_for_service() {
    local service_name="$1"
    local check_command="$2"
    local max_attempts=30
    local attempt=0
    
    echo "Waiting for $service_name to be ready..."
    while [ $attempt -lt $max_attempts ]; do
        if eval "$check_command" >/dev/null 2>&1; then
            echo "$service_name is ready!"
            return 0
        fi
        sleep 0.1
        attempt=$((attempt + 1))
    done
    echo "WARNING: $service_name failed to start within 3 seconds"
    return 1
}

# Set display early
export DISPLAY=:1

# Start Xvfb immediately in background
echo "Starting Xvfb..."
Xvfb :1 -screen 0 1280x720x24 -ac +extension GLX +render -noreset &
XVFB_PID=$!

# Start window manager in parallel (doesn't need X to be fully ready)
echo "Starting openbox..."
openbox &
OPENBOX_PID=$!

# Wait for X server to be responsive
wait_for_service "Xvfb" "xdpyinfo -display :1"

# Start x11vnc as soon as X is ready
echo "Starting x11vnc..."
x11vnc -display :1 -nopw -listen 0.0.0.0 -rfbport 5900 -forever -shared -bg -o /var/log/x11vnc.log

# Start noVNC websocket proxy in parallel
echo "Starting noVNC..."
cd /usr/share/novnc && python3 -m websockify --web . 5901 localhost:5900 &
NOVNC_PID=$!

# Start download monitor in background
echo "Starting download monitor..."
/usr/local/bin/download-monitor.sh &
MONITOR_PID=$!

# Start file server for downloads
echo "Starting file server..."
cd /home/chrome/Downloads && python3 -m http.server 8080 &
FILESERVER_PID=$!

# Wait for VNC to be accepting connections
wait_for_service "VNC" "netstat -ln | grep :5900"

# Wait for noVNC to be ready
wait_for_service "noVNC" "netstat -ln | grep :5901"

echo "All services started successfully!"

# Start Chrome with optimized flags for better performance and lower memory usage
echo "Starting Chrome in kiosk mode with URL: ${START_URL:-https://google.com}"
exec chromium-browser \
  --no-sandbox \
  --disable-dev-shm-usage \
  --kiosk \
  --disable-extensions \
  --disable-translate \
  --disable-web-security \
  --disable-features=VizDisplayCompositor \
  --disable-infobars \
  --disable-session-crashed-bubble \
  --disable-restore-session-state \
  --disable-background-timer-throttling \
  --disable-backgrounding-occluded-windows \
  --disable-renderer-backgrounding \
  --disable-field-trial-config \
  --no-first-run \
  --no-default-browser-check \
  --disable-component-extensions-with-background-pages \
  --memory-pressure-off \
  --max_old_space_size=256 \
  --disable-background-networking \
  --disable-sync \
  --disable-default-apps \
  --disable-features=TranslateUI \
  --disable-ipc-flooding-protection \
  "${START_URL:-https://google.com}"