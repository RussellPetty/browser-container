#!/bin/sh

# Chrome Profile Initialization Script
# This script ensures the Chrome profile directory is properly initialized
# for volume mounts and has correct permissions

PROFILE_DIR="/home/chrome/.config/chromium"
DOWNLOADS_DIR="/home/chrome/Downloads"
TEMPLATE_DIR="/usr/local/share/chrome-template"

echo "Initializing Chrome profile directory: $PROFILE_DIR"

# Create directories if they don't exist
mkdir -p "$PROFILE_DIR"
mkdir -p "$DOWNLOADS_DIR"

# Always start with a clean profile approach for reliability
echo "Using clean profile template approach..."

# Clean up any existing problematic files first
rm -f "$PROFILE_DIR/SingletonLock" 2>/dev/null || true
rm -f "$PROFILE_DIR/SingletonCookie" 2>/dev/null || true
rm -f "$PROFILE_DIR/SingletonSocket" 2>/dev/null || true
rm -f "$PROFILE_DIR/.org.chromium.Chromium."* 2>/dev/null || true
rm -rf /tmp/.org.chromium.Chromium.* 2>/dev/null || true

# Clean up database lock files
find "$PROFILE_DIR" -name "LOCK" -type f -delete 2>/dev/null || true
find "$PROFILE_DIR" -name "*.tmp" -type f -delete 2>/dev/null || true
find "$PROFILE_DIR" -name "*.lock" -type f -delete 2>/dev/null || true
find "$PROFILE_DIR" -name "*-journal" -type f -delete 2>/dev/null || true

# Remove crash reports and caches
rm -rf "$PROFILE_DIR/Crash Reports" 2>/dev/null || true
rm -rf "$PROFILE_DIR/GPUCache" 2>/dev/null || true
rm -rf "$PROFILE_DIR/GrShaderCache" 2>/dev/null || true
rm -rf "$PROFILE_DIR/ShaderCache/GPUCache" 2>/dev/null || true

# Check if we need to initialize or repair the profile
if [ ! -f "$PROFILE_DIR/Default/Preferences" ] || ! python3 -m json.tool "$PROFILE_DIR/Default/Preferences" > /dev/null 2>&1; then
    echo "Initializing clean profile from template..."
    
    # Create directory structure
    mkdir -p "$PROFILE_DIR/Default"
    mkdir -p "$PROFILE_DIR/Default/Local Storage"
    mkdir -p "$PROFILE_DIR/Default/Session Storage"
    mkdir -p "$PROFILE_DIR/Default/IndexedDB"
    mkdir -p "$PROFILE_DIR/Default/databases"
    mkdir -p "$PROFILE_DIR/ShaderCache"
    
    # Copy clean template files
    if [ -f "$TEMPLATE_DIR/Default/Preferences" ]; then
        cp "$TEMPLATE_DIR/Default/Preferences" "$PROFILE_DIR/Default/Preferences"
    else
        # Fallback minimal preferences
        cat > "$PROFILE_DIR/Default/Preferences" << 'EOF'
{
  "browser": {
    "check_default_browser": false,
    "has_seen_welcome_page": true
  },
  "profile": {
    "default_content_setting_values": {
      "notifications": 2
    },
    "exit_type": "Normal",
    "exited_cleanly": true
  },
  "extensions": {
    "settings": {}
  }
}
EOF
    fi
    
    if [ -f "$TEMPLATE_DIR/Local State" ]; then
        cp "$TEMPLATE_DIR/Local State" "$PROFILE_DIR/Local State"
    else
        # Fallback minimal local state
        cat > "$PROFILE_DIR/Local State" << 'EOF'
{
  "browser": {
    "enabled_labs_experiments": []
  },
  "profile": {
    "info_cache": {},
    "last_used": "Default"
  }
}
EOF
    fi
    
    # Mark as initialized
    touch "$PROFILE_DIR/First Run"
    
    echo "Clean profile initialized successfully"
else
    echo "Profile exists and is valid, performing standard cleanup..."
fi

# Ensure correct ownership (chrome user is UID 1000)
chown -R chrome:chrome "$PROFILE_DIR"
chown -R chrome:chrome "$DOWNLOADS_DIR"

# Set proper permissions
chmod -R 755 "$PROFILE_DIR"
chmod -R 755 "$DOWNLOADS_DIR"

# Validate profile integrity
if [ ! -w "$PROFILE_DIR" ]; then
    echo "ERROR: Profile directory is not writable by chrome user"
    exit 1
fi

echo "Profile initialization completed successfully"
exit 0