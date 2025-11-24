# Hibernation Configuration for Nix Home Manager
# This module configures hibernation support with proper swap management

{ config, lib, pkgs, ... }:

let
  systemSpecs = config.systemSpecs;
  systemId = systemSpecs.system_id or "unknown";

  # Calculate required swap size (should be at least RAM size + some extra)
  requiredSwapGB = systemSpecs.memory_gb + 4; # RAM + 4GB buffer

  # System-specific hibernation configurations
  hibernationConfigs = {
    "laptop-20Y30016MX-hybrid" = {
      enableHibernation = true;
      swapSizeGB = 66; # 62GB RAM + 4GB buffer
      enableHybridSuspend = true;
      enableSuspendThenHibernate = true;
      suspendThenHibernateDelay = "30min";
    };
    "laptop-Latitude_7410-intel" = {
      enableHibernation = true;
      swapSizeGB = 20; # Assuming ~16GB RAM + buffer
      enableHybridSuspend = true;
      enableSuspendThenHibernate = true;
      suspendThenHibernateDelay = "45min";
    };
    "default" = {
      enableHibernation = false;
      swapSizeGB = 8;
      enableHybridSuspend = false;
      enableSuspendThenHibernate = false;
      suspendThenHibernateDelay = "30min";
    };
  };

  # Get configuration for current system
  hibernationConfig =
    hibernationConfigs.${systemId} or hibernationConfigs.default;

in lib.mkIf hibernationConfig.enableHibernation {

  # Create hibernation helper scripts
  home.packages = with pkgs; [
    # Power management tools
    acpi
    powertop

    # Custom hibernation scripts
    (writeShellScriptBin "hibernation-setup" ''
      #!/usr/bin/env bash
      # Hibernation setup script for Fedora with Home Manager

      set -e

      echo "🔧 Hibernation Setup for System: ${systemId}"
      echo "==============================================="
      echo "Required RAM: ${toString systemSpecs.memory_gb}GB"
      echo "Recommended Swap: ${toString hibernationConfig.swapSizeGB}GB"
      echo ""

      # Check current swap
      echo "📊 Current Swap Status:"
      free -h | grep -E "Mem:|Swap:"
      echo ""
      cat /proc/swaps
      echo ""

      # Check available power states
      echo "⚡ Available Power States:"
      cat /sys/power/state
      echo ""

      # Check if hibernation is available
      if grep -q "disk" /sys/power/state; then
        echo "✅ Hibernation (disk) is available in kernel"
      else
        echo "❌ Hibernation (disk) is NOT available in kernel"
        echo ""
        echo "🔧 To enable hibernation, you need to:"
        echo "1. Create a proper swap file or partition (not zram)"
        echo "2. Add resume= parameter to kernel command line"
        echo "3. Ensure swap size >= RAM size"
        echo ""
      fi

      # Check current kernel parameters
      echo "🔍 Current Kernel Parameters:"
      grep -o "resume=[^ ]*" /proc/cmdline || echo "No resume parameter found"
      echo ""

      # Instructions for manual setup
      echo "📝 Manual Setup Instructions:"
      echo ""
      echo "1. Create swap file (as root):"
      echo "   sudo fallocate -l ${
        toString hibernationConfig.swapSizeGB
      }G /swapfile"
      echo "   sudo chmod 600 /swapfile"
      echo "   sudo mkswap /swapfile"
      echo "   sudo swapon /swapfile"
      echo ""
      echo "2. Add to /etc/fstab:"
      echo "   /swapfile none swap sw 0 0"
      echo ""
      echo "3. Get swap file offset (for GRUB):"
      echo "   sudo filefrag -v /swapfile | head -20"
      echo ""
      echo "4. Add to GRUB_CMDLINE_LINUX in /etc/default/grub:"
      echo "   resume=/dev/nvme0n1p7 resume_offset=<offset_from_step_3>"
      echo ""
      echo "5. Update GRUB and initramfs:"
      echo "   sudo grub2-mkconfig -o /boot/grub2/grub.cfg"
      echo "   sudo dracut -f"
      echo ""
      echo "6. Reboot and test:"
      echo "   systemctl hibernate"
      echo ""
    '')

    (writeShellScriptBin "test-hibernation" ''
      #!/usr/bin/env bash
      # Test hibernation functionality

      echo "🧪 Testing Hibernation Support"
      echo "============================="

      # Check power states
      echo "Available power states:"
      cat /sys/power/state
      echo ""

      # Check swap
      echo "Swap information:"
      swapon --show
      echo ""

      # Check systemd hibernation services
      echo "Systemd hibernation services:"
      systemctl status systemd-hibernate.service --no-pager -l || true
      echo ""

      # Test hibernation (dry run)
      echo "Testing hibernation (this will actually hibernate if working!):"
      echo "Run 'systemctl hibernate' to test (WARNING: will hibernate system)"
      echo "Run 'systemctl hybrid-sleep' for hybrid suspend/hibernate"
      echo "Run 'systemctl suspend-then-hibernate' for suspend with delayed hibernate"
    '')

    (writeShellScriptBin "fix-hibernation-fedora" ''
      #!/usr/bin/env bash
      # Automated hibernation fix for Fedora with Btrfs support

      set -e

      echo "🔧 Automated Hibernation Fix for Fedora (Btrfs)"
      echo "=============================================="
      echo ""

      # Check if running as root
      if [[ $EUID -eq 0 ]]; then
        echo "❌ Don't run this script as root. It will use sudo when needed."
        exit 1
      fi

      SWAP_SIZE="${toString hibernationConfig.swapSizeGB}G"
      SWAP_FILE="/swapfile"

      echo "📊 System Information:"
      echo "  RAM: ${toString systemSpecs.memory_gb}GB"
      echo "  Recommended Swap: $SWAP_SIZE"
      echo "  Root filesystem: $(df -T / | tail -1 | awk '{print $2}')"
      echo "  Root device: $(df / | tail -1 | awk '{print $1}')"
      echo ""

      # Check filesystem type
      FS_TYPE=$(df -T / | tail -1 | awk '{print $2}')
      if [ "$FS_TYPE" = "btrfs" ]; then
        echo "🗂️  Detected Btrfs filesystem - using Btrfs-compatible swap setup"
      else
        echo "🗂️  Detected $FS_TYPE filesystem"
      fi
      echo ""

      # Check available space
      AVAILABLE_GB=$(df / | tail -1 | awk '{print int($4/1024/1024)}')
      REQUIRED_GB=${toString hibernationConfig.swapSizeGB}

      if [ "$AVAILABLE_GB" -lt "$REQUIRED_GB" ]; then
        echo "❌ Insufficient space: need $REQUIRED_GB GB, have $AVAILABLE_GB GB"
        exit 1
      fi

      echo "✅ Sufficient space available"
      echo ""

      # Remove existing problematic swap file if it exists
      if [ -f "$SWAP_FILE" ]; then
        echo "�️  Removing existing swap file..."
        sudo swapoff "$SWAP_FILE" 2>/dev/null || true
        sudo rm -f "$SWAP_FILE"
        echo "✅ Removed existing swap file"
      fi

      # Create Btrfs-compatible swap file
      echo "�� Creating Btrfs-compatible swap file..."

      # Create the swap file with proper Btrfs settings
      sudo truncate -s 0 "$SWAP_FILE"
      sudo chattr +C "$SWAP_FILE" 2>/dev/null || echo "⚠️  Could not set NOCOW attribute (may not be needed)"
      sudo fallocate -l "$SWAP_SIZE" "$SWAP_FILE"
      sudo chmod 600 "$SWAP_FILE"

      # Make it a swap file
      sudo mkswap "$SWAP_FILE"
      echo "✅ Swap file created with Btrfs compatibility"

      # Test swap file before proceeding
      echo "🧪 Testing swap file..."
      if sudo swapon "$SWAP_FILE"; then
        echo "✅ Swap file test successful"
        sudo swapoff "$SWAP_FILE"
      else
        echo "❌ Swap file test failed - this may require a dedicated partition"
        echo ""
        echo "🔧 Alternative solution: Create dedicated swap partition"
        echo "1. Use GParted or fdisk to create a swap partition"
        echo "2. Format it: sudo mkswap /dev/sdXN"
        echo "3. Add to fstab: /dev/sdXN none swap sw 0 0"
        echo "4. Enable: sudo swapon /dev/sdXN"
        exit 1
      fi

      # Enable swap permanently
      echo "🔄 Enabling swap file..."
      sudo swapon "$SWAP_FILE"
      echo "✅ Swap file enabled"

      # Add to fstab if not present
      if ! grep -q "$SWAP_FILE" /etc/fstab; then
        echo "📝 Adding swap to /etc/fstab..."
        echo "$SWAP_FILE none swap sw 0 0" | sudo tee -a /etc/fstab
        echo "✅ Added to fstab"
      else
        echo "ℹ️  Already in fstab"
      fi

      # For Btrfs, we need to use btrfs_map_physical to get the offset
      echo "🔍 Getting Btrfs swap file offset..."

      # Try to get offset using btrfs_map_physical or filefrag
      if command -v btrfs_map_physical &> /dev/null; then
        OFFSET=$(sudo btrfs_map_physical "$SWAP_FILE" | head -2 | tail -1 | awk '{print $6}')
        echo "Using btrfs_map_physical offset: $OFFSET"
      else
        echo "⚠️  btrfs_map_physical not available, trying filefrag..."
        OFFSET=$(sudo filefrag -v "$SWAP_FILE" | awk 'NR==4{print $4}' | sed 's/\.\.//' | sed 's/://')
        echo "Using filefrag offset: $OFFSET"

        if [ -z "$OFFSET" ] || [ "$OFFSET" = "0" ]; then
          echo "❌ Could not determine swap file offset reliably"
          echo "🔧 This is common with Btrfs. Consider using a dedicated swap partition instead."
          echo ""
          echo "📋 Manual steps for swap partition:"
          echo "1. Create partition: sudo fdisk /dev/nvme0n1"
          echo "2. Format as swap: sudo mkswap /dev/nvme0n1pX"
          echo "3. Enable swap: sudo swapon /dev/nvme0n1pX"
          echo "4. Add to fstab: /dev/nvme0n1pX none swap sw 0 0"
          echo "5. Update GRUB: resume=/dev/nvme0n1pX (no offset needed)"
          exit 1
        fi
      fi

      # Get root device UUID
      ROOT_UUID=$(findmnt -n -o UUID /)
      ROOT_DEVICE=$(findmnt -n -o SOURCE /)

      echo "Root device: $ROOT_DEVICE"
      echo "Root UUID: $ROOT_UUID"
      echo "Swap offset: $OFFSET"
      echo ""

      # Update GRUB configuration
      echo "⚙️  Updating GRUB configuration..."

      GRUB_FILE="/etc/default/grub"
      BACKUP_FILE="/etc/default/grub.backup.$(date +%Y%m%d_%H%M%S)"

      # Backup current GRUB config
      sudo cp "$GRUB_FILE" "$BACKUP_FILE"
      echo "📋 Backed up GRUB config to $BACKUP_FILE"

      # Remove existing resume parameters
      if grep -q "resume=" "$GRUB_FILE"; then
        echo "ℹ️  Resume parameter already exists, updating..."
        sudo sed -i "s/resume=[^ \"]*//g" "$GRUB_FILE"
        sudo sed -i "s/resume_offset=[^ \"]*//g" "$GRUB_FILE"
      fi

      # Add resume parameters for Btrfs
      sudo sed -i "s/GRUB_CMDLINE_LINUX=\"/&resume=UUID=$ROOT_UUID resume_offset=$OFFSET /" "$GRUB_FILE"

      echo "✅ Updated GRUB configuration"
      echo ""

      # Rebuild GRUB
      echo "🔄 Rebuilding GRUB..."
      sudo grub2-mkconfig -o /boot/grub2/grub.cfg
      echo "✅ GRUB rebuilt"
      echo ""

      # Rebuild initramfs
      echo "🔄 Rebuilding initramfs..."
      sudo dracut -f
      echo "✅ Initramfs rebuilt"
      echo ""

      echo "🎉 Hibernation setup complete!"
      echo ""
      echo "📋 Next steps:"
      echo "1. Reboot your system"
      echo "2. Test hibernation with: systemctl hibernate"
      echo "3. Check if 'disk' appears in: cat /sys/power/state"
      echo ""
      echo "⚠️  IMPORTANT: Reboot required for changes to take effect!"
    '')

    (writeShellScriptBin "hibernation-recovery" ''
      #!/usr/bin/env bash
      # Emergency hibernation recovery script

      echo "🆘 Hibernation Recovery Script"
      echo "============================="
      echo ""

      echo "📋 Available recovery options:"
      echo "1. Disable hibernation temporarily"
      echo "2. Restore original GRUB configuration"
      echo "3. Remove swap file completely"
      echo "4. Show current hibernation status"
      echo ""

      read -p "Choose option (1-4): " choice

      case $choice in
        1)
          echo "🔄 Disabling hibernation temporarily..."
          sudo swapoff /swapfile 2>/dev/null || true
          echo "✅ Swap disabled. System will work normally without hibernation."
          ;;
        2)
          echo "🔄 Restoring original GRUB configuration..."
          if [ -f "/etc/default/grub.backup.20250730_074411" ]; then
            sudo cp /etc/default/grub.backup.20250730_074411 /etc/default/grub
            sudo grub2-mkconfig -o /boot/grub2/grub.cfg
            sudo dracut -f
            echo "✅ Original GRUB configuration restored. Reboot to take effect."
          else
            echo "❌ Backup file not found. Manual recovery needed."
          fi
          ;;
        3)
          echo "🗑️  Removing swap file completely..."
          sudo swapoff /swapfile 2>/dev/null || true
          sudo sed -i '/\/swapfile/d' /etc/fstab
          sudo rm -f /swapfile
          echo "✅ Swap file removed. Consider creating a dedicated partition instead."
          ;;
        4)
          echo "📊 Current hibernation status:"
          echo "Power states: $(cat /sys/power/state)"
          echo "Active swap:"
          swapon --show || echo "No active swap"
          echo "GRUB parameters:"
          grep -o "resume=[^ ]*" /proc/cmdline || echo "No resume parameter"
          ;;
        *)
          echo "❌ Invalid option"
          ;;
      esac
    '')

    (writeShellScriptBin "fix-hibernation-partition" ''
      #!/usr/bin/env bash
      # Create dedicated swap partition for reliable hibernation on Btrfs systems

      set -e

      echo "🔧 Hibernation Fix: Dedicated Swap Partition"
      echo "==========================================="
      echo ""
      echo "⚠️  This will create a dedicated swap partition for reliable hibernation."
      echo "   Btrfs swap files often have hibernation issues, so we'll use a partition instead."
      echo ""

      # Check if running as root
      if [[ $EUID -eq 0 ]]; then
        echo "❌ Don't run this script as root. It will use sudo when needed."
        exit 1
      fi

      SWAP_SIZE="${toString hibernationConfig.swapSizeGB}G"

      echo "📊 System Information:"
      echo "  RAM: ${toString systemSpecs.memory_gb}GB"
      echo "  Recommended Swap: $SWAP_SIZE"
      echo ""

      echo "🔍 Current Disk Layout:"
      lsblk /dev/nvme0n1
      echo ""

      # Check if nvme0n1p8 exists and is available
      if [ ! -b "/dev/nvme0n1p8" ]; then
        echo "❌ Expected partition /dev/nvme0n1p8 not found"
        echo "Please check your disk layout with: lsblk"
        exit 1
      fi

      # Check if partition is already mounted
      if mountpoint -q /dev/nvme0n1p8 2>/dev/null; then
        echo "❌ /dev/nvme0n1p8 is currently mounted. Please unmount it first."
        exit 1
      fi

      # Show partition info
      echo "📋 Target partition: /dev/nvme0n1p8"
      sudo fdisk -l /dev/nvme0n1p8 2>/dev/null || echo "Partition details: $(lsblk /dev/nvme0n1p8 | tail -1)"
      echo ""

      read -p "⚠️  This will FORMAT /dev/nvme0n1p8 as swap. Continue? (y/N): " -n 1 -r
      echo
      if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "❌ Cancelled by user"
        exit 1
      fi

      echo ""
      echo "🔄 Setting up swap partition..."

      # Turn off existing swap file
      echo "📤 Disabling existing swap file..."
      sudo swapoff /swapfile 2>/dev/null || true

      # Remove swap file entry from fstab
      sudo sed -i '/\/swapfile/d' /etc/fstab

      # Remove the swap file
      sudo rm -f /swapfile
      echo "✅ Removed swap file"

      # Format the partition as swap
      echo "🔧 Formatting /dev/nvme0n1p8 as swap..."
      sudo mkswap /dev/nvme0n1p8

      # Enable the swap partition
      echo "🔄 Enabling swap partition..."
      sudo swapon /dev/nvme0n1p8
      echo "✅ Swap partition enabled"

      # Add to fstab
      echo "📝 Adding swap partition to /etc/fstab..."
      SWAP_UUID=$(sudo blkid -s UUID -o value /dev/nvme0n1p8)
      echo "UUID=$SWAP_UUID none swap sw 0 0" | sudo tee -a /etc/fstab
      echo "✅ Added to fstab"

      # Update GRUB configuration
      echo "⚙️  Updating GRUB configuration for partition-based hibernation..."

      GRUB_FILE="/etc/default/grub"
      BACKUP_FILE="/etc/default/grub.backup.partition.$(date +%Y%m%d_%H%M%S)"

      # Backup current GRUB config
      sudo cp "$GRUB_FILE" "$BACKUP_FILE"
      echo "📋 Backed up GRUB config to $BACKUP_FILE"

      # Remove existing resume parameters (file-based)
      sudo sed -i 's/resume=[^ "]* resume_offset=[^ "]*//' "$GRUB_FILE"
      sudo sed -i 's/resume=[^ "]*//' "$GRUB_FILE"

      # Add resume parameter for partition (no offset needed!)
      sudo sed -i "s/GRUB_CMDLINE_LINUX=\"/&resume=UUID=$SWAP_UUID /" "$GRUB_FILE"

      echo "✅ Updated GRUB configuration"
      echo ""

      # Rebuild GRUB
      echo "🔄 Rebuilding GRUB..."
      sudo grub2-mkconfig -o /boot/grub2/grub.cfg
      echo "✅ GRUB rebuilt"
      echo ""

      # Rebuild initramfs
      echo "🔄 Rebuilding initramfs..."
      sudo dracut -f
      echo "✅ Initramfs rebuilt"
      echo ""

      echo "🎉 Hibernation setup with dedicated partition complete!"
      echo ""
      echo "📋 Summary:"
      echo "  ✅ Swap partition: /dev/nvme0n1p8 (UUID: $SWAP_UUID)"
      echo "  ✅ GRUB updated: resume=UUID=$SWAP_UUID"
      echo "  ✅ No offset needed (partition-based)"
      echo ""
      echo "📋 Next steps:"
      echo "1. Reboot your system"
      echo "2. Test hibernation with: systemctl hibernate"
      echo "3. Check power states: cat /sys/power/state (should show 'disk')"
      echo ""
      echo "⚠️  IMPORTANT: Reboot required for changes to take effect!"
      echo ""
      echo "✨ Partition-based hibernation is much more reliable than Btrfs swap files!"
    '')
  ];

  # Configure GNOME power settings for hibernation
  dconf.settings = {
    "org/gnome/settings-daemon/plugins/power" = {
      # Laptop lid behavior
      lid-close-ac-action = "suspend";
      lid-close-battery-action = "hibernate";

      # Sleep timeouts (override gnome.nix settings with lib.mkForce)
      sleep-inactive-ac-timeout = lib.mkForce 3600; # 1 hour on AC
      sleep-inactive-battery-timeout = lib.mkForce 1800; # 30 minutes on battery
      sleep-inactive-ac-type = lib.mkForce
        (if hibernationConfig.enableSuspendThenHibernate then
          "suspend"
        else
          "hibernate");
      sleep-inactive-battery-type = lib.mkForce "hibernate";

      # Power button behavior
      power-button-action = "interactive"; # Show power dialog

      # Critical battery action
      critical-battery-action = "hibernate";
    };

    # Session manager logout settings
    "org/gnome/SessionManager" = {
      logout-prompt = false; # Don't prompt on logout
    };
  };

  # Create desktop entries for power actions
  xdg.desktopEntries = {
    hibernate = lib.mkIf hibernationConfig.enableHibernation {
      name = "Hibernate";
      comment = "Hibernate the system";
      exec = "systemctl hibernate";
      icon = "system-suspend-hibernate";
      categories = [ "System" ];
      noDisplay = false;
    };

    hybrid-sleep = lib.mkIf hibernationConfig.enableHybridSuspend {
      name = "Hybrid Sleep";
      comment = "Suspend to RAM and disk";
      exec = "systemctl hybrid-sleep";
      icon = "system-suspend";
      categories = [ "System" ];
      noDisplay = false;
    };

    suspend-then-hibernate =
      lib.mkIf hibernationConfig.enableSuspendThenHibernate {
        name = "Suspend then Hibernate";
        comment = "Suspend to RAM, then hibernate after delay";
        exec = "systemctl suspend-then-hibernate";
        icon = "system-suspend";
        categories = [ "System" ];
        noDisplay = false;
      };
  };

  # Shell aliases for power management
  programs.bash.shellAliases = {
    "hibernate" = "systemctl hibernate";
    "hybrid-sleep" = "systemctl hybrid-sleep";
    "suspend-hibernate" = "systemctl suspend-then-hibernate";
    "hibernation-status" = "hibernation-setup";
    "test-hibernate" = "test-hibernation";
    "fix-hibernation" = "fix-hibernation-fedora";
    "fix-hibernation-partition" = "fix-hibernation-partition";
    "hibernation-recovery" = "hibernation-recovery";
  };

  # Create hibernation status script for system info
  home.file.".local/bin/hibernation-info" = {
    executable = true;
    text = ''
      #!/usr/bin/env bash
      echo "💤 Hibernation Status for ${systemId}"
      echo "================================="
      echo "Config: ${
        if hibernationConfig.enableHibernation then "Enabled" else "Disabled"
      }"
      echo "Required swap: ${toString hibernationConfig.swapSizeGB}GB"
      echo "Hybrid suspend: ${
        if hibernationConfig.enableHybridSuspend then "Enabled" else "Disabled"
      }"
      echo "Suspend-then-hibernate: ${
        if hibernationConfig.enableSuspendThenHibernate then
          "Enabled"
        else
          "Disabled"
      }"
      echo ""
      echo "Available power states:"
      cat /sys/power/state 2>/dev/null || echo "Unable to read power states"
      echo ""
      echo "Current swap:"
      swapon --show 2>/dev/null || echo "No active swap"
    '';
  };

  # Add hibernation info to system info display
  home.activation.showHibernationStatus =
    lib.hm.dag.entryAfter [ "showSystemType" ] ''
      $DRY_RUN_CMD ~/.local/bin/hibernation-info
    '';
}
