{ config, pkgs, lib, ... }:

{
  # Install required packages for keyboard customization
  home.packages = with pkgs; [
    xorg.xkbcomp # Add xkbcomp for custom keyboard layouts
    libnotify    # For notify-send in the script
  ];

  # Configure dual keyboard layout - SVDVORAK and Swedish QWERTY
  dconf.settings = {
    # Dual keyboard layout configuration
    "org/gnome/desktop/input-sources" = {
      sources = [
        (lib.hm.gvariant.mkTuple [ "xkb" "se+svdvorak" ]) # SVDVORAK as primary
        (lib.hm.gvariant.mkTuple [ "xkb" "se" ])        # Swedish QWERTY as secondary
      ];
      xkb-options = [ 
        "terminate:ctrl_alt_bksp"
        "lv3:ralt_switch"        # Right Alt as AltGr for special characters
      ];
      current = 0; # SVDVORAK as default
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
        # Set both keyboard layouts - SVDVORAK and Swedish QWERTY
        $DRY_RUN_CMD gsettings set org.gnome.desktop.input-sources sources "[('xkb', 'se+svdvorak'), ('xkb', 'se')]"
        
        # Set xkb options
        $DRY_RUN_CMD gsettings set org.gnome.desktop.input-sources xkb-options "['terminate:ctrl_alt_bksp', 'lv3:ralt_switch']"
      fi
    '';
}
