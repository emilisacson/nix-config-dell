#!/bin/bash

# GNOME Display Configuration Parser
# Parses gdbus DisplayConfig output and formats it in a human-readable format
# Similar to the formatted_display_data.txt structure

set -euo pipefail

# Ensure C locale for consistent number formatting
export LC_NUMERIC=C

# Get display configuration data from gdbus immediately
echo "Getting current display configuration..."
echo ""
DISPLAY_DATA=$(gdbus call --session --dest org.gnome.Mutter.DisplayConfig --object-path /org/gnome/Mutter/DisplayConfig --method org.gnome.Mutter.DisplayConfig.GetCurrentState 2>/dev/null)

if [[ -z "$DISPLAY_DATA" ]]; then
    echo "Error: Failed to get display configuration from gdbus" >&2
    echo "Make sure you're running this in a GNOME session" >&2
    exit 1
fi

# Function to format refresh rate
format_refresh_rate() {
    local rate="$1"
    printf "%.3f" "$rate"
}

# Function to format scale factor
format_scale() {
    local scale="$1"
    printf "%.3f" "$scale"
}

# Function to determine display type
get_display_type() {
    local is_builtin="$1"
    if [[ "$is_builtin" == "true" ]]; then
        echo "Built-in Display"
    else
        echo "External Monitor"
    fi
}

# Function to extract mode details from a mode string
extract_mode_details() {
    local mode_string="$1"
    local mode_id width height refresh_rate scale is_current is_preferred
    
    # Mode format: ('mode_id', width, height, refresh_rate, scale, [supported_scales], {properties})
    if [[ "$mode_string" =~ \'([^\']*)\',\ ([0-9]+),\ ([0-9]+),\ ([0-9.e+-]+),\ ([0-9.]+) ]]; then
        mode_id="${BASH_REMATCH[1]}"
        width="${BASH_REMATCH[2]}"
        height="${BASH_REMATCH[3]}"
        refresh_rate="${BASH_REMATCH[4]}"
        scale="${BASH_REMATCH[5]}"
        
        # Check if current or preferred
        is_current="false"
        is_preferred="false"
        if [[ "$mode_string" =~ is-current.*true ]]; then
            is_current="true"
        fi
        if [[ "$mode_string" =~ is-preferred.*true ]]; then
            is_preferred="true"
        fi
        
        echo "$mode_id|$width|$height|$refresh_rate|$scale|$is_current|$is_preferred"
    fi
}

# Function to parse monitor metadata
parse_monitor_metadata() {
    local monitor_data="$1"
    local connector vendor model serial
    
    # Extract basic info: connector, vendor, model, serial
    if [[ "$monitor_data" =~ (\(\()?\'([^\']*)\',\ \'([^\']*)\',\ \'([^\']*)\',\ \'([^\']*)\' ]]; then
        connector="${BASH_REMATCH[2]}"
        vendor="${BASH_REMATCH[3]}"
        model="${BASH_REMATCH[4]}"
        serial="${BASH_REMATCH[5]}"
        echo "$connector|$vendor|$model|$serial"
    fi
}

# Function to parse monitor properties
parse_monitor_properties() {
    local props_section="$1"
    local is_builtin display_name min_refresh_rate is_primary
    
    # Extract properties
    is_builtin="false"
    display_name=""
    min_refresh_rate=""
    is_primary="false"
    
    if [[ "$props_section" =~ \'is-builtin\'.*\<true\> ]]; then
        is_builtin="true"
    fi
    
    if [[ "$props_section" =~ \'display-name\'.*\<\'([^\']*)\'\> ]]; then
        display_name="${BASH_REMATCH[1]}"
    fi
    
    if [[ "$props_section" =~ \'min-refresh-rate\'.*\<([0-9]+)\> ]]; then
        min_refresh_rate="${BASH_REMATCH[1]}"
    fi
    
    if [[ "$props_section" =~ is-primary.*true ]]; then
        is_primary="true"
    fi
    
    echo "$is_builtin|$display_name|$min_refresh_rate|$is_primary"
}

# Function to parse modes
parse_modes() {
    local modes_section="$1"
    local current_mode="" preferred_mode=""
    
    # Find current and preferred modes
    current_mode=$(echo "$modes_section" | grep -o "('[^']*', [0-9]*, [0-9]*, [0-9.e+-]*, [0-9.]*, \[[^\]]*\], {[^}]*'is-current': <true>[^}]*})")
    preferred_mode=$(echo "$modes_section" | grep -o "('[^']*', [0-9]*, [0-9]*, [0-9.e+-]*, [0-9.]*, \[[^\]]*\], {[^}]*'is-preferred': <true>[^}]*})")
    
    echo "$current_mode|$preferred_mode"
}

# Function to parse layout information for a specific connector
parse_layout_for_connector() {
    local layout_section="$1"
    local target_connector="$2"
    
    # Layout format: (x, y, scale, rotation, is_primary, [('connector', 'vendor', 'model', 'serial')])
    while IFS= read -r layout_entry; do
        if [[ "$layout_entry" =~ \(([0-9]+),\ ([0-9]+),\ ([0-9.]+),\ uint32\ ([0-9]+),\ ([^,]*),\ \[.*\'([^\']*)\' ]]; then
            local x="${BASH_REMATCH[1]}"
            local y="${BASH_REMATCH[2]}"
            local scale="${BASH_REMATCH[3]}"
            local rotation="${BASH_REMATCH[4]}"
            local is_primary="${BASH_REMATCH[5]}"
            local connector="${BASH_REMATCH[6]}"
            
            if [[ "$connector" == "$target_connector" ]]; then
                echo "$x|$y|$scale|$rotation|$is_primary"
                return
            fi
        fi
    done <<< "$(echo "$layout_section" | grep -o "([0-9]*, [0-9]*, [0-9.]*, uint32 [0-9]*, [^,]*, \[[^]]*\])")"
}

# Function to parse layout information
parse_layout() {
    local layout_section="$1"
    local x y scale rotation is_primary connector
    
    # Extract layout info: (x, y, scale, rotation, is_primary, [('connector', ...)])
    x=$(echo "$layout_section" | sed -n "s/.*(\([0-9]*\), \([0-9]*\), \([0-9.]*\), uint32 \([0-9]*\), \([^,]*\), \[.*\].*/\1/p")
    y=$(echo "$layout_section" | sed -n "s/.*(\([0-9]*\), \([0-9]*\), \([0-9.]*\), uint32 \([0-9]*\), \([^,]*\), \[.*\].*/\2/p")
    scale=$(echo "$layout_section" | sed -n "s/.*(\([0-9]*\), \([0-9]*\), \([0-9.]*\), uint32 \([0-9]*\), \([^,]*\), \[.*\].*/\3/p")
    rotation=$(echo "$layout_section" | sed -n "s/.*(\([0-9]*\), \([0-9]*\), \([0-9.]*\), uint32 \([0-9]*\), \([^,]*\), \[.*\].*/\4/p")
    is_primary=$(echo "$layout_section" | sed -n "s/.*(\([0-9]*\), \([0-9]*\), \([0-9.]*\), uint32 \([0-9]*\), \([^,]*\), \[.*\].*/\5/p")
    connector=$(echo "$layout_section" | sed -n "s/.*\[('\([^']*\)',.*/\1/p")
    
    echo "$connector|$x|$y|$scale|$rotation|$is_primary"
}

# Function to extract and format all modes
format_all_modes() {
    local modes_section="$1"
    local current_mode_name="$2"
    local preferred_mode_name="$3"
    
    # Extract individual modes
    echo "$modes_section" | grep -o "('[^']*', [0-9]*, [0-9]*, [0-9.e+-]*, [0-9.]*, \[[^\]]*\], {[^}]*})" | while read -r mode; do
        local mode_name width height refresh_rate scale scales
        
        mode_name=$(echo "$mode" | sed "s/.*('\([^']*\)'.*/\1/")
        width=$(echo "$mode" | sed "s/.*'[^']*', \([0-9]*\).*/\1/")
        height=$(echo "$mode" | sed "s/.*'[^']*', [0-9]*, \([0-9]*\).*/\1/")
        refresh_rate=$(echo "$mode" | sed "s/.*'[^']*', [0-9]*, [0-9]*, \([0-9.e+-]*\).*/\1/")
        scale=$(echo "$mode" | sed "s/.*'[^']*', [0-9]*, [0-9]*, [0-9.e+-]*, \([0-9.]*\).*/\1/")
        
        # Format output line
        local status=""
        if [[ "$mode_name" == "$current_mode_name" && "$mode_name" == "$preferred_mode_name" ]]; then
            status=" (Current, Preferred)"
        elif [[ "$mode_name" == "$current_mode_name" ]]; then
            status=" (Current)"
        elif [[ "$mode_name" == "$preferred_mode_name" ]]; then
            status=" (Preferred)"
        fi
        
        printf "  %s @ %.3f Hz%s - Scale: %.3f\n" "${width}×${height}" "$refresh_rate" "$status" "$scale"
    done
}

# Main parsing function
parse_display_config() {
    local input="$1"
    
    # Print header
    echo "GNOME Mutter Display Configuration Output"
    echo "========================================="
    echo ""
    echo "Command: gdbus call --session --dest org.gnome.Mutter.DisplayConfig --object-path /org/gnome/Mutter/DisplayConfig --method org.gnome.Mutter.DisplayConfig.GetCurrentState"
    echo ""
    
    # Extract the main sections: (uint32 X, [MONITORS], [LAYOUT], {CONFIG})
    # Remove outer parentheses and split by main sections
    local cleaned_input=$(echo "$input" | sed 's/^(uint32 [0-9]*, //' | sed 's/)$//')
    
    # Extract monitors section (first [...] block)  
    local monitors_section=""
    local layout_section=""
    local config_section=""
    
    # Use Python to properly parse the complex structure
    local temp_file=$(mktemp)
    cat > "$temp_file" << 'EOF'
import sys
import re

# Read the input
input_data = sys.stdin.read().strip()

# Remove outer parentheses and uint32 prefix
if input_data.startswith('(uint32'):
    # Find the first comma after uint32
    first_comma = input_data.find(',', 6)
    if first_comma != -1:
        input_data = input_data[first_comma+1:].strip()
        if input_data.endswith(')'):
            input_data = input_data[:-1].strip()

# Find the three main sections by counting brackets/braces
bracket_count = 0
brace_count = 0
sections = []
current_section = ""
section_type = None

i = 0
while i < len(input_data):
    char = input_data[i]
    
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

# Output the sections
if len(sections) >= 3:
    print("MONITORS_SECTION:" + sections[0][1])
    print("LAYOUT_SECTION:" + sections[1][1])
    print("CONFIG_SECTION:" + sections[2][1])
else:
    print("ERROR: Could not find all three sections")
    print(f"Found {len(sections)} sections")
    for i, (stype, content) in enumerate(sections):
        print(f"Section {i} ({stype}): {content[:100]}...")
EOF

    echo "$cleaned_input" | python3 "$temp_file" > "${temp_file}.out" 2>&1
    
    if [[ $? -eq 0 ]]; then
        # Extract the sections from Python output
        monitors_section=$(grep "^MONITORS_SECTION:" "${temp_file}.out" | sed 's/^MONITORS_SECTION://')
        layout_section=$(grep "^LAYOUT_SECTION:" "${temp_file}.out" | sed 's/^LAYOUT_SECTION://')
        config_section=$(grep "^CONFIG_SECTION:" "${temp_file}.out" | sed 's/^CONFIG_SECTION://')
    fi
    
    rm -f "$temp_file" "${temp_file}.out"
    
    # Process monitors
    if [[ -n "$monitors_section" ]]; then
        # Split monitors by "), ((" pattern
        echo "$monitors_section" | sed 's/), ((/\n===MONITOR_SPLIT===\n/g' > "$temp_file"
        
        local monitor_num=1
        local current_monitor=""
        local in_monitor=false
        
        while IFS= read -r line; do
            if [[ "$line" == "===MONITOR_SPLIT===" ]]; then
                if [[ $in_monitor == true && -n "$current_monitor" ]]; then
                    parse_single_monitor_comprehensive "$current_monitor" "$monitor_num" "$layout_section"
                    ((monitor_num++))
                fi
                current_monitor=""
                in_monitor=true
            else
                if [[ $in_monitor == true ]]; then
                    current_monitor+="$line"
                elif [[ -z "$current_monitor" ]]; then
                    # First monitor (no split marker before it)
                    current_monitor="$line"
                    in_monitor=true
                fi
            fi
        done < "$temp_file"
        
        # Handle the last monitor
        if [[ $in_monitor == true && -n "$current_monitor" ]]; then
            parse_single_monitor_comprehensive "$current_monitor" "$monitor_num" "$layout_section"
        fi
        
        rm -f "$temp_file"
    else
        echo "Error: Could not extract monitors section"
        return 1
    fi
    
    # Display layout configuration summary
    echo "═══════════════════════════════════════════════════════════════════════════════"
    echo ""
    echo "LAYOUT CONFIGURATION"
    echo "────────────────────"
    
    # Extract layout mode from config section
    if [[ "$input" =~ \{.*layout-mode.*uint32\ ([0-9]+) ]]; then
        local layout_mode="${BASH_REMATCH[1]}"
        case "$layout_mode" in
            1) echo "Layout Mode: 1 (Logical)" ;;
            2) echo "Layout Mode: 2 (Physical)" ;;
            *) echo "Layout Mode: $layout_mode" ;;
        esac
    fi
    
    if [[ "$input" =~ supports-changing-layout-mode.*true ]]; then
        echo "Supports Changing Layout Mode: Yes"
    else
        echo "Supports Changing Layout Mode: No"
    fi
    
    echo ""
}

# Comprehensive single monitor parser
parse_single_monitor_comprehensive() {
    local monitor_data="$1"
    local monitor_num="$2"
    local layout_data="$3"
    
    # Extract monitor metadata
    local metadata=$(parse_monitor_metadata "$monitor_data")
    IFS='|' read -r connector vendor model serial <<< "$metadata"
    
    if [[ -z "$connector" ]]; then
        echo "Warning: Could not parse monitor $monitor_num data"
        return
    fi
    
    echo "═══════════════════════════════════════════════════════════════════════════════"
    echo ""
    
    # Extract properties from the last {...} block in monitor data
    local props_data=""
    if [[ "$monitor_data" =~ \{[^}]*'is-builtin'[^}]*\} ]]; then
        props_data="${BASH_REMATCH[0]}"
    fi
    
    local props_info=$(parse_monitor_properties "$props_data")
    IFS='|' read -r is_builtin display_name min_refresh_rate is_primary <<< "$props_info"
    
    # Determine display type and format header
    if [[ "$is_builtin" == "true" ]]; then
        echo "MONITOR $monitor_num: $connector (Built-in Display)"
        echo "───────────────────────────────────"
        echo "Type:          Built-in Display"
    else
        echo "MONITOR $monitor_num: $connector ($vendor $model)"
        echo "──────────────────────────────"
        echo "Type:          External Monitor"
    fi
    
    echo "Connector:     $connector"
    echo "Manufacturer:  $vendor"
    echo "Model:         $model"
    echo "Serial:        $serial"
    
    if [[ -n "$display_name" ]]; then
        echo "Display Name:  $display_name"
    fi
    
    echo "Builtin:       $is_builtin"
    
    if [[ -n "$min_refresh_rate" ]]; then
        echo "Minimum Refresh Rate: $min_refresh_rate Hz"
    fi
    
    if [[ "$is_primary" == "true" ]]; then
        echo "Primary:       true"
    fi
    
    echo ""
    
    # Extract and parse modes section 
    # The structure is: (('connector',...), [MODES], {PROPERTIES})
    # We need to find the [ that comes after the first ), and the ] that comes before the last , {
    local modes_section=""
    
    # Use a simpler approach - extract everything between "], [" and "], {"
    local temp_data="$monitor_data"
    
    # Find the start position after '), [' and before '], {'
    if [[ "$temp_data" =~ (\),\ \[)([^]]*(\][^]]*)*)\],\ \{ ]]; then
        modes_section="${BASH_REMATCH[2]}"
    else
        # Alternative method: find positions manually
        local start_pos=$(echo "$temp_data" | grep -o -b '), \[' | head -1 | cut -d: -f1)
        if [[ -n "$start_pos" ]]; then
            # Skip past '), [' 
            start_pos=$((start_pos + 4))
            local remaining_data="${temp_data:$start_pos}"
            
            # Find the end position before '], {'
            local end_marker=$(echo "$remaining_data" | grep -o -b '\], {' | head -1 | cut -d: -f1)
            if [[ -n "$end_marker" ]]; then
                modes_section="${remaining_data:0:$end_marker}"
            fi
        fi
    fi
    
    # Find current and preferred modes
    local current_mode="" preferred_mode=""
    local current_width="" current_height="" current_refresh="" current_scale=""
    
    # First, find current mode info
    if [[ "$modes_section" =~ \'([^\']*)\',\ ([0-9]+),\ ([0-9]+),\ ([0-9.e+-]+),\ ([0-9.]+)[^}]*\'is-current\'.*true ]]; then
        current_mode="${BASH_REMATCH[1]}"
        current_width="${BASH_REMATCH[2]}"
        current_height="${BASH_REMATCH[3]}"
        current_refresh="${BASH_REMATCH[4]}"
        current_scale="${BASH_REMATCH[5]}"
    fi
    
    # Display current mode
    if [[ -n "$current_mode" ]]; then
        echo "Current Mode:"
        echo "  Resolution:   ${current_width}×${current_height}"
        printf "  Refresh Rate: %.3f Hz\n" "$current_refresh"
        printf "  Scale Factor: %.3f\n" "$current_scale"
        echo ""
    fi
    
    # Display all supported resolutions
    echo "Supported Resolutions:"
    
    if [[ -n "$modes_section" ]]; then
        # Split by "), (" to separate individual mode entries, and also handle the first one without leading "), ("
        echo "$modes_section" | sed -e 's/), (/\n/g' -e 's/^(//' -e 's/)$//' | while IFS= read -r mode_entry; do
            # Skip empty lines
            [[ -n "$mode_entry" ]] || continue
            
            # Parse mode entry: 'mode_id', width, height, refresh_rate, scale, [scales], {properties}
            if [[ "$mode_entry" =~ ^\'([^\']*)\',\ ([0-9]+),\ ([0-9]+),\ ([0-9.e+-]+),\ ([0-9.]+) ]]; then
                local mode_id="${BASH_REMATCH[1]}"
                local width="${BASH_REMATCH[2]}"
                local height="${BASH_REMATCH[3]}"
                local refresh_rate="${BASH_REMATCH[4]}"
                local scale="${BASH_REMATCH[5]}"
                
                local status=""
                
                # Check for current and preferred flags
                if [[ "$mode_entry" =~ \'is-current\'.*true ]] && [[ "$mode_entry" =~ \'is-preferred\'.*true ]]; then
                    status=" (Current, Preferred)"
                elif [[ "$mode_entry" =~ \'is-current\'.*true ]]; then
                    status=" (Current)"
                elif [[ "$mode_entry" =~ \'is-preferred\'.*true ]]; then
                    status=" (Preferred)"
                fi
                
                printf "  %s×%s @ %.3f Hz%s - Scale: %.3f\n" "$width" "$height" "$refresh_rate" "$status" "$scale"
            fi
        done
    else
        echo "  (No modes information available)"
    fi
    
    echo ""
    
    # Extract position from layout data
    if [[ -n "$layout_data" ]]; then
        local position_info=$(parse_layout_for_connector "$layout_data" "$connector")
        if [[ -n "$position_info" ]]; then
            IFS='|' read -r x y scale rotation is_primary_layout <<< "$position_info"
            echo "Position in Layout: x=$x, y=$y"
            echo ""
        fi
    fi
}

# Main execution
main() {
    local input_data=""
    
    input_data=$(gdbus call --session --dest org.gnome.Mutter.DisplayConfig --object-path /org/gnome/Mutter/DisplayConfig --method org.gnome.Mutter.DisplayConfig.GetCurrentState 2>/dev/null)
    
    if [[ -z "$input_data" ]]; then
        echo "Error: Failed to get display configuration from gdbus" >&2
        echo "Make sure you're running this in a GNOME session" >&2
        exit 1
    fi
    
    # Check if optional file argument is provided for comparison
    if [[ $# -eq 1 ]]; then
        local input_file="$1"
        if [[ -f "$input_file" ]]; then
            echo "Note: Using live gdbus data. File '$input_file' provided but will be ignored."
            echo "      (To parse from file only, modify the script)"
        else
            echo "Warning: File '$input_file' not found, using live gdbus data"
        fi
    fi
    
    # Check if input contains expected gdbus output
    if [[ ! "$input_data" =~ "uint32" ]]; then
        echo "Error: Input does not appear to be gdbus DisplayConfig output" >&2
        exit 1
    fi
    
    # Parse and format the display configuration
    parse_display_config "$input_data"
}

# Run main function with all arguments
main "$@"
