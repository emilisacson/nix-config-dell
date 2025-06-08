#!/usr/bin/env bash
# Toggle the smart layout switcher on/off

if pgrep -f smart-layout-switcher.sh > /dev/null; then
    echo "Stopping smart layout switcher..."
    pkill -f smart-layout-switcher.sh
    pkill xbindkeys || true
    gsettings reset org.gnome.desktop.wm.keybindings switch-input-source
    notify-send "Smart Layout Switcher" "Disabled - Using default Super+Space behavior"
else
    echo "Starting smart layout switcher..."
    ~/.nix-config/extras/smart-layout-switcher.sh &
    notify-send "Smart Layout Switcher" "Enabled - Intelligent layout switching active"
fi
