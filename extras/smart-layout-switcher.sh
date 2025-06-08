#!/usr/bin/env bash
# Smart Layout Switcher with Automatic Ctrl Overlay Management
# Intercepts Super+Space to provide intelligent layout switching

LOG_FILE="$HOME/.cache/smart-layout-switcher.log"
LOCK_FILE="/tmp/smart-layout-switcher.lock"

# Logging function
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

# Cleanup function
cleanup() {
    log_message "Smart layout switcher stopping..."
    rm -f "$LOCK_FILE"
    # Restore normal Super+Space behavior
    gsettings reset org.gnome.desktop.wm.keybindings switch-input-source
    exit 0
}

# Set up signal handlers
trap cleanup EXIT INT TERM

# Check if already running
if [[ -f "$LOCK_FILE" ]]; then
    existing_pid=$(cat "$LOCK_FILE")
    if kill -0 "$existing_pid" 2>/dev/null; then
        echo "Smart layout switcher already running with PID $existing_pid"
        exit 1
    else
        rm -f "$LOCK_FILE"
    fi
fi

# Create lock file
echo $$ > "$LOCK_FILE"

log_message "Smart layout switcher starting..."

# Function to get current layout index
get_current_layout() {
    local raw_output=$(gsettings get org.gnome.desktop.input-sources current 2>/dev/null || echo "0")
    # Extract just the number from "uint32 0" format
    echo "$raw_output" | sed 's/uint32 //' | tr -d ' '
}

# Function to get layout sources
get_layout_sources() {
    gsettings get org.gnome.desktop.input-sources sources 2>/dev/null
}

# Function to switch to next layout
switch_to_next_layout() {
    local current=$(get_current_layout)
    
    # Use setxkbmap directly instead of relying on GNOME's gsettings
    if [[ $current -eq 0 ]]; then
        # Currently Swedish QWERTY, switch to SVDVORAK
        log_message "Switching from Swedish QWERTY to SVDVORAK"
        setxkbmap -layout se -variant svdvorak -option "terminate:ctrl_alt_bksp,lv3:ralt_switch" 2>/dev/null
        gsettings set org.gnome.desktop.input-sources current 1
        return 1
    else
        # Currently SVDVORAK, switch to Swedish QWERTY
        log_message "Switching from SVDVORAK to Swedish QWERTY"
        setxkbmap -layout se -variant "" -option "terminate:ctrl_alt_bksp,lv3:ralt_switch" 2>/dev/null
        gsettings set org.gnome.desktop.input-sources current 0
        return 0
    fi
}

# Function to apply ctrl overlay for SVDVORAK
apply_ctrl_overlay() {
    log_message "Applying Ctrl overlay for SVDVORAK..."
    
    # SVDVORAK is already set by switch_to_next_layout()
    # Now apply ONLY the Ctrl overlay by loading the custom XKB layout on top
    if [[ -f "$HOME/.nix-config/extras/custom-keyboard-layout.xkb" ]]; then
        xkbcomp "$HOME/.nix-config/extras/custom-keyboard-layout.xkb" "$DISPLAY" 2>/dev/null
        log_message "Custom XKB layout with Ctrl overlay loaded on top of SVDVORAK"
    else
        log_message "Warning: Custom XKB layout file not found, using basic SVDVORAK"
    fi
}

# Function to remove ctrl overlay for Swedish QWERTY
remove_ctrl_overlay() {
    log_message "Removing Ctrl overlay for Swedish QWERTY..."
    
    # Swedish QWERTY is already set by switch_to_next_layout()
    # No additional setup needed - standard Swedish layout should work correctly
    
    log_message "Swedish QWERTY layout active with normal Ctrl functionality"
}

# Function to handle layout change
handle_layout_change() {
    local new_layout_index=$1
    local sources=$(get_layout_sources)
    
    # Convert layout index to pure number if it has uint32 prefix
    new_layout_index=$(echo "$new_layout_index" | sed 's/uint32 //' | tr -d ' ')
    
    log_message "Handling layout change: index=$new_layout_index, sources=$sources"
    
    # Determine which layout is now active based on the sources order and index
    if [[ $sources == *"('xkb', 'se')"* ]] && [[ $sources == *"('xkb', 'se+svdvorak')"* ]]; then
        # We have both layouts - determine which is at which index
        if [[ $sources =~ \[\(\'xkb\',\ \'se\'\),.*\(\'xkb\',\ \'se\+svdvorak\'\) ]]; then
            # Swedish QWERTY is first (index 0), SVDVORAK is second (index 1)
            if [[ $new_layout_index -eq 0 ]]; then
                log_message "Swedish QWERTY active (index 0) - disabling Ctrl overlay"
                remove_ctrl_overlay
                notify-send "Layout: Swedish QWERTY" "Ctrl overlay disabled" -t 2000 -u low
            else
                log_message "SVDVORAK active (index 1) - enabling Ctrl overlay"
                apply_ctrl_overlay
                notify-send "Layout: SVDVORAK" "Ctrl overlay enabled (Ctrl+C/V/X/Z at Swedish positions)" -t 2000 -u low
            fi
        elif [[ $sources =~ \[\(\'xkb\',\ \'se\+svdvorak\'\),.*\(\'xkb\',\ \'se\'\) ]]; then
            # SVDVORAK is first (index 0), Swedish QWERTY is second (index 1)
            if [[ $new_layout_index -eq 0 ]]; then
                log_message "SVDVORAK active (index 0) - enabling Ctrl overlay"
                apply_ctrl_overlay
                notify-send "Layout: SVDVORAK" "Ctrl overlay enabled (Ctrl+C/V/X/Z at Swedish positions)" -t 2000 -u low
            else
                log_message "Swedish QWERTY active (index 1) - disabling Ctrl overlay"
                remove_ctrl_overlay
                notify-send "Layout: Swedish QWERTY" "Ctrl overlay disabled" -t 2000 -u low
            fi
        fi
    else
        log_message "Warning: Expected dual layout setup not found"
    fi
}

# Function to intercept Super+Space
intercept_super_space() {
    log_message "Setting up Super+Space interception..."
    
    # Disable the default Super+Space behavior temporarily
    gsettings set org.gnome.desktop.wm.keybindings switch-input-source "[]"
    
    # Use xbindkeys to capture Super+Space
    cat > /tmp/xbindkeysrc << 'EOF'
# Smart layout switcher - Super+Space
"echo switch > /tmp/layout_switch_trigger"
  Mod4 + space
EOF
    
    # Start xbindkeys with our config
    xbindkeys -f /tmp/xbindkeysrc &
    local xbindkeys_pid=$!
    
    log_message "xbindkeys started with PID $xbindkeys_pid"
    
    # Give xbindkeys a moment to initialize
    sleep 1
    
    # Monitor for switch trigger
    while true; do
        if [[ -f /tmp/layout_switch_trigger ]]; then
            rm -f /tmp/layout_switch_trigger
            
            log_message "Super+Space triggered - switching layout"
            
            # Perform the layout switch
            switch_to_next_layout
            local new_layout=$?
            
            # Handle the overlay based on new layout
            sleep 0.2  # Brief delay to let layout switch settle
            handle_layout_change $new_layout
        fi
        
        sleep 0.1
    done
}

# Main execution
log_message "Initializing smart layout switcher..."

# Check if required tools are available
if ! command -v xbindkeys &> /dev/null; then
    log_message "Error: xbindkeys not found. Please install it first."
    echo "Error: xbindkeys is required but not installed."
    echo "On Fedora: sudo dnf install xbindkeys"
    exit 1
fi

# Get initial layout state and set up overlay accordingly
initial_layout=$(get_current_layout)
log_message "Initial layout index: $initial_layout"
handle_layout_change $initial_layout

# Start the interception
intercept_super_space
