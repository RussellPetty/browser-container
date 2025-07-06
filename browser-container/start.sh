#!/bin/sh

echo "Starting VNC container..."

# Start Xvfb
echo "Starting Xvfb..."
Xvfb :1 -screen 0 1280x720x24 -ac +extension GLX +render -noreset &
export DISPLAY=:1

# Wait for X server
sleep 3

# Start x11vnc
echo "Starting x11vnc..."
x11vnc -display :1 -nopw -listen 0.0.0.0 -rfbport 5900 -forever -shared -cursor most -buttonmap 321 -nomodtweak -noxrecord -noxfixes -noxdamage &

# Start window manager
echo "Starting openbox..."
openbox &

# Wait a bit more
sleep 2

# Start noVNC
echo "Starting noVNC..."
cd /usr/share/novnc && python3 -m websockify --web . 5901 localhost:5900 &

# Wait for services to start
sleep 3

# Start keyboard handler for Control+Arrow navigation
echo "Starting keyboard handler..."
/keyboard-handler.sh &

# Start Chrome in true kiosk mode
echo "Starting Chrome in kiosk mode with URL: ${START_URL:-https://google.com}"
exec chromium-browser --no-sandbox --disable-dev-shm-usage \
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
  "${START_URL:-https://google.com}"