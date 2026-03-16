{ config, pkgs, lib, ... }:

{
  # Declarative Flatpak management (via nix-flatpak module)
  services.flatpak = {
    enable = true;
    remotes = [{
      name = "flathub";
      location = "https://dl.flathub.org/repo/flathub.flatpakrepo";
    }];
    packages = [ "be.alexandervanhee.gradia" ];
    update.onActivation = true;
    uninstallUnmanaged = true;
  };

  # Use Gradia Flatpak for interactive screenshots on Print key
  dconf.settings = {
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
          "flatpak run be.alexandervanhee.gradia --screenshot=INTERACTIVE";
        name = "Gradia Interactive Screenshot";
      };

    # Register custom keybinding
    "org/gnome/settings-daemon/plugins/media-keys" = {
      custom-keybindings = [
        "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/"
      ];
    };
  };
}
