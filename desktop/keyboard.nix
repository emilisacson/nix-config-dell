{ config, pkgs, lib, ... }:

{
  # Install required packages for keyboard customization
  home.packages = with pkgs; [
    xorg.xkbcomp # Add xkbcomp for custom keyboard layouts
    libnotify # For notify-send in the script
  ];

  # Configure dual keyboard layout - SVDVORAK and Swedish QWERTY
  dconf.settings = {
    # Dual keyboard layout configuration
    "org/gnome/desktop/input-sources" = {
      sources = [
        (lib.hm.gvariant.mkTuple [ "xkb" "se+svdvorak" ]) # SVDVORAK as primary
        (lib.hm.gvariant.mkTuple [ "xkb" "se" ]) # Swedish QWERTY as secondary
      ];
      xkb-options = [
        "terminate:ctrl_alt_bksp"
        "lv3:ralt_switch" # Right Alt as AltGr for special characters
      ];
      current = 1; # SVDVORAK as default
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

  # Add an activation script to set keyboard layouts directly
  home.activation.setSwedishKeyboard =
    lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      if command -v gsettings &> /dev/null; then
        # Clear any existing XKB options that might interfere
        $DRY_RUN_CMD gsettings set org.gnome.desktop.input-sources xkb-options "[]"
        
        # Set both keyboard layouts - SVDVORAK and Swedish QWERTY
        $DRY_RUN_CMD gsettings set org.gnome.desktop.input-sources sources "[('xkb', 'se+svdvorak'), ('xkb', 'se')]"
        
        # Set xkb options after a brief delay
        $DRY_RUN_CMD gsettings set org.gnome.desktop.input-sources xkb-options "['terminate:ctrl_alt_bksp', 'lv3:ralt_switch']"
        
        # Set svdvorak as default
        $DRY_RUN_CMD gsettings set org.gnome.desktop.input-sources current 0
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
