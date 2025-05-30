#!/usr/bin/env bash

# System Override Management Script
# This script helps you manage system type overrides for testing different configurations

OVERRIDE_FILE="$HOME/.nix-system-type"

show_help() {
    echo "🔧 System Override Management"
    echo "═══════════════════════════════════════════════════"
    echo ""
    echo "Usage: $0 [COMMAND] [OPTIONS]"
    echo ""
    echo "Commands:"
    echo "  show                    Show current override status"
    echo "  set <system-type>       Set a system type override"
    echo "  clear                   Clear any existing override"
    echo "  list                    List available system types"
    echo "  test                    Test current detection without override"
    echo "  rebuild                 Rebuild home-manager configuration"
    echo ""
    echo "Quick shortcuts:"
    echo "  test-nvidia             Set Lenovo ThinkPad with NVIDIA (for testing)"
    echo "  test-intel              Set Dell with Intel-only (for testing)"
    echo "  test-error              Simulate detection failure"
    echo ""
    echo "Example system types:"
    echo "  dell-Latitude_7410-intel-only"
    echo "  lenovo-ThinkPad_T14_Gen_2-nvidia-intel"
    echo "  lenovo-ThinkPad_X1_Carbon-intel-only"
    echo "  unable-to-detect-system"
    echo "  unable-to-detect-vendor-model-intel-only"
    echo ""
    echo "Examples:"
    echo "  $0 show"
    echo "  $0 set lenovo-ThinkPad_T14_Gen_2-nvidia-intel"
    echo "  $0 clear"
    echo "  $0 rebuild"
}

show_status() {
    echo "🔍 Current Override Status"
    echo "═══════════════════════════════════════════════════"
    
    if [ -f "$OVERRIDE_FILE" ]; then
        OVERRIDE_CONTENT=$(cat "$OVERRIDE_FILE" 2>/dev/null | tr -d '\n' | tr -d '\r')
        if [ -n "$OVERRIDE_CONTENT" ]; then
            echo "✅ Override active: $OVERRIDE_CONTENT"
        else
            echo "⚠️  Override file exists but is empty"
        fi
    else
        echo "✅ No override active (using automatic detection)"
    fi
    
    echo ""
    echo "📋 Detected system info:"
    if [ -f /sys/class/dmi/id/sys_vendor ] && [ -f /sys/class/dmi/id/product_name ]; then
        VENDOR=$(cat /sys/class/dmi/id/sys_vendor 2>/dev/null | tr -d '\n' | tr -d '\r' | sed 's/^[ \t]*//;s/[ \t]*$//')
        MODEL=$(cat /sys/class/dmi/id/product_name 2>/dev/null | tr -d '\n' | tr -d '\r' | sed 's/^[ \t]*//;s/[ \t]*$//')
        echo "  • Hardware: $VENDOR $MODEL"
    else
        echo "  • Hardware: Unable to detect"
    fi
    
    if command -v lspci >/dev/null 2>&1; then
        if lspci 2>/dev/null | grep -i nvidia >/dev/null; then
            echo "  • GPU: NVIDIA + Intel (hybrid)"
        else
            echo "  • GPU: Intel only"
        fi
    else
        echo "  • GPU: Unable to detect (lspci not available)"
    fi
}

set_override() {
    local system_type="$1"
    
    if [ -z "$system_type" ]; then
        echo "❌ Error: Please specify a system type"
        echo "Run '$0 list' to see available options"
        exit 1
    fi
    
    echo "🔧 Setting system override to: $system_type"
    echo "$system_type" > "$OVERRIDE_FILE"
    
    if [ -f "$OVERRIDE_FILE" ]; then
        echo "✅ Override set successfully"
        echo "💡 Run '$0 rebuild' to apply the changes"
    else
        echo "❌ Failed to create override file"
        exit 1
    fi
}

clear_override() {
    if [ -f "$OVERRIDE_FILE" ]; then
        rm "$OVERRIDE_FILE"
        echo "✅ Override cleared - back to automatic detection"
        echo "💡 Run '$0 rebuild' to apply the changes"
    else
        echo "✅ No override was active"
    fi
}

list_system_types() {
    echo "📋 Available System Types"
    echo "═══════════════════════════════════════════════════"
    echo ""
    echo "🏢 Dell Systems:"
    echo "  dell-Latitude_7410-intel-only"
    echo "  dell-XPS_13-intel-only"
    echo "  dell-Precision_5000-nvidia-intel"
    echo ""
    echo "🏢 Lenovo Systems:"
    echo "  lenovo-ThinkPad_T14_Gen_2-nvidia-intel"
    echo "  lenovo-ThinkPad_X1_Carbon-intel-only"
    echo "  lenovo-ThinkPad_P1-nvidia-intel"
    echo "  lenovo-IdeaPad_Gaming-nvidia-intel"
    echo ""
    echo "⚠️  Error Simulation:"
    echo "  unable-to-detect-system"
    echo "  unable-to-detect-vendor-model-intel-only"
    echo "  unable-to-detect-vendor-model-nvidia-intel"
    echo ""
    echo "💡 You can also create custom system types using the format:"
    echo "   <vendor>-<model>-<gpu-config>"
    echo "   where gpu-config is either 'intel-only' or 'nvidia-intel'"
}

test_detection() {
    echo "🧪 Testing System Detection"
    echo "═══════════════════════════════════════════════════"
    
    # Run our standalone detection script
    if [ -f "$HOME/.nix-config/extras/test-detection.sh" ]; then
        bash "$HOME/.nix-config/extras/test-detection.sh"
    else
        echo "❌ Test script not found at $HOME/.nix-config/extras/test-detection.sh"
        echo "💡 This would normally run the detection logic"
    fi
}

rebuild_config() {
    echo "🔄 Rebuilding Home Manager Configuration"
    echo "═══════════════════════════════════════════════════"
    
    cd ~/.nix-config || {
        echo "❌ Error: Could not change to ~/.nix-config directory"
        exit 1
    }
    
    echo "🚀 Running: NIXPKGS_ALLOW_UNFREE=1 nix run --impure .#homeConfigurations.$USER.activationPackage"
    NIXPKGS_ALLOW_UNFREE=1 nix run --impure .#homeConfigurations.$USER.activationPackage
}

# Main script logic
case "${1:-show}" in
    "help"|"-h"|"--help")
        show_help
        ;;
    "show"|"status"|"current")
        show_status
        ;;
    "set")
        set_override "$2"
        ;;
    "clear"|"remove"|"reset")
        clear_override
        ;;
    "list"|"types")
        list_system_types
        ;;
    "test"|"detect")
        test_detection
        ;;
    "rebuild"|"apply")
        rebuild_config
        ;;
    "test-nvidia")
        set_override "lenovo-ThinkPad_T14_Gen_2-nvidia-intel"
        echo "🧪 Test mode: NVIDIA + Intel configuration active"
        echo "💡 Run '$0 rebuild' to apply the changes"
        ;;
    "test-intel")
        set_override "dell-Latitude_7410-intel-only"
        echo "🧪 Test mode: Intel-only configuration active"
        echo "💡 Run '$0 rebuild' to apply the changes"
        ;;
    "test-error")
        set_override "unable-to-detect-system"
        echo "🧪 Test mode: Detection failure simulation active"
        echo "💡 Run '$0 rebuild' to see how the system handles detection errors"
        ;;
    *)
        echo "❌ Unknown command: $1"
        echo ""
        show_help
        exit 1
        ;;
esac
