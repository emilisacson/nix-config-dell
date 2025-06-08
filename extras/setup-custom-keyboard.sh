#!/usr/bin/env bash
# Load custom XKB configuration for Ctrl key behavior

# Detect current system to determine correct keyboard configuration
SYSTEM_SPECS_FILE="$HOME/.nix-config/system-specs.json"

if [ -f "$SYSTEM_SPECS_FILE" ]; then
    SYSTEM_ID=$(jq -r '.system_id // "unknown"' "$SYSTEM_SPECS_FILE")
else
    SYSTEM_ID="unknown"
fi

# Set keyboard configuration based on detected system
case "$SYSTEM_ID" in
    "laptop-20Y30016MX-hybrid")
        PRIMARY_LAYOUT="se+svdvorak"
        SECONDARY_LAYOUT="se"
        echo "Detected ThinkPad - using SVDVORAK as primary layout"
        ;;
    "laptop-Latitude_7410-intel")
        PRIMARY_LAYOUT="se"
        SECONDARY_LAYOUT="se+svdvorak"
        echo "Detected Dell Latitude - using Swedish QWERTY as primary layout"
        ;;
    *)
        PRIMARY_LAYOUT="se"
        SECONDARY_LAYOUT="se+svdvorak"
        echo "Unknown system ($SYSTEM_ID) - using Swedish QWERTY as default"
        ;;
esac

# Wait for GNOME to fully load
sleep 5

# Clear any existing XKB state that might interfere
echo "Clearing previous XKB state..."
setxkbmap -option '' 2>/dev/null || true

# Ensure we're starting from the correct base layout
echo "Setting base layout to $PRIMARY_LAYOUT..."
gsettings set org.gnome.desktop.input-sources sources "[('xkb', '$PRIMARY_LAYOUT'), ('xkb', '$SECONDARY_LAYOUT')]"
gsettings set org.gnome.desktop.input-sources current 0

# Wait for GNOME to apply the layout
sleep 3

# Force the layout change using setxkbmap as well (for immediate effect)
echo "Forcing layout application with setxkbmap..."
if [[ "$PRIMARY_LAYOUT" == "se+svdvorak" ]]; then
    setxkbmap -layout se -variant svdvorak
elif [[ "$PRIMARY_LAYOUT" == "se" ]]; then
    setxkbmap -layout se
fi

# Wait for layout to be applied
sleep 2

# Apply custom XKB configuration whenever SVDVORAK is available (primary or secondary)
if [[ "$PRIMARY_LAYOUT" == "se+svdvorak" || "$SECONDARY_LAYOUT" == "se+svdvorak" ]]; then
    echo "Applying custom XKB configuration for SVDVORAK support (Ctrl switches to Swedish QWERTY)..."
    
    # GNOME/Wayland approach: Use separate input sources with custom XKB overlay
    echo "Setting up separate input sources with custom Ctrl behavior..."
    gsettings set org.gnome.desktop.input-sources sources "[('xkb', '$PRIMARY_LAYOUT'), ('xkb', '$SECONDARY_LAYOUT')]"
    gsettings set org.gnome.desktop.input-sources xkb-options "['terminate:ctrl_alt_bksp', 'lv3:ralt_switch']"
    
    # Wait for GNOME to apply the settings
    sleep 3
    
    # Apply the original custom XKB layout that provides Ctrl switching behavior
    echo "Loading custom XKB layout for Ctrl key behavior..."
    xkbcomp -v -w0 ~/.nix-config/extras/custom-keyboard-layout.xkb $DISPLAY 2> /tmp/xkb_error.log
    if [ $? -ne 0 ]; then
        echo "Warning: Failed to load custom XKB layout. See /tmp/xkb_error.log"
        echo "Falling back to standard layout switching with Super+Space"
    else
        echo "Custom XKB layout loaded successfully."
        echo "When in SVDVORAK: Hold Ctrl while typing to temporarily use Swedish QWERTY positions"
        echo "Use Super+Space to switch between SVDVORAK and Swedish layouts"
    fi
    
    echo "Custom keyboard configuration completed."
else
    echo "Skipping custom XKB configuration (SVDVORAK not available)."
    # Clear any XKB options to ensure clean behavior
    echo "Clearing XKB options for clean experience..."
    gsettings set org.gnome.desktop.input-sources xkb-options "[]"
fi

# Force GNOME to reload input sources by toggling and setting them again
echo "Forcing GNOME to reload input sources..."
gsettings set org.gnome.desktop.input-sources sources "[]"
sleep 1
gsettings set org.gnome.desktop.input-sources sources "[('xkb', '$PRIMARY_LAYOUT'), ('xkb', '$SECONDARY_LAYOUT')]"
gsettings set org.gnome.desktop.input-sources current 0

# Wait for settings to apply
sleep 3

# Verify the layout using gsettings instead of setxkbmap (more reliable under Wayland)
current_sources=$(gsettings get org.gnome.desktop.input-sources sources)
current_index=$(gsettings get org.gnome.desktop.input-sources current)
actual_layout=$(setxkbmap -query | grep layout | awk '{print $2}' 2>/dev/null || echo "unknown")
actual_variant=$(setxkbmap -query | grep variant | awk '{print $2}' 2>/dev/null || echo "")

echo "Current input sources: $current_sources"
echo "Current active source index: $current_index"
echo "Actual keyboard layout (setxkbmap): $actual_layout"
echo "Actual keyboard variant (setxkbmap): $actual_variant"

# Check if we're using the combined layout approach
if [[ "$current_sources" == *"'se+svdvorak,se'"* ]]; then
    echo "Combined layout detected. Checking group configuration..."
    if [[ "$actual_layout" == "se" ]]; then
        if [[ "$PRIMARY_LAYOUT" == "se+svdvorak" && "$actual_variant" == *"svdvorak"* ]]; then
            echo "SVDVORAK group active with Ctrl switching to Swedish - configuration successful."
            notify-send "Custom keyboard layout" "SVDVORAK with Ctrl switching to Swedish active" --urgency=normal
        elif [[ "$PRIMARY_LAYOUT" == "se" && "$actual_variant" == "" ]]; then
            echo "Swedish group active with Ctrl switching to SVDVORAK - configuration successful."
            notify-send "Custom keyboard layout" "Swedish with Ctrl switching to SVDVORAK active" --urgency=normal
        else
            echo "Combined layout configured but unexpected group/variant active."
            notify-send "Keyboard layout" "Combined layout configured - use Ctrl to switch groups" --urgency=normal
        fi
    else
        echo "Warning: Combined layout set but unexpected base layout: $actual_layout"
        notify-send "Keyboard layout" "Layout configuration may need adjustment" --urgency=normal
    fi
elif [[ "$current_sources" == *"'$PRIMARY_LAYOUT'"* ]] && [[ "$actual_layout" == *"se"* || "$actual_layout" == "se" ]]; then
    if [[ "$PRIMARY_LAYOUT" == "se+svdvorak" || "$SECONDARY_LAYOUT" == "se+svdvorak" ]]; then
        echo "Keyboard layout with SVDVORAK Ctrl overlay loaded successfully."
        notify-send "Custom keyboard layout" "$PRIMARY_LAYOUT with SVDVORAK Ctrl overlay available" --urgency=normal
    else
        echo "Standard keyboard layout loaded successfully."
        notify-send "Keyboard layout" "$PRIMARY_LAYOUT loaded successfully" --urgency=normal
    fi
elif [[ "$current_sources" == *"'$PRIMARY_LAYOUT'"* ]] && [[ "$actual_layout" == *"us"* ]]; then
    echo "Warning: gsettings shows correct layout but setxkbmap still shows US. Layout may not be fully applied."
    notify-send "Keyboard layout" "Layout configured in settings but may not be active yet - try switching layouts manually" --urgency=normal
else
    echo "Warning: Unexpected layout configuration."
    echo "Current sources: $current_sources"
    echo "Actual layout: $actual_layout"
    notify-send "Keyboard layout" "Layout verification failed - configuration may need adjustment" --urgency=normal
fi
