#!/usr/bin/env bash
# Advanced hibernation diagnostics and fixes for Btrfs

set -e

echo "🔍 Advanced Hibernation Diagnostics"
echo "==================================="
echo ""

echo "📊 Current System State:"
echo "  RAM: $(free -g | awk 'NR==2{print $2}')GB"
echo "  Swap: $(free -g | awk 'NR==3{print $2}')GB"
echo "  Root FS: $(df -T / | tail -1 | awk '{print $2}')"
echo ""

echo "🔍 Checking kernel support..."
echo "Power states: $(cat /sys/power/state)"
echo "Hibernate support: $(ls -la /sys/power/resume 2>/dev/null || echo 'Not found')"
echo "Resume device: $(cat /sys/power/resume 2>/dev/null || echo 'Not set')"
echo ""

echo "📋 Current swap configuration:"
swapon --show
echo ""

echo "🔍 Kernel command line:"
cat /proc/cmdline
echo ""

echo "📁 Swap file analysis:"
if [ -f /swapfile ]; then
    echo "  File exists: ✅"
    echo "  Size: $(ls -lh /swapfile | awk '{print $5}')"
    echo "  Permissions: $(ls -l /swapfile | awk '{print $1}')"
    
    echo "  Getting file offset (multiple methods):"
    
    # Method 1: filefrag
    echo "    Method 1 (filefrag):"
    sudo filefrag -v /swapfile | head -10
    
    # Method 2: Try btrfs inspector if available
    if command -v btrfs &> /dev/null; then
        echo "    Method 2 (btrfs filesystem usage):"
        sudo btrfs filesystem usage / | head -10
    fi
    
    # Method 3: Check file attributes
    echo "    Method 3 (file attributes):"
    lsattr /swapfile 2>/dev/null || echo "    Could not read attributes"
    
else
    echo "  ❌ Swap file not found"
fi

echo ""
echo "🧪 Testing hibernation components:"

# Test 1: Check if resume device is set correctly
echo "  1. Resume device configuration:"
RESUME_DEV=$(cat /sys/power/resume 2>/dev/null || echo "0:0")
echo "     /sys/power/resume contains: $RESUME_DEV"

# Test 2: Try to manually set resume device
ROOT_DEV=$(df / | tail -1 | awk '{print $1}')
echo "     Root device: $ROOT_DEV"

# Test 3: Check systemd hibernation capability
echo "  2. Systemd hibernation check:"
systemctl --version | head -1
systemctl list-unit-files | grep -E "(hibernate|suspend)" || echo "     No hibernation units found"

echo ""
echo "🔧 Suggested fixes:"

# Check if the issue is the missing resume major:minor
if [ "$RESUME_DEV" = "0:0" ]; then
    echo "  ❌ Resume device not properly set"
    echo "     This is likely the main issue!"
    
    # Get the device major:minor for root
    ROOT_MAJOR_MINOR=$(stat -c "%t:%T" "$ROOT_DEV" 2>/dev/null || echo "unknown")
    if [ "$ROOT_MAJOR_MINOR" != "unknown" ]; then
        ROOT_MAJOR=$((0x$(echo $ROOT_MAJOR_MINOR | cut -d: -f1)))
        ROOT_MINOR=$((0x$(echo $ROOT_MAJOR_MINOR | cut -d: -f2)))
        echo "     Root device major:minor should be: $ROOT_MAJOR:$ROOT_MINOR"
        echo ""
        echo "  🔧 Fix attempt 1: Set resume device manually"
        echo "     sudo sh -c 'echo $ROOT_MAJOR:$ROOT_MINOR > /sys/power/resume'"
    fi
fi

echo ""
echo "  🔧 Fix attempt 2: Alternative resume parameter format"
echo "     Current: resume=UUID=..."
echo "     Try: resume=$ROOT_DEV (direct device)"

echo ""
echo "  🔧 Fix attempt 3: Check if hibernation is disabled in systemd"
echo "     sudo systemctl status systemd-hibernate.service"

echo ""
echo "  🔧 Fix attempt 4: Verify initramfs contains resume support"
echo "     lsinitrd | grep -i resume"

echo ""
echo "💡 Would you like me to try automatic fixes? (y/N)"
read -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "🔄 Applying automatic fixes..."
    
    # Fix 1: Set resume device
    if [ "$RESUME_DEV" = "0:0" ] && [ "$ROOT_MAJOR_MINOR" != "unknown" ]; then
        echo "  Setting resume device..."
        sudo sh -c "echo $ROOT_MAJOR:$ROOT_MINOR > /sys/power/resume" || echo "  Failed to set resume device"
        echo "  New resume device: $(cat /sys/power/resume)"
    fi
    
    # Fix 2: Test hibernation again
    echo "  Testing power states after fix:"
    cat /sys/power/state
    
    if grep -q "disk" /sys/power/state; then
        echo "  ✅ 'disk' now available! Hibernation should work."
        echo "  Test with: systemctl hibernate"
    else
        echo "  ❌ 'disk' still not available"
        echo "  This likely requires kernel rebuild or different approach"
    fi
    
else
    echo "Manual fixes not applied."
fi

echo ""
echo "📋 Summary:"
echo "  Current power states: $(cat /sys/power/state)"
echo "  Resume device: $(cat /sys/power/resume 2>/dev/null || echo 'Not set')"
echo "  Hibernation working: $(if grep -q disk /sys/power/state; then echo '✅ Likely yes'; else echo '❌ No'; fi)"
