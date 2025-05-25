#!/usr/bin/env bash
# Load custom XKB configuration for Ctrl key behavior

# Wait for GNOME to fully load
sleep 5

# Clear any existing XKB state that might interfere
echo "Clearing previous XKB state..."
setxkbmap -option '' 2>/dev/null || true

# Ensure we're starting from the correct base layout
echo "Setting base layout to svdvorak..."
gsettings set org.gnome.desktop.input-sources sources "[('xkb', 'se+svdvorak'), ('xkb', 'se')]"
gsettings set org.gnome.desktop.input-sources current 0

# Wait for GNOME to apply the layout
sleep 2

# Compile and load the custom XKB configuration
echo "Loading custom keyboard layout for Ctrl key behavior..."
xkbcomp -v -w0 ~/.nix-config/extras/custom-keyboard-layout.xkb $DISPLAY 2> /tmp/xkb_error.log

# Check for errors
if [ $? -ne 0 ]; then
    echo "Failed to load custom keyboard layout. See /tmp/xkb_error.log for details."
    notify-send "Custom keyboard layout" "Failed to load SVDVORAK + Swedish QWERTY with Ctrl key overlay. Check /tmp/xkb_error.log" --urgency=critical
    exit 1
fi

# Verify the layout loaded correctly
current_layout=$(setxkbmap -query | grep layout | awk '{print $2}')
if [[ "$current_layout" == *"se"* ]]; then
    echo "Custom keyboard layout loaded successfully."
    notify-send "Custom keyboard layout" "SVDVORAK + Swedish QWERTY with Ctrl key overlay loaded successfully" --urgency=normal
else
    echo "Warning: Layout verification failed. Current layout: $current_layout"
    notify-send "Custom keyboard layout" "Layout loaded but verification failed" --urgency=normal
fi
