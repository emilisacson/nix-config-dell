{ config, pkgs, lib, ... }:

{
  # Install Flameshot with required tools
  home.packages = with pkgs; [
    (flameshot.override {
      enableWlrSupport = true;
    }) # Screenshot tool with Wayland support
    util-linux # For script command (needed by wrapper)
  ];

  # Create Screenshots directory for Flameshot
  home.file."Pictures/Screenshots/.keep".text = "";

  # Deploy Flameshot configuration file
  home.file.".config/flameshot/flameshot.ini" = {
    source = ../extras/flameshot.ini;
    force = true;
  };

  # Configure Flameshot keybindings and disable GNOME screenshot
  dconf.settings = {
    # Replace GNOME screenshot tool with Flameshot
    # Disable default GNOME screenshot keybindings
    "org/gnome/shell/keybindings" = {
      screenshot = [ ];
      show-screenshot-ui = [ ];
      screenshot-window = [ ];
    };

    "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0" =
      {
        binding = "Print";
        command =
          "script --command 'QT_QPA_PLATFORM=wayland flameshot gui --clipboard' /dev/null";
        name = "Flameshot GUI";
      };

    "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom1" =
      {
        binding = "<Shift>Print";
        command =
          "script --command 'QT_QPA_PLATFORM=wayland flameshot full --clipboard -p $HOME/Pictures/Screenshots' /dev/null";
        name = "Flameshot Full Screen";
      };

    "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom2" =
      {
        binding = "<Alt>Print";
        command =
          "script --command 'QT_QPA_PLATFORM=wayland flameshot screen --clipboard -p $HOME/Pictures/Screenshots' /dev/null";
        name = "Flameshot Current Screen";
      };

    # Configure media keys - register custom keybindings
    "org/gnome/settings-daemon/plugins/media-keys" = {
      custom-keybindings = [
        "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/"
        "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom1/"
        "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom2/"
      ];
    };
  };
}
