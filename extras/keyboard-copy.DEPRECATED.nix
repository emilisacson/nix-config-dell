{ config, pkgs, lib, ... }:

let
  # System-specific keyboard configuration
  system_id = config.systemSpecs.system_id or "unknown";

  keyboardConfigs = {
    # ThinkPad P1 Gen 4 - SVDVORAK as primary
    "laptop-20Y30016MX-hybrid" = {
      defaultLayout = "se+svdvorak";
      secondaryLayout = "se";
      defaultIsFirst = true; # SVDVORAK is default
    };

    # Dell Latitude 7410 - Swedish QWERTY as primary
    "laptop-Latitude_7410-intel" = {
      defaultLayout = "se";
      secondaryLayout = "se+svdvorak";
      defaultIsFirst = true; # Swedish is default
    };

    # Default configuration for unknown systems
    "default" = {
      defaultLayout = "se";
      secondaryLayout = "se+svdvorak";
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
  home.packages = with pkgs; [
    xorg.xkbcomp # Add xkbcomp for custom keyboard layouts
    libnotify # For notify-send in the script
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

  # Create autostart entry for the custom keyboard setup script
  xdg.configFile."autostart/custom-keyboard.desktop" = {
    text = ''
      [Desktop Entry]
      Name=Custom Keyboard Layout
      Exec=${config.home.homeDirectory}/.nix-config/extras/setup-custom-keyboard.sh
      Comment=Load custom keyboard configuration for Ctrl key behavior
      Categories=Utility;
      Terminal=false
      StartupNotify=false
      Type=Application
    '';
    executable = true;
  };

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

  # Add a script to reset keyboard state when things get confused
  home.file.".local/bin/fix-keyboard" = {
    text = ''
      #!/usr/bin/env bash
      # Reset keyboard layout state when it gets confused
      echo "Resetting keyboard layout state..."

      # Clear XKB state
      setxkbmap -option ""

      # Reset to basic Swedish layout
      setxkbmap -layout se -variant ""

      # Wait a moment
      sleep 1

      # Reapply the custom layout via autostart script
      ${config.home.homeDirectory}/.nix-config/extras/setup-custom-keyboard.sh &

      notify-send "Keyboard Reset" "Layout state cleared and custom layout reloading..."
    '';
    executable = true;
  };
}
