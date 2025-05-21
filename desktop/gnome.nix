{ config, pkgs, lib, ... }:

{
  # Enable GNOME desktop environment configuration
  home.packages = with pkgs; [
    gnome-tweaks
    gnome-extension-manager
    gnome-shell-extensions
    gnomeExtensions.dash-to-dock
    gnomeExtensions.gsconnect # Add GSConnect extension
    # adw-gtk3
  ];

  # Configure dconf settings for GNOME
  dconf.settings = {
    # Interface preferences
    "org/gnome/desktop/interface" = {
      color-scheme = "prefer-dark";
      enable-hot-corners = false;
      font-antialiasing = "rgba";
      gtk-theme = "adw-gtk3-dark";
      show-battery-percentage = true;
      clock-format = "24h";
      clock-show-seconds = true;
    };

    # Language and locale settings
    "org/gnome/system/locale" = { region = "sv_SE.UTF-8"; };
    "system/locale" = { region = "sv_SE.UTF-8"; };

    # Date and time format for Swedish locale
    "org/gnome/desktop/calendar" = { show-weekdate = true; };

    # Window manager preferences
    "org/gnome/desktop/wm/preferences" = {
      button-layout = "appmenu:minimize,maximize,close";
      focus-mode = "click";
    };

    # Power settings
    "org/gnome/settings-daemon/plugins/power" = {
      sleep-inactive-ac-type = "nothing";
    };

    # File manager settings
    "org/gnome/nautilus/preferences" = {
      default-folder-viewer = "icon-view";
      search-filter-time-type = "last_modified";
      show-create-link = true;
    };

    "org/gnome/shell" = {
      disable-user-extensions = false;

      enabled-extensions = [
        "appindicatorsupport@rgcjonas.gmail.com"
        "caffeine@patapon.info"
        "dash-to-dock@micxgx.gmail.com"
        "launch-new-instance@gnome-shell-extensions.gcampax.github.com"
        "gsconnect@andyholmes.github.io" # Enable GSConnect extension
      ];
    };

    # Dock settings
    "org/gnome/shell/extensions/dash-to-dock" = {
      background-opacity = 0.8;
      click-action = "previews";
      custom-theme-shrink = true;
      dash-max-icon-size = 32;
      dock-fixed = true;
      dock-position = "LEFT";
      extend-height = true;
      height-fraction = 0.9;
      intellihide-mode = "FOCUS_APPLICATION_WINDOWS";
    };

    # Default applications
    "org/gnome/desktop/applications/browser" = { exec = "brave"; };
    
    # GSConnect settings
    "org/gnome/shell/extensions/gsconnect" = {
      enabled = true;
      show-indicators = true;
      show-status-icon = true;
    };
  };
}
