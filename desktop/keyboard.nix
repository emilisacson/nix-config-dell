{ config, pkgs, lib, ... }:

let
  # System-specific keyboard configuration
  system_id = config.systemSpecs.system_id or "unknown";

  keyboardConfigs = {
    # ThinkPad P1 Gen 4 - Swedish QWERTY only (keyd provides SVDVORAK on Keychron)
    "laptop-20Y30016MX-hybrid" = {
      defaultLayout = "se";
      secondaryLayout = "se";
      defaultIsFirst = true;
    };

    # Dell Latitude 7410 - Swedish QWERTY as primary
    "laptop-Latitude_7410-intel" = {
      defaultLayout = "se";
      secondaryLayout = "se";
      defaultIsFirst = true;
    };

    # Default configuration for unknown systems
    "default" = {
      defaultLayout = "se";
      secondaryLayout = "se";
      defaultIsFirst = true;
    };
  };

  # Get configuration for current system (fallback to default)
  keyboardConfig = keyboardConfigs.${system_id} or keyboardConfigs.default;

  # Convert layout names to proper tuples
  layoutTuples = [
    (lib.hm.gvariant.mkTuple [ "xkb" keyboardConfig.defaultLayout ])
    (lib.hm.gvariant.mkTuple [ "xkb" keyboardConfig.secondaryLayout ])
  ];

  # Determine which layout should be current (0 = first, 1 = second)
  currentLayout = if keyboardConfig.defaultIsFirst then 0 else 1;

in {
  # Install required packages for keyboard customization
  home.packages = with pkgs;
    [
      # Note: keyd is installed system-wide via dnf for SVDVORAK Ctrl overlay support
      # Keychron Q11: Full SVDVORAK layout provided by keyd
      # Laptop keyboard: Swedish QWERTY from GNOME (unaffected by keyd)
      # Config: /etc/keyd/default.conf
      # Service: sudo systemctl status keyd
      # Setup: ~/.nix-config/extras/setup-keyd.sh
    ];

  # Configure dual keyboard layout based on system configuration
  dconf.settings = {
    # Dual keyboard layout configuration
    "org/gnome/desktop/input-sources" = {
      sources = layoutTuples;
      xkb-options = [
        "terminate:ctrl_alt_bksp"
        "lv3:ralt_switch" # Right Alt as AltGr for special characters
      ];
      current = currentLayout;
    };
  };

  # Note: Custom keyboard autostart removed - using keyd instead
  # keyd provides Wayland-compatible Ctrl overlay functionality
  # The old XKB approach doesn't work reliably under Wayland
  # To reinstall: sudo dnf install keyd && sudo systemctl enable --now keyd
  # Config location: /etc/keyd/default.conf

  # Add an activation script to set keyboard layouts based on system config
  home.activation.setSystemKeyboard =
    lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      if command -v gsettings &> /dev/null; then
        # Clear any existing XKB options that might interfere
        $DRY_RUN_CMD gsettings set org.gnome.desktop.input-sources xkb-options "[]"
        
        # Set both keyboard layouts based on system configuration
        $DRY_RUN_CMD gsettings set org.gnome.desktop.input-sources sources "[('xkb', '${keyboardConfig.defaultLayout}'), ('xkb', '${keyboardConfig.secondaryLayout}')]"
        
        # Set xkb options after a brief delay
        $DRY_RUN_CMD gsettings set org.gnome.desktop.input-sources xkb-options "['terminate:ctrl_alt_bksp', 'lv3:ralt_switch']"
        
        # Set default layout based on system configuration
        $DRY_RUN_CMD gsettings set org.gnome.desktop.input-sources current ${
          toString currentLayout
        }
      fi
    '';

  # Setup keyd for Wayland Ctrl overlay support
  home.activation.setupKeyd = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    echo "Checking keyd configuration for SVDVORAK Ctrl overlay..."
    if [ ! -f /etc/keyd/default.conf ]; then
      echo "⚠️  keyd not configured."
      echo "    Run: ~/.nix-config/extras/setup-keyd.sh"
    elif ! /usr/bin/systemctl is-active --quiet keyd 2>/dev/null; then
      echo "⚠️  keyd not running."
      echo "    Run: sudo systemctl start keyd"
    else
      echo "✅ keyd is active - Ctrl overlay working"
    fi
  '';

  # Script to reset keyboard if keyd causes issues
  home.file.".local/bin/fix-keyboard" = {
    text = ''
      #!/usr/bin/env bash
      # Reset keyboard and restart keyd if needed
      echo "Resetting keyboard configuration..."

      # Reset GNOME keyboard settings
      gsettings set org.gnome.desktop.input-sources sources "[('xkb', '${keyboardConfig.defaultLayout}'), ('xkb', '${keyboardConfig.secondaryLayout}')]"
      gsettings set org.gnome.desktop.input-sources xkb-options "['terminate:ctrl_alt_bksp', 'lv3:ralt_switch']"
      gsettings set org.gnome.desktop.input-sources current ${
        toString currentLayout
      }

      # Restart keyd if it's installed
      if systemctl is-active --quiet keyd; then
        echo "Restarting keyd service..."
        sudo systemctl restart keyd
        notify-send "Keyboard Reset" "Keyboard layout and keyd restarted"
      else
        notify-send "Keyboard Reset" "Keyboard layout reset (keyd not running)"
      fi
    '';
    executable = true;
  };
}
