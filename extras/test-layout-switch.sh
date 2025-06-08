#!/usr/bin/env bash
# Manual layout switching for testing the smart switcher
# This simulates what happens when Super+Space is pressed

echo "=== Manual Layout Switch Test ==="

# Get current state
current=$(gsettings get org.gnome.desktop.input-sources current | sed 's/uint32 //' | tr -d ' ')
sources=$(gsettings get org.gnome.desktop.input-sources sources)

echo "Current layout index: $current"
echo "Available sources: $sources"

# Trigger the switch (same mechanism as Super+Space)
echo "Triggering layout switch..."
echo "switch" > /tmp/layout_switch_trigger

# Wait and check result
sleep 1
new_current=$(gsettings get org.gnome.desktop.input-sources current | sed 's/uint32 //' | tr -d ' ')

echo "New layout index: $new_current"

# Show the layout names
if [[ $new_current -eq 0 ]]; then
    if [[ $sources =~ \[\(\'xkb\',\ \'se\'\) ]]; then
        echo "Active layout: Swedish QWERTY (Ctrl overlay disabled)"
    else
        echo "Active layout: SVDVORAK (Ctrl overlay enabled)"
    fi
else
    if [[ $sources =~ \[\(\'xkb\',\ \'se\'\) ]]; then
        echo "Active layout: SVDVORAK (Ctrl overlay enabled)"
    else
        echo "Active layout: Swedish QWERTY (Ctrl overlay disabled)"
    fi
fi

echo ""
echo "Recent smart switcher activity:"
tail -3 ~/.cache/smart-layout-switcher.log
