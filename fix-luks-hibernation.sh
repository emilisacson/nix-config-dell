#!/usr/bin/env bash
# Smart hibernation fix for LUKS + Btrfs systems

set -e

echo "🔧 Smart Hibernation Fix (No Partition Changes Needed!)"
echo "======================================================"
echo ""

echo "🔍 The issue is that your encrypted LUKS system needs special handling."
echo "   We don't need a new partition - just proper LUKS resume configuration!"
echo ""

# Get device information
LUKS_DEV="/dev/mapper/luks-e0b6f4a8-158d-4730-905c-7c907b6873d8"
PHYSICAL_DEV="/dev/nvme0n1p7"

echo "📊 Current setup:"
echo "  Physical device: $PHYSICAL_DEV"
echo "  LUKS device: $LUKS_DEV"
echo "  Swap file: /swapfile (on LUKS device)"
echo ""

# Get device major:minor for LUKS device
LUKS_MAJOR_MINOR=$(stat -c "%t:%T" "$LUKS_DEV" 2>/dev/null)
if [ -n "$LUKS_MAJOR_MINOR" ]; then
    LUKS_MAJOR=$((0x$(echo $LUKS_MAJOR_MINOR | cut -d: -f1)))
    LUKS_MINOR=$((0x$(echo $LUKS_MAJOR_MINOR | cut -d: -f2)))
    echo "🔍 LUKS device major:minor: $LUKS_MAJOR:$LUKS_MINOR"
else
    echo "❌ Could not determine LUKS device major:minor"
    exit 1
fi

echo ""
echo "🔧 The fix: Update GRUB to use the LUKS device directly"
echo "   This avoids the UUID resolution issues with encrypted filesystems."
echo ""

read -p "Apply the LUKS hibernation fix? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "❌ Fix cancelled"
    exit 1
fi

echo ""
echo "🔄 Applying LUKS hibernation fix..."

# Backup GRUB config
GRUB_FILE="/etc/default/grub"
BACKUP_FILE="/etc/default/grub.backup.luks.$(date +%Y%m%d_%H%M%S)"
sudo cp "$GRUB_FILE" "$BACKUP_FILE"
echo "📋 Backed up GRUB config to $BACKUP_FILE"

# Remove existing resume parameters
sudo sed -i 's/resume=[^ "]* resume_offset=[^ "]*//' "$GRUB_FILE"
sudo sed -i 's/resume=[^ "]*//' "$GRUB_FILE"

# Add LUKS-compatible resume parameters
sudo sed -i "s/GRUB_CMDLINE_LINUX=\"/&resume=$LUKS_DEV resume_offset=111252504 /" "$GRUB_FILE"

echo "✅ Updated GRUB to use LUKS device directly"

# Also try the device major:minor approach
echo "🔄 Setting runtime resume device..."
sudo sh -c "echo $LUKS_MAJOR:$LUKS_MINOR > /sys/power/resume"
echo "✅ Set resume device to $LUKS_MAJOR:$LUKS_MINOR"

# Rebuild GRUB
echo "🔄 Rebuilding GRUB..."
sudo grub2-mkconfig -o /boot/grub2/grub.cfg
echo "✅ GRUB rebuilt"

# Rebuild initramfs
echo "🔄 Rebuilding initramfs..."
sudo dracut -f
echo "✅ Initramfs rebuilt"

echo ""
echo "🧪 Testing hibernation immediately..."
echo "Current power states: $(cat /sys/power/state)"
echo "Resume device: $(cat /sys/power/resume)"

if grep -q "disk" /sys/power/state; then
    echo "🎉 SUCCESS! 'disk' is now available!"
    echo ""
    echo "✅ Hibernation should now work. Test with:"
    echo "   systemctl hibernate"
else
    echo "⚠️  'disk' still not available after runtime fix."
    echo "   A reboot may be needed for full kernel support."
    echo ""
    echo "📋 Next steps:"
    echo "1. Reboot your system"
    echo "2. Check power states: cat /sys/power/state"
    echo "3. Test hibernation: systemctl hibernate"
fi

echo ""
echo "🎉 LUKS hibernation fix complete!"
echo "   No partitions were harmed in the making of this fix! 😄"
