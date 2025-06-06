{ config, pkgs, lib, ... }:

{
  # Import extensions configuration
  imports = [ ./extensions/extensions.nix ];

  # Enable GNOME desktop environment configuration
  home.packages = with pkgs; [
    gnome-tweaks
    gnome-extension-manager
    gnome-browser-connector # Allows browser integration for extensions.gnome.org
    chrome-gnome-shell # Browser connector for Chrome/Firefox
    gnome-shell-extensions
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
      default-folder-viewer = "list-view";
      search-filter-time-type = "last_modified";
      show-create-link = true;
      show-directory-item-counts = "always";
      default-sort-order = "name";
      default-sort-in-reverse-order = false;
    };

    # List view specific settings
    "org/gnome/nautilus/list-view" = {
      default-folder-viewer = "list-view";
      use-tree-view = false;
    };

    # Icon view settings (for consistency)
    "org/gnome/nautilus/icon-view" = { default-zoom-level = "standard"; };

    "org/gnome/shell" = {
      disable-user-extensions = false;
      development-tools = true; # Enable development tools for extensions
      disable-extension-version-validation =
        true; # Allow installing extensions for different GNOME versions
    };

    # Default applications
    "org/gnome/desktop/default-applications/office" = {
      calendar = "org.gnome.Calendar.desktop";
      tasks = "org.gnome.Evolution.desktop";
    };

    "org/gnome/settings-daemon/plugins/media-keys" = {
      email-client = "org.gnome.Evolution.desktop";
    };

    # Set default browser
    "org/gnome/desktop/default-applications/web" = {
      browser = "brave-browser.desktop";
    };
  };
}
