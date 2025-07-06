#!/bin/sh

# Keyboard handler for Control+Arrow navigation
# Monitors for Control+Left/Right and sends browser navigation commands

export DISPLAY=:1

while true; do
    # Wait for Control+Left (keycode 113+37)
    if xev -root -event keyboard | grep -q "keycode 37.*state 0x4"; then
        echo "Control+Left detected - sending browser back"
        xdotool key --window $(xdotool search --class chromium | head -1) alt+Left
    fi
    
    # Wait for Control+Right (keycode 113+39) 
    if xev -root -event keyboard | grep -q "keycode 39.*state 0x4"; then
        echo "Control+Right detected - sending browser forward"
        xdotool key --window $(xdotool search --class chromium | head -1) alt+Right
    fi
    
    sleep 0.1
done