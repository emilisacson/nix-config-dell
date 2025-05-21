#!/usr/bin/env bash
# Load custom XKB configuration for Ctrl key behavior

# Wait a few seconds for GNOME to fully load
sleep 5

# Compile and load the custom XKB configuration
echo "Loading custom keyboard layout for Ctrl key behavior..."
xkbcomp -v -w0 ~/.nix-config/extras/custom-keyboard-layout.xkb $DISPLAY 2> /tmp/xkb_error.log

# Check for errors
if [ $? -ne 0 ]; then
    echo "Failed to load custom keyboard layout. See /tmp/xkb_error.log for details."
    notify-send "Custom keyboard layout" "Failed to load SVDVORAK + Swedish QWERTY with Ctrl key overlay. Check /tmp/xkb_error.log"
    exit 1
fi

# Notify the user
echo "Custom keyboard layout loaded successfully."
notify-send "Custom keyboard layout" "SVDVORAK + Swedish QWERTY with Ctrl key overlay loaded"
