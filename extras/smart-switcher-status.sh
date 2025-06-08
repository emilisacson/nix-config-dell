#!/usr/bin/env bash
# Check smart layout switcher status

echo "=== Smart Layout Switcher Status ==="

if pgrep -f smart-layout-switcher.sh > /dev/null; then
    echo "✅ Smart switcher is RUNNING"
    echo "PID: $(pgrep -f smart-layout-switcher.sh)"
else
    echo "❌ Smart switcher is NOT RUNNING"
fi

if pgrep xbindkeys > /dev/null; then
    echo "✅ xbindkeys is RUNNING"
    echo "PID: $(pgrep xbindkeys)"
else
    echo "❌ xbindkeys is NOT RUNNING"
fi

echo ""
echo "Current layout: $(setxkbmap -query | grep -E 'layout|variant')"
echo ""
echo "Keyboard sources: $(gsettings get org.gnome.desktop.input-sources sources)"
echo "Current source: $(gsettings get org.gnome.desktop.input-sources current)"

# Check Super+Space keybinding status
current_binding=$(gsettings get org.gnome.desktop.wm.keybindings switch-input-source)
if [[ "$current_binding" == "[]" ]]; then
    echo "🔒 Super+Space is intercepted by smart switcher"
else
    echo "🔓 Super+Space uses default GNOME behavior: $current_binding"
fi

# Check log file
log_file="$HOME/.cache/smart-layout-switcher.log"
if [[ -f "$log_file" ]]; then
    echo ""
    echo "=== Recent Log Entries ==="
    tail -5 "$log_file"
fi
