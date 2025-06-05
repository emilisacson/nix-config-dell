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
            # Extract monitor info in format: ('DP-5', 'AOC', 'U28P2G6B', 'PCSN4JA000069')
            # We want field 1 (manufacturer) + field 3 (serial)
            MONITOR_DATA=$(echo "$DISPLAY_CONFIG" | grep -o "('$monitor_name'[^)]*)" | head -1 || echo "")
            if [ -n "$MONITOR_DATA" ]; then
                # Extract the manufacturer (field 1) and serial (field 3)
                VENDOR=$(echo "$MONITOR_DATA" | sed "s/.*'$monitor_name', '\([^']*\)'.*/\1/" || echo "")
                SERIAL=$(echo "$MONITOR_DATA" | sed "s/.*'$monitor_name', '[^']*', '[^']*', '\([^']*\)'.*/\1/" || echo "")
                
                if [ -n "$VENDOR" ] && [ -n "$SERIAL" ] && [ "$SERIAL" != "$MONITOR_DATA" ]; then
                    panel_id="$VENDOR-$SERIAL"
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

# Function to get monitor rotation from GNOME monitors.xml
# Note: GNOME uses different rotation conventions in XML vs GUI:
# - monitors.xml "left" = 90° counterclockwise = GUI "Portrait Right"
# - monitors.xml "right" = 90° clockwise = GUI "Portrait Left"
# - monitors.xml "inverted" = 180° = GUI "Landscape (flipped)"
# This function returns the XML convention for consistency with the config file
get_monitor_rotation() {
    local monitor_name="$1"
    local monitors_xml="$HOME/.config/monitors.xml"
    local rotation="normal"
    
    if [ -f "$monitors_xml" ] && command -v xmlstarlet >/dev/null 2>&1; then
        # Use xmlstarlet if available for robust XML parsing
        rotation=$(xmlstarlet sel -t -m "//logicalmonitor[monitor/monitorspec/connector='$monitor_name']/transform/rotation" -v . "$monitors_xml" 2>/dev/null || echo "normal")
    elif [ -f "$monitors_xml" ]; then
        # Simple approach: find the line number of our connector, then search backwards for the nearest rotation
        local connector_line=$(grep -n "<connector>$monitor_name</connector>" "$monitors_xml" | head -1 | cut -d: -f1)
        
        if [ -n "$connector_line" ]; then
            # Look backwards from the connector line to find the nearest logicalmonitor start
            local logicalmonitor_start=$(awk -v connector_line="$connector_line" 'NR <= connector_line && /<logicalmonitor>/ {start=NR} END {print start}' "$monitors_xml")
            
            if [ -n "$logicalmonitor_start" ]; then
                # Look for rotation between the logicalmonitor start and connector line
                local rotation_line=$(sed -n "${logicalmonitor_start},${connector_line}p" "$monitors_xml" | grep -n "<rotation>" | head -1 | cut -d: -f1)
                
                if [ -n "$rotation_line" ]; then
                    # Calculate actual line number and extract rotation
                    local actual_rotation_line=$((logicalmonitor_start + rotation_line - 1))
                    rotation=$(sed -n "${actual_rotation_line}p" "$monitors_xml" | sed 's/.*<rotation>\([^<]*\)<\/rotation>.*/\1/' | tr -d ' \t\n\r')
                fi
            fi
        fi
    fi
    
    echo "$rotation"
}

# Function to determine actual orientation based on resolution and rotation
get_actual_orientation() {
    local width="$1"
    local height="$2"
    local rotation="$3"
    
    local base_orientation
    if [ "$width" -gt "$height" ]; then
        base_orientation="landscape"
    elif [ "$height" -gt "$width" ]; then
        base_orientation="portrait"
    else
        base_orientation="square"
    fi
    
    # Apply rotation transformation
    case "$rotation" in
        "left"|"right")
            # 90-degree rotations flip the orientation
            if [ "$base_orientation" = "landscape" ]; then
                echo "portrait"
            elif [ "$base_orientation" = "portrait" ]; then
                echo "landscape"
            else
                echo "square"
            fi
            ;;
        "inverted"|"normal"|"")
            # 0 or 180-degree rotations keep the same logical orientation
            echo "$base_orientation"
            ;;
        *)
            # Unknown rotation, fall back to base orientation
            echo "$base_orientation"
            ;;
    esac
}

# Function to get monitor refresh rate (Hz) - improved method using proper gdbus parsing
get_monitor_refresh_rate() {
    local monitor_name="$1"
    local refresh_rate=60  # Default fallback
    
    # Method 1: Try gdbus to get GNOME display config (most reliable) - using Python parser
    if command -v gdbus >/dev/null 2>&1 && command -v python3 >/dev/null 2>&1 && [ -n "${DISPLAY:-}" ]; then
        DISPLAY_CONFIG=$(gdbus call --session --dest org.gnome.Mutter.DisplayConfig \
            --object-path /org/gnome/Mutter/DisplayConfig \
            --method org.gnome.Mutter.DisplayConfig.GetCurrentState 2>/dev/null || true)
        
        if [ -n "$DISPLAY_CONFIG" ]; then
            # Use Python to properly parse the complex gdbus structure
            TEMP_PYTHON=$(mktemp --suffix=.py)
            cat > "$TEMP_PYTHON" << 'EOF'
import sys
import re

def extract_current_refresh_rate(gdbus_output, target_connector):
    """Extract current refresh rate for a specific monitor connector."""
    
    # Remove outer parentheses and uint32 prefix
    cleaned = gdbus_output.strip()
    if cleaned.startswith('(uint32'):
        # Find the first comma after uint32
        first_comma = cleaned.find(',', 6)
        if first_comma != -1:
            cleaned = cleaned[first_comma+1:].strip()
            if cleaned.endswith(')'):
                cleaned = cleaned[:-1].strip()
    
    # Find the three main sections by counting brackets/braces
    bracket_count = 0
    brace_count = 0
    sections = []
    current_section = ""
    section_type = None
    
    i = 0
    while i < len(cleaned):
        char = cleaned[i]
        
        if char == '[' and bracket_count == 0 and brace_count == 0:
            if current_section.strip():
                sections.append((section_type, current_section.strip()))
            current_section = ""
            section_type = 'array'
            bracket_count = 1
        elif char == '[':
            bracket_count += 1
            current_section += char
        elif char == ']':
            bracket_count -= 1
            if bracket_count == 0 and section_type == 'array':
                sections.append((section_type, current_section.strip()))
                current_section = ""
                section_type = None
            else:
                current_section += char
        elif char == '{' and bracket_count == 0 and brace_count == 0:
            if current_section.strip():
                sections.append((section_type, current_section.strip()))
            current_section = ""
            section_type = 'object'
            brace_count = 1
        elif char == '{':
            brace_count += 1
            current_section += char
        elif char == '}':
            brace_count -= 1
            if brace_count == 0 and section_type == 'object':
                sections.append((section_type, current_section.strip()))
                current_section = ""
                section_type = None
            else:
                current_section += char
        elif bracket_count > 0 or brace_count > 0:
            current_section += char
        elif char in ', \n\t':
            # Skip whitespace and commas between sections
            pass
        else:
            current_section += char
        
        i += 1
    
    # Handle any remaining section
    if current_section.strip():
        sections.append((section_type, current_section.strip()))
    
    # Get monitors section (first array)
    if len(sections) < 1:
        return "60"
    
    monitors_section = sections[0][1]
    
    # Split monitors by "), ((" pattern
    monitor_entries = re.split(r'\), \(\(', monitors_section)
    
    for entry in monitor_entries:
        # Clean up the entry
        entry = entry.strip()
        if entry.startswith('(('):
            entry = entry[2:]
        if entry.endswith('))'):
            entry = entry[:-2]
        elif entry.endswith(')'):
            entry = entry[:-1]
        
        # Check if this entry is for our target connector
        if f"'{target_connector}'" not in entry:
            continue
        
        # Parse monitor entry: (('connector', 'vendor', 'model', 'serial'), [MODES], {PROPERTIES})
        # Find the modes section (between "), [" and "], {")
        modes_match = re.search(r'\), \[(.*)\], \{', entry)
        if not modes_match:
            continue
        
        modes_section = modes_match.group(1)
        
        # Find current mode by looking for 'is-current': <true>
        # Mode format: ('mode_id', width, height, refresh_rate, scale, [scales], {properties})
        mode_pattern = r"'([^']*)', (\d+), (\d+), ([0-9.e+-]+), ([0-9.]+), \[[^\]]*\], \{[^}]*'is-current': <true>[^}]*\}"
        current_mode_match = re.search(mode_pattern, modes_section)
        
        if current_mode_match:
            refresh_rate = current_mode_match.group(4)
            try:
                # Convert to float and round to nearest integer
                rate_float = float(refresh_rate)
                return str(round(rate_float))
            except ValueError:
                continue
    
    return "60"

if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("60")
        sys.exit(0)
    
    gdbus_output = sys.argv[1]
    target_connector = sys.argv[2]
    
    result = extract_current_refresh_rate(gdbus_output, target_connector)
    print(result)
EOF
            
            # Call Python script to parse refresh rate
            PARSED_RATE=$(python3 "$TEMP_PYTHON" "$DISPLAY_CONFIG" "$monitor_name" 2>/dev/null || echo "60")
            if [ -n "$PARSED_RATE" ] && [ "$PARSED_RATE" != "60" ]; then
                refresh_rate="$PARSED_RATE"
            fi
            
            rm -f "$TEMP_PYTHON"
        fi
    fi
    
    # Method 2: Try xrandr if gdbus method failed
    if [ "$refresh_rate" = "60" ] && command -v xrandr >/dev/null 2>&1 && [ -n "${DISPLAY:-}" ]; then
        XRANDR_OUTPUT=$(xrandr 2>/dev/null | grep "^$monitor_name " || true)
        if [ -n "$XRANDR_OUTPUT" ]; then
            # Look for current mode (marked with *)
            CURRENT_RATE=$(echo "$XRANDR_OUTPUT" | grep -o '[0-9][0-9]*\.[0-9][0-9]*\*' | sed 's/\*//' | head -1)
            if [ -n "$CURRENT_RATE" ]; then
                refresh_rate=$(printf "%.0f" "$CURRENT_RATE")
            fi
        fi
    fi
    
    # Method 3: Try DRM mode information as last resort
    if [ "$refresh_rate" = "60" ]; then
        for card in /sys/class/drm/card*-$monitor_name; do
            if [ -d "$card" ]; then
                modes_file="$card/modes"
                if [ -f "$modes_file" ]; then
                    # Get the first (preferred) mode and extract refresh rate
                    PREFERRED_MODE=$(head -1 "$modes_file" 2>/dev/null || echo "")
                    if [ -n "$PREFERRED_MODE" ] && echo "$PREFERRED_MODE" | grep -q "@"; then
                        MODE_RATE=$(echo "$PREFERRED_MODE" | sed 's/.*@\([0-9]*\).*/\1/')
                        if [ -n "$MODE_RATE" ] && [ "$MODE_RATE" -gt 0 ] && [ "$MODE_RATE" -lt 1000 ]; then
                            refresh_rate="$MODE_RATE"
                        fi
                    fi
                fi
                break
            fi
        done
    fi
    
    # Ensure we have a reasonable value (allow lower values like 30Hz for some displays)
    if [ "$refresh_rate" -lt 20 ] || [ "$refresh_rate" -gt 500 ]; then
        refresh_rate=60
    fi
    
    echo "$refresh_rate"
}

# 4. MONITOR/DISPLAY INFORMATION  
echo "   🖥️  Detecting monitor information..."

MONITOR_INFO="{\"count\": 0, \"monitors\": [], \"primary\": \"unknown\"}"

# Detect monitors using DRM (Direct Rendering Manager)
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
                    
                    # Set first connected monitor as primary
                    if [ "$PRIMARY_MONITOR" = "unknown" ]; then
                        PRIMARY_MONITOR="$MONITOR_NAME"
                    fi
                    
                    # Try to get actual resolution from DRM
                    WIDTH=1920
                    HEIGHT=1080
                    ORIENTATION="landscape"
                    
                    # Method 1: Try to get mode information from DRM
                    modes_file="$card/modes"
                    if [ -f "$modes_file" ]; then
                        # Get the first (preferred) mode
                        PREFERRED_MODE=$(head -1 "$modes_file" 2>/dev/null || echo "")
                        if [ -n "$PREFERRED_MODE" ] && echo "$PREFERRED_MODE" | grep -q "x"; then
                            WIDTH=$(echo "$PREFERRED_MODE" | cut -d'x' -f1)
                            HEIGHT=$(echo "$PREFERRED_MODE" | cut -d'x' -f2 | cut -d'i' -f1 | cut -d'p' -f1)
                        fi
                    fi
                    
                    # Method 2: Try to get resolution from EDID detailed timing
                    edid_file="$card/edid"
                    if [ -f "$edid_file" ] && [ -s "$edid_file" ] && command -v hexdump >/dev/null 2>&1; then
                        # EDID detailed timing descriptor starts at byte 54 (0x36)
                        # Horizontal active is at bytes 56-57 (little endian)
                        # Vertical active is at bytes 59-60 (little endian)
                        EDID_HEX=$(hexdump -C "$edid_file" 2>/dev/null | head -10)
                        if [ -n "$EDID_HEX" ]; then
                            # Extract horizontal resolution (bytes 58-59, with upper nibble of 62)
                            H_LOW=$(echo "$EDID_HEX" | sed -n '4p' | awk '{print "0x" $7}' 2>/dev/null)
                            H_HIGH=$(echo "$EDID_HEX" | sed -n '4p' | awk '{print "0x" $8}' 2>/dev/null)
                            V_LOW=$(echo "$EDID_HEX" | sed -n '4p' | awk '{print "0x" $10}' 2>/dev/null)
                            V_HIGH=$(echo "$EDID_HEX" | sed -n '4p' | awk '{print "0x" $11}' 2>/dev/null)
                            
                            if [ -n "$H_LOW" ] && [ -n "$H_HIGH" ] && [ -n "$V_LOW" ] && [ -n "$V_HIGH" ]; then
                                # Calculate resolution (simplified EDID parsing)
                                H_RES=$(( (($H_HIGH & 0xF0) << 4) + $H_LOW ))
                                V_RES=$(( (($V_HIGH & 0xF0) << 4) + $V_LOW ))
                                
                                if [ "$H_RES" -gt 640 ] && [ "$H_RES" -lt 8192 ] && [ "$V_RES" -gt 480 ] && [ "$V_RES" -lt 8192 ]; then
                                    WIDTH=$H_RES
                                    HEIGHT=$V_RES
                                fi
                            fi
                        fi
                    fi
                    
                    # Method 3: Fallback based on monitor type
                    if [ "$WIDTH" = "1920" ] && [ "$HEIGHT" = "1080" ]; then
                        case "$MONITOR_NAME" in
                            eDP-1|LVDS-1|DSI-1)
                                # Laptop displays - common resolutions
                                WIDTH=1920
                                HEIGHT=1080
                                ;;
                            DP-*|HDMI-*)
                                # External displays - assume common resolution
                                WIDTH=1920
                                HEIGHT=1080
                                ;;
                        esac
                    fi
                    
                    # Get rotation from GNOME monitors.xml
                    ROTATION=$(get_monitor_rotation "$MONITOR_NAME")
                    
                    # Determine actual orientation based on resolution and rotation
                    ACTUAL_ORIENTATION=$(get_actual_orientation "$WIDTH" "$HEIGHT" "$ROTATION")
                    
                    # Keep original orientation logic for compatibility
                    if [ "$WIDTH" -gt "$HEIGHT" ]; then
                        ORIENTATION="landscape"
                    elif [ "$HEIGHT" -gt "$WIDTH" ]; then
                        ORIENTATION="portrait"
                    else
                        ORIENTATION="square"
                    fi
                    
                    # Extract panel ID using comprehensive approach
                    PANEL_ID=$(extract_panel_id "$MONITOR_NAME")
                    
                    # Get refresh rate using comprehensive method
                    REFRESH_RATE=$(get_monitor_refresh_rate "$MONITOR_NAME")
                    
                    MONITOR_OBJ=$(jq -n \
                        --arg name "$MONITOR_NAME" \
                        --argjson width "$WIDTH" \
                        --argjson height "$HEIGHT" \
                        --arg orientation "$ORIENTATION" \
                        --arg panel_id "$PANEL_ID" \
                        --arg rotation "$ROTATION" \
                        --arg actual_orientation "$ACTUAL_ORIENTATION" \
                        --argjson refresh_rate "$REFRESH_RATE" \
                        '{name: $name, width: $width, height: $height, orientation: $orientation, panel_id: $panel_id, rotation: $rotation, actual_orientation: $actual_orientation, refresh_rate: $refresh_rate}')
                    
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
