#!/bin/sh

# Chrome startup script that bypasses crashpad issues
# Use display :1 consistently
export DISPLAY=:1
export CHROME_DEVEL_SANDBOX=""
export CHROME_NO_SANDBOX=1

echo "Starting Chrome on display $DISPLAY"

# Kill any existing Chrome processes
pkill -f chromium-browser 2>/dev/null || true

# Wait a moment
sleep 2

# Start Chrome with minimal flags and profile recovery options
cd /home/chrome
exec chromium-browser \
    --no-sandbox \
    --disable-dev-shm-usage \
    --disable-gpu \
    --disable-software-rasterizer \
    --disable-background-timer-throttling \
    --disable-backgrounding-occluded-windows \
    --disable-renderer-backgrounding \
    --disable-extensions \
    --disable-sync \
    --disable-translate \
    --disable-default-apps \
    --no-first-run \
    --no-default-browser-check \
    --disable-component-extensions-with-background-pages \
    --disable-background-networking \
    --disable-breakpad \
    --disable-crash-reporter \
    --disable-client-side-phishing-detection \
    --disable-web-security \
    --disable-session-crashed-bubble \
    --disable-infobars \
    --hide-crash-restore-bubble \
    --disable-features=VizDisplayCompositor \
    --disable-logging \
    --silent-debugger-extension-api \
    --user-data-dir=/home/chrome/.config/chromium \
    --window-size=1280,1024 \
    --start-maximized \
    --disable-session-crashed-bubble \
    --disable-infobars \
    --disable-restore-session-state \
    --disable-background-mode \
    --new-window \
    "${START_URL:-https://google.com}"