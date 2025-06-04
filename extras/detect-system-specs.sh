#!/usr/bin/env bash
# System Specification Detection Script
# This script detects all system specifications and writes them to a JSON configuration file
# that can be used by Nix during build-time configuration.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="$(dirname "$SCRIPT_DIR")"
OUTPUT_FILE="$CONFIG_DIR/system-specs.json"

# Function to extract monitor panel ID from EDID or fallback methods
extract_panel_id() {
    local monitor_name="$1"
    local panel_id="$monitor_name"
    
    # Method 1: Try to read EDID from DRM
    for edid_path in /sys/class/drm/card*-$monitor_name/edid; do
        if [ -f "$edid_path" ] && [ -s "$edid_path" ]; then
            if command -v hexdump >/dev/null 2>&1; then
                # Read first 16 bytes of EDID which contain vendor/product info
                EDID_HEX=$(hexdump -C "$edid_path" 2>/dev/null | head -2 || true)
                if [ -n "$EDID_HEX" ]; then
                    # Extract vendor bytes (bytes 8-9) and product bytes (bytes 10-11)
                    # EDID format: bytes 8-9 are vendor ID, bytes 10-11 are product ID
                    VENDOR_BYTES=$(echo "$EDID_HEX" | sed -n '1p' | awk '{print $10 $11}' 2>/dev/null || echo "")
                    PRODUCT_BYTES=$(echo "$EDID_HEX" | sed -n '1p' | awk '{print $12 $13}' 2>/dev/null || echo "")
                    
                    if [ -n "$VENDOR_BYTES" ] && [ -n "$PRODUCT_BYTES" ]; then
                        # Convert vendor ID to 3-letter manufacturer code
                        # Vendor ID is stored as big-endian 16-bit value
                        VENDOR_CODE=$(printf "%s" "$VENDOR_BYTES" | \
                            sed 's/\(..\)\(..\)/\2\1/' | \
                            xxd -r -p 2>/dev/null | \
                            od -An -tx2 2>/dev/null | \
                            awk '{
                                val = strtonum("0x" $1);
                                c1 = int(val / 1024) % 32 + 64;
                                c2 = int(val / 32) % 32 + 64;
                                c3 = val % 32 + 64;
                                printf "%c%c%c", c1, c2, c3
                            }' 2>/dev/null || echo "")
                        
                        # Format product ID as hex
                        PRODUCT_HEX=$(printf "0x%s%s" "${PRODUCT_BYTES:0:2}" "${PRODUCT_BYTES:2:2}" || echo "0x00000000")
                        
                        if [ -n "$VENDOR_CODE" ] && [ "$VENDOR_CODE" != "" ] && [ ${#VENDOR_CODE} -eq 3 ]; then
                            panel_id="$VENDOR_CODE-$PRODUCT_HEX"
                            echo "$panel_id"
                            return
                        fi
                    fi
                fi
            fi
        fi
    done
    
    # Method 2: Try gdbus to get GNOME display config
    if command -v gdbus >/dev/null 2>&1 && [ -n "${DISPLAY:-}" ]; then
        DISPLAY_CONFIG=$(gdbus call --session --dest org.gnome.Mutter.DisplayConfig \
            --object-path /org/gnome/Mutter/DisplayConfig \
            --method org.gnome.Mutter.DisplayConfig.GetCurrentState 2>/dev/null || true)
        
        if [ -n "$DISPLAY_CONFIG" ]; then
            # Extract monitor info in format: ('eDP-1', 'AUO', '0x633d', '0x00000000')
            # We want field 2 (vendor) + field 4 (the 0x000... ID)
            MONITOR_DATA=$(echo "$DISPLAY_CONFIG" | grep -o "('$monitor_name'[^)]*)" | head -1 || echo "")
            if [ -n "$MONITOR_DATA" ]; then
                # Extract the vendor (2nd field) and the 0x000... (4th field)
                VENDOR=$(echo "$MONITOR_DATA" | sed "s/.*'$monitor_name', '\([^']*\)'.*/\1/" || echo "")
                PRODUCT_ID=$(echo "$MONITOR_DATA" | sed "s/.*'$monitor_name'[^']*'[^']*'[^']*'\([^']*\)'.*/\1/" || echo "")
                
                if [ -n "$VENDOR" ] && [ -n "$PRODUCT_ID" ] && [ "$PRODUCT_ID" != "$MONITOR_DATA" ]; then
                    panel_id="$VENDOR-$PRODUCT_ID"
                    echo "$panel_id"
                    return
                fi
            fi
        fi
    fi
    
    # Method 3: Try i2c EDID reading if available
    if command -v i2cget >/dev/null 2>&1; then
        # Try to find the i2c bus for this monitor
        for i2c_link in /sys/class/drm/card*-$monitor_name/ddc; do
            if [ -L "$i2c_link" ]; then
                I2C_BUS=$(readlink "$i2c_link" | grep -o 'i2c-[0-9]*' | cut -d'-' -f2 || echo "")
                if [ -n "$I2C_BUS" ]; then
                    # Try to read EDID header to check if device responds
                    if timeout 2 i2cget -y "$I2C_BUS" 0x50 0x00 2>/dev/null >/dev/null; then
                        # Read vendor/product bytes from EDID
                        VENDOR_BYTE1=$(timeout 1 i2cget -y "$I2C_BUS" 0x50 0x08 2>/dev/null || echo "")
                        VENDOR_BYTE2=$(timeout 1 i2cget -y "$I2C_BUS" 0x50 0x09 2>/dev/null || echo "")
                        PRODUCT_BYTE1=$(timeout 1 i2cget -y "$I2C_BUS" 0x50 0x0a 2>/dev/null || echo "")
                        PRODUCT_BYTE2=$(timeout 1 i2cget -y "$I2C_BUS" 0x50 0x0b 2>/dev/null || echo "")
                        
                        if [ -n "$VENDOR_BYTE1" ] && [ -n "$VENDOR_BYTE2" ] && [ -n "$PRODUCT_BYTE1" ] && [ -n "$PRODUCT_BYTE2" ]; then
                            # Convert to vendor code and product hex
                            VENDOR_VAL=$(( ($VENDOR_BYTE1 << 8) | $VENDOR_BYTE2 ))
                            VENDOR_CODE=$(printf "%c%c%c" \
                                $(( ($VENDOR_VAL >> 10) % 32 + 64 )) \
                                $(( ($VENDOR_VAL >> 5) % 32 + 64 )) \
                                $(( $VENDOR_VAL % 32 + 64 )) 2>/dev/null || echo "")
                            
                            PRODUCT_HEX=$(printf "0x%02x%02x" "$PRODUCT_BYTE1" "$PRODUCT_BYTE2" || echo "0x00000000")
                            
                            if [ -n "$VENDOR_CODE" ] && [ ${#VENDOR_CODE} -eq 3 ]; then
                                panel_id="$VENDOR_CODE-$PRODUCT_HEX"
                                echo "$panel_id"
                                return
                            fi
                        fi
                    fi
                fi
            fi
        done
    fi
    
    # Method 4: Known laptop model fallbacks
    if [ -f /sys/devices/virtual/dmi/id/sys_vendor ] && [ -f /sys/devices/virtual/dmi/id/product_name ]; then
        SYS_VENDOR=$(cat /sys/devices/virtual/dmi/id/sys_vendor 2>/dev/null || echo "")
        PRODUCT_NAME=$(cat /sys/devices/virtual/dmi/id/product_name 2>/dev/null || echo "")
        
        case "$SYS_VENDOR" in
            "Dell Inc.")
                case "$PRODUCT_NAME" in
                    "Latitude 7410"|"Latitude 7420"|"Latitude 5420"|"Latitude 5520")
                        # Dell Latitudes commonly use AUO panels
                        panel_id="AUO-0x00000000"
                        ;;
                    "XPS 13"*)
                        # XPS often uses Sharp panels
                        panel_id="SHP-0x00000000"
                        ;;
                    *)
                        # Generic Dell fallback
                        panel_id="AUO-0x00000000"
                        ;;
                esac
                ;;
            "Lenovo")
                # Lenovo commonly uses BOE or AUO
                panel_id="BOE-0x00000000"
                ;;
            "HP Inc."|"Hewlett-Packard")
                # HP commonly uses AUO
                panel_id="AUO-0x00000000"
                ;;
            *)
                # Generic fallback based on monitor name
                if [ "$monitor_name" = "eDP-1" ]; then
                    panel_id="AUO-0x00000000"
                else
                    panel_id="$monitor_name-0x00000000"
                fi
                ;;
        esac
        
        echo "$panel_id"
        return
    fi
    
    # Final fallback
    echo "$monitor_name"
}

echo "🔍 Detecting system specifications..."

# Initialize JSON structure
JSON_DATA="{}"

# Function to add data to JSON
add_to_json() {
    local key="$1"
    local value="$2"
    local value_type="${3:-string}"
    
    if [ "$value_type" = "object" ] || [ "$value_type" = "array" ]; then
        JSON_DATA=$(echo "$JSON_DATA" | jq --argjson val "$value" ". + {\"$key\": \$val}")
    elif [ "$value_type" = "number" ]; then
        JSON_DATA=$(echo "$JSON_DATA" | jq --argjson val "$value" ". + {\"$key\": \$val}")
    elif [ "$value_type" = "boolean" ]; then
        JSON_DATA=$(echo "$JSON_DATA" | jq --argjson val "$value" ". + {\"$key\": \$val}")
    else
        JSON_DATA=$(echo "$JSON_DATA" | jq --arg val "$value" ". + {\"$key\": \$val}")
    fi
}

# 1. SYSTEM INFORMATION
echo "   📋 Detecting system information..."

# Hostname
HOSTNAME=$(hostname 2>/dev/null || echo "unknown")
add_to_json "hostname" "$HOSTNAME"

# OS Information
if [ -f /etc/os-release ]; then
    source /etc/os-release
    add_to_json "os_name" "${NAME:-unknown}"
    add_to_json "os_version" "${VERSION:-unknown}"
    add_to_json "os_id" "${ID:-unknown}"
    add_to_json "os_version_id" "${VERSION_ID:-unknown}"
else
    add_to_json "os_name" "unknown"
    add_to_json "os_version" "unknown"
    add_to_json "os_id" "unknown"
    add_to_json "os_version_id" "unknown"
fi

# Architecture
ARCH=$(uname -m 2>/dev/null || echo "unknown")
add_to_json "architecture" "$ARCH"

# Kernel
KERNEL=$(uname -r 2>/dev/null || echo "unknown")
add_to_json "kernel" "$KERNEL"

# 2. CPU INFORMATION
echo "   🖥️  Detecting CPU information..."

if [ -f /proc/cpuinfo ]; then
    CPU_MODEL=$(grep "model name" /proc/cpuinfo | head -1 | cut -d: -f2 | sed 's/^ *//' || echo "unknown")
    CPU_CORES=$(nproc 2>/dev/null || echo "unknown")
    CPU_VENDOR=$(grep "vendor_id" /proc/cpuinfo | head -1 | cut -d: -f2 | sed 's/^ *//' || echo "unknown")
else
    CPU_MODEL="unknown"
    CPU_CORES="unknown"
    CPU_VENDOR="unknown"
fi

add_to_json "cpu_model" "$CPU_MODEL"
add_to_json "cpu_cores" "$CPU_CORES" "number"
add_to_json "cpu_vendor" "$CPU_VENDOR"

# 3. GPU INFORMATION
echo "   🎮 Detecting GPU information..."

GPU_INFO="[]"
if command -v lspci >/dev/null 2>&1; then
    # Get VGA controllers
    VGA_DEVICES=$(lspci | grep -i vga || true)
    if [ -n "$VGA_DEVICES" ]; then
        GPU_ARRAY="[]"
        while IFS= read -r line; do
            if [ -n "$line" ]; then
                # Extract vendor and model
                VENDOR="unknown"
                MODEL="$line"
                
                if echo "$line" | grep -qi "nvidia"; then
                    VENDOR="nvidia"
                    MODEL=$(echo "$line" | sed 's/.*NVIDIA Corporation //' | sed 's/ \[.*\]//')
                elif echo "$line" | grep -qi "intel"; then
                    VENDOR="intel"
                    MODEL=$(echo "$line" | sed 's/.*Intel Corporation //' | sed 's/ \[.*\]//')
                elif echo "$line" | grep -qi "amd\|radeon"; then
                    VENDOR="amd"
                    MODEL=$(echo "$line" | sed 's/.*AMD\/ATI //' | sed 's/ \[.*\]//')
                fi
                
                GPU_OBJ=$(jq -n --arg vendor "$VENDOR" --arg model "$MODEL" --arg full "$line" \
                    '{vendor: $vendor, model: $model, full_description: $full}')
                GPU_ARRAY=$(echo "$GPU_ARRAY" | jq --argjson gpu "$GPU_OBJ" '. + [$gpu]')
            fi
        done <<< "$VGA_DEVICES"
        GPU_INFO="$GPU_ARRAY"
    fi
fi

add_to_json "gpus" "$GPU_INFO" "array"

# 4. MONITOR/DISPLAY INFORMATION  
echo "   🖥️  Detecting monitor information..."

MONITOR_INFO="{\"count\": 0, \"monitors\": [], \"primary\": \"unknown\"}"

# Method 1: Try xrandr if available and DISPLAY is set
if command -v xrandr >/dev/null 2>&1 && [ -n "${DISPLAY:-}" ]; then
    echo "     Using xrandr detection..."
    XRANDR_OUTPUT=$(xrandr --query 2>/dev/null || true)
    if [ -n "$XRANDR_OUTPUT" ]; then
        CONNECTED_MONITORS=$(echo "$XRANDR_OUTPUT" | grep " connected" || true)
        if [ -n "$CONNECTED_MONITORS" ]; then
            MONITOR_ARRAY="[]"
            MONITOR_COUNT=0
            PRIMARY_MONITOR="unknown"
            
            while IFS= read -r line; do
                if [ -n "$line" ]; then
                    MONITOR_NAME=$(echo "$line" | awk '{print $1}')
                    MONITOR_COUNT=$((MONITOR_COUNT + 1))
                    
                    # Check if primary
                    if echo "$line" | grep -q "primary"; then
                        PRIMARY_MONITOR="$MONITOR_NAME"
                    fi
                    
                    # Extract resolution and determine orientation
                    RESOLUTION=$(echo "$line" | grep -o '[0-9]\+x[0-9]\+' | head -1 || echo "unknown")
                    WIDTH=$(echo "$RESOLUTION" | cut -d'x' -f1 2>/dev/null || echo "0")
                    HEIGHT=$(echo "$RESOLUTION" | cut -d'x' -f2 2>/dev/null || echo "0")
                    
                    ORIENTATION="unknown"
                    if [ "$WIDTH" -gt "$HEIGHT" ]; then
                        ORIENTATION="landscape"
                    elif [ "$HEIGHT" -gt "$WIDTH" ]; then
                        ORIENTATION="portrait"
                    fi
                    
                    # Extract panel ID from EDID information
                    PANEL_ID="$MONITOR_NAME"
                    
                    # Method 1: Try to get panel ID from DRM EDID
                    DRM_CARD_PATH="/sys/class/drm/card*-$MONITOR_NAME/edid"
                    for edid_path in $DRM_CARD_PATH; do
                        if [ -f "$edid_path" ]; then
                            # Read EDID binary data and extract vendor/product
                            if command -v hexdump >/dev/null 2>&1; then
                                EDID_HEX=$(hexdump -C "$edid_path" 2>/dev/null | head -10 || true)
                                if [ -n "$EDID_HEX" ]; then
                                    # EDID vendor ID is at bytes 8-9, product ID at bytes 10-11
                                    VENDOR_BYTES=$(echo "$EDID_HEX" | sed -n '1p' | awk '{print $3 $4}' || echo "")
                                    PRODUCT_BYTES=$(echo "$EDID_HEX" | sed -n '1p' | awk '{print $5 $6}' || echo "")
                                    
                                    if [ -n "$VENDOR_BYTES" ] && [ -n "$PRODUCT_BYTES" ]; then
                                        # Convert vendor bytes to 3-letter code
                                        VENDOR_CODE=$(printf "%s" "$VENDOR_BYTES" | \
                                            sed 's/\(..\)\(..\)/\2\1/' | \
                                            xxd -r -p 2>/dev/null | \
                                            od -An -tx2 2>/dev/null | \
                                            awk '{printf "%c%c%c", (($1/1024)%32)+64, (($1/32)%32)+64, ($1%32)+64}' 2>/dev/null || echo "")
                                        
                                        # Format product as hex
                                        PRODUCT_HEX=$(printf "0x%s" "$PRODUCT_BYTES" | sed 's/\(..\)\(..\)/0x\2\1/' || echo "0x00000000")
                                        
                                        if [ -n "$VENDOR_CODE" ] && [ "$VENDOR_CODE" != "" ]; then
                                            PANEL_ID="$VENDOR_CODE-$PRODUCT_HEX"
                                        fi
                                    fi
                                fi
                            fi
                            break
                        fi
                    done
                    
                    # Method 2: Fallback to xrandr --verbose for EDID info
                    if [ "$PANEL_ID" = "$MONITOR_NAME" ] && command -v xrandr >/dev/null 2>&1; then
                        XRANDR_VERBOSE=$(xrandr --verbose | grep -A 50 "^$MONITOR_NAME " 2>/dev/null || true)
                        if [ -n "$XRANDR_VERBOSE" ]; then
                            # Look for manufacturer and product in verbose output
                            MANUFACTURER=$(echo "$XRANDR_VERBOSE" | grep -i "manufacturer" | head -1 | awk '{print $2}' || echo "")
                            PRODUCT=$(echo "$XRANDR_VERBOSE" | grep -i "product" | head -1 | awk '{print $2}' || echo "")
                            
                            if [ -n "$MANUFACTURER" ] && [ -n "$PRODUCT" ]; then
                                PANEL_ID="$MANUFACTURER-$PRODUCT"
                            fi
                        fi
                    fi
                    
                    # Method 3: Try gdbus as final fallback
                    if [ "$PANEL_ID" = "$MONITOR_NAME" ] && command -v gdbus >/dev/null 2>&1 && [ -n "${DISPLAY:-}" ]; then
                        DISPLAY_CONFIG=$(gdbus call --session --dest org.gnome.Mutter.DisplayConfig \
                            --object-path /org/gnome/Mutter/DisplayConfig \
                            --method org.gnome.Mutter.DisplayConfig.GetCurrentState 2>/dev/null || true)
                        
                        if [ -n "$DISPLAY_CONFIG" ]; then
                            # Extract monitor info in format: ('eDP-1', 'AUO', '0x633d', '0x00000000')
                            # We want field 2 (vendor) + field 4 (the 0x000... ID)
                            MONITOR_DATA=$(echo "$DISPLAY_CONFIG" | grep -o "('$MONITOR_NAME'[^)]*)" | head -1 || echo "")
                            if [ -n "$MONITOR_DATA" ]; then
                                # Extract the vendor (2nd field) and the 0x000... (4th field)
                                VENDOR=$(echo "$MONITOR_DATA" | sed "s/.*'$MONITOR_NAME', '\([^']*\)'.*/\1/" || echo "")
                                PRODUCT_ID=$(echo "$MONITOR_DATA" | sed "s/.*'$MONITOR_NAME', '[^']*', '[^']*', '\([^']*\)'.*/\1/" || echo "")
                                
                                if [ -n "$VENDOR" ] && [ -n "$PRODUCT_ID" ] && [ "$PRODUCT_ID" != "$MONITOR_DATA" ]; then
                                    PANEL_ID="$VENDOR-$PRODUCT_ID"
                                fi
                            fi
                        fi
                    fi
                    
                    MONITOR_OBJ=$(jq -n \
                        --arg name "$MONITOR_NAME" \
                        --arg width "$WIDTH" \
                        --arg height "$HEIGHT" \
                        --arg orientation "$ORIENTATION" \
                        --arg panel_id "$PANEL_ID" \
                        '{name: $name, width: ($width | tonumber), height: ($height | tonumber), orientation: $orientation, panel_id: $panel_id}')
                    
                    MONITOR_ARRAY=$(echo "$MONITOR_ARRAY" | jq --argjson monitor "$MONITOR_OBJ" '. + [$monitor]')
                fi
            done <<< "$CONNECTED_MONITORS"
            
            if [ "$PRIMARY_MONITOR" = "unknown" ] && [ "$MONITOR_COUNT" -gt 0 ]; then
                PRIMARY_MONITOR=$(echo "$MONITOR_ARRAY" | jq -r '.[0].name')
            fi
            
            MONITOR_INFO=$(jq -n \
                --argjson count "$MONITOR_COUNT" \
                --argjson monitors "$MONITOR_ARRAY" \
                --arg primary "$PRIMARY_MONITOR" \
                '{count: $count, monitors: $monitors, primary: $primary}')
        fi
    fi
fi

# Method 2: Fallback to DRM if xrandr failed
if [ "$(echo "$MONITOR_INFO" | jq '.count')" = "0" ]; then
    echo "     Using DRM fallback detection..."
    if [ -d "/sys/class/drm" ]; then
        MONITOR_ARRAY="[]"
        MONITOR_COUNT=0
        PRIMARY_MONITOR="unknown"
        
        for card in /sys/class/drm/card*-*; do
            if [ -d "$card" ]; then
                status_file="$card/status"
                if [ -f "$status_file" ]; then
                    status=$(cat "$status_file" 2>/dev/null || echo "unknown")
                    if [ "$status" = "connected" ]; then
                        MONITOR_NAME=$(basename "$card" | sed 's/^card[0-9]*-//')
                        MONITOR_COUNT=$((MONITOR_COUNT + 1))
                        
                        if [ "$PRIMARY_MONITOR" = "unknown" ]; then
                            PRIMARY_MONITOR="$MONITOR_NAME"
                        fi
                        
                        # For DRM, we can't easily get resolution, so use reasonable defaults
                        # Most laptop screens are 1920x1080 landscape
                        WIDTH=1920
                        HEIGHT=1080
                        ORIENTATION="landscape"
                             # Extract panel ID using comprehensive approach
                    PANEL_ID="$MONITOR_NAME"
                    
                    # Try multiple methods to get real panel ID
                    PANEL_ID=$(extract_panel_id "$MONITOR_NAME")
                        
                        MONITOR_OBJ=$(jq -n \
                            --arg name "$MONITOR_NAME" \
                            --argjson width "$WIDTH" \
                            --argjson height "$HEIGHT" \
                            --arg orientation "$ORIENTATION" \
                            --arg panel_id "$PANEL_ID" \
                            '{name: $name, width: $width, height: $height, orientation: $orientation, panel_id: $panel_id}')
                        
                        MONITOR_ARRAY=$(echo "$MONITOR_ARRAY" | jq --argjson monitor "$MONITOR_OBJ" '. + [$monitor]')
                    fi
                fi
            fi
        done
        
        if [ "$MONITOR_COUNT" -gt 0 ]; then
            MONITOR_INFO=$(jq -n \
                --argjson count "$MONITOR_COUNT" \
                --argjson monitors "$MONITOR_ARRAY" \
                --arg primary "$PRIMARY_MONITOR" \
                '{count: $count, monitors: $monitors, primary: $primary}')
        fi
    fi
fi

add_to_json "displays" "$MONITOR_INFO" "object"

# 5. MEMORY INFORMATION
echo "   💾 Detecting memory information..."

if [ -f /proc/meminfo ]; then
    TOTAL_MEM_KB=$(grep "MemTotal:" /proc/meminfo | awk '{print $2}' || echo "0")
    TOTAL_MEM_GB=$((TOTAL_MEM_KB / 1024 / 1024))
else
    TOTAL_MEM_GB=0
fi

add_to_json "memory_gb" "$TOTAL_MEM_GB" "number"

# 6. STORAGE INFORMATION
echo "   💿 Detecting storage information..."

STORAGE_INFO="[]"
if command -v lsblk >/dev/null 2>&1; then
    BLOCK_DEVICES=$(lsblk -J 2>/dev/null || echo '{"blockdevices":[]}')
    STORAGE_ARRAY="[]"
    
    # Extract main storage devices (not partitions)
    MAIN_DEVICES=$(echo "$BLOCK_DEVICES" | jq -r '.blockdevices[] | select(.type == "disk") | .name' 2>/dev/null || true)
    if [ -n "$MAIN_DEVICES" ]; then
        while IFS= read -r device; do
            if [ -n "$device" ]; then
                SIZE=$(echo "$BLOCK_DEVICES" | jq -r ".blockdevices[] | select(.name == \"$device\") | .size" 2>/dev/null || echo "unknown")
                MODEL=$(echo "$BLOCK_DEVICES" | jq -r ".blockdevices[] | select(.name == \"$device\") | .model" 2>/dev/null || echo "unknown")
                
                # If lsblk didn't provide a model or returned null, try /sys/block
                if [ "$MODEL" = "unknown" ] || [ "$MODEL" = "null" ]; then
                    if [ -f "/sys/block/$device/device/model" ]; then
                        MODEL=$(cat "/sys/block/$device/device/model" 2>/dev/null | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' || echo "unknown")
                    elif [ "$device" = "zram0" ]; then
                        MODEL="zram (virtual)"
                    else
                        MODEL="unknown"
                    fi
                fi
                
                STORAGE_OBJ=$(jq -n \
                    --arg name "$device" \
                    --arg size "$SIZE" \
                    --arg model "$MODEL" \
                    '{name: $name, size: $size, model: $model}')
                
                STORAGE_ARRAY=$(echo "$STORAGE_ARRAY" | jq --argjson storage "$STORAGE_OBJ" '. + [$storage]')
            fi
        done <<< "$MAIN_DEVICES"
    fi
    STORAGE_INFO="$STORAGE_ARRAY"
fi

add_to_json "storage" "$STORAGE_INFO" "array"

# 7. NETWORK INFORMATION
echo "   🌐 Detecting network information..."

NETWORK_INFO="[]"
if command -v ip >/dev/null 2>&1; then
    INTERFACES=$(ip link show | grep -E "^[0-9]+:" | awk -F: '{print $2}' | sed 's/^ *//' | grep -v "^lo$" || true)
    NETWORK_ARRAY="[]"
    
    if [ -n "$INTERFACES" ]; then
        while IFS= read -r interface; do
            if [ -n "$interface" ]; then
                STATE=$(ip link show "$interface" 2>/dev/null | grep -o "state [A-Z]*" | cut -d' ' -f2 || echo "UNKNOWN")
                TYPE="unknown"
                
                if echo "$interface" | grep -q "wl"; then
                    TYPE="wifi"
                elif echo "$interface" | grep -q "en\|eth"; then
                    TYPE="ethernet"
                fi
                
                NETWORK_OBJ=$(jq -n \
                    --arg name "$interface" \
                    --arg type "$TYPE" \
                    --arg state "$STATE" \
                    '{name: $name, type: $type, state: $state}')
                
                NETWORK_ARRAY=$(echo "$NETWORK_ARRAY" | jq --argjson net "$NETWORK_OBJ" '. + [$net]')
            fi
        done <<< "$INTERFACES"
    fi
    NETWORK_INFO="$NETWORK_ARRAY"
fi

add_to_json "network_interfaces" "$NETWORK_INFO" "array"

# 8. SYSTEM TYPE CLASSIFICATION
echo "   🏷️  Classifying system type..."

# Determine if laptop or desktop
IS_LAPTOP=false
if [ -d "/proc/acpi/battery" ] || [ -d "/sys/class/power_supply" ]; then
    # Check for battery
    if ls /sys/class/power_supply/BAT* >/dev/null 2>&1; then
        IS_LAPTOP=true
    fi
fi

add_to_json "is_laptop" "$IS_LAPTOP" "boolean"

# Generate system identifier (like your current system-detection.nix)
SYSTEM_ID="unknown"
if [ "$IS_LAPTOP" = true ]; then
    # For laptops, try to get model info
    if [ -f /sys/devices/virtual/dmi/id/product_name ]; then
        PRODUCT_NAME=$(cat /sys/devices/virtual/dmi/id/product_name 2>/dev/null | tr ' ' '_' || echo "laptop")
    else
        PRODUCT_NAME="laptop"
    fi
    
    # GPU type for identifier
    GPU_TYPE="unknown"
    if echo "$JSON_DATA" | jq -e '.gpus[] | select(.vendor == "nvidia")' >/dev/null 2>&1; then
        if echo "$JSON_DATA" | jq -e '.gpus[] | select(.vendor == "intel")' >/dev/null 2>&1; then
            GPU_TYPE="hybrid"
        else
            GPU_TYPE="nvidia"
        fi
    elif echo "$JSON_DATA" | jq -e '.gpus[] | select(.vendor == "intel")' >/dev/null 2>&1; then
        GPU_TYPE="intel"
    elif echo "$JSON_DATA" | jq -e '.gpus[] | select(.vendor == "amd")' >/dev/null 2>&1; then
        GPU_TYPE="amd"
    fi
    
    SYSTEM_ID="laptop-${PRODUCT_NAME}-${GPU_TYPE}"
else
    SYSTEM_ID="desktop"
fi

add_to_json "system_id" "$SYSTEM_ID"

# 9. TIMESTAMP
TIMESTAMP=$(date -Iseconds)
add_to_json "detection_timestamp" "$TIMESTAMP"
add_to_json "detection_method" "runtime_script"

# Write the final JSON file
echo "$JSON_DATA" | jq '.' > "$OUTPUT_FILE"

echo "✅ System specifications detected and saved to: $OUTPUT_FILE"
echo ""
echo "📋 Summary:"
echo "   • System ID: $(echo "$JSON_DATA" | jq -r '.system_id')"
echo "   • Hostname: $(echo "$JSON_DATA" | jq -r '.hostname')"
echo "   • OS: $(echo "$JSON_DATA" | jq -r '.os_name') $(echo "$JSON_DATA" | jq -r '.os_version')"
echo "   • CPU: $(echo "$JSON_DATA" | jq -r '.cpu_model')"
echo "   • GPUs: $(echo "$JSON_DATA" | jq -r '.gpus | length') detected"
echo "   • Displays: $(echo "$JSON_DATA" | jq -r '.displays.count') detected"
echo "   • Memory: $(echo "$JSON_DATA" | jq -r '.memory_gb') GB"
echo "   • Is Laptop: $(echo "$JSON_DATA" | jq -r '.is_laptop')"
echo ""
echo "💡 Run 'cd ~/.nix-config && NIXPKGS_ALLOW_UNFREE=1 nix run --impure .#homeConfigurations.$USER.activationPackage"
