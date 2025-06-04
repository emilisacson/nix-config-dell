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
      default-folder-viewer = "icon-view";
      search-filter-time-type = "last_modified";
      show-create-link = true;
    };

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

    # GSConnect settings
    "org/gnome/shell/extensions/gsconnect" = {
      enabled = true;
      show-indicators = true;
      show-status-icon = true;
    };

    # GNOME Shell Extensions settings - Allow network access
    "org/gnome/shell/extensions" = {
      allowed-extensions = [ "extensions.gnome.org" "localhost" ];
      user-extensions-enabled = true;
    };

    # Vitals extension settings
    "org/gnome/shell/extensions/vitals" = {
      hot-sensors = [ "_processor_usage_" "_memory_usage_" "_gpu_usage_" ];
      position-in-panel =
        0; # Position in top panel (0 = left, 1 = center, 2 = right)
      show-battery = true;
      show-cpu = true;
      show-memory = true;
      show-network = true;
      show-temperature = true;
      show-gpu = true;
      update-time = 2; # Update interval in seconds
    };

    # ddterm (drop-down terminal) settings
    "org/gnome/shell/extensions/ddterm" = {
      ddterm-toggle-hotkey =
        [ "<Super>grave" ]; # Super + ` (backtick) to toggle
      window-position = "top";
      window-size = 0.25; # 25% of screen height
      window-monitor = "primary";
      tab-policy = "automatic";
      hide-when-focus-lost = true;
      animation-time = 0.2;
    };

    # Caffeine extension settings (already enabled, adding config)
    "org/gnome/shell/extensions/caffeine" = {
      indicator-position-max = 2; # Position in system tray
      show-indicator = "always";
      show-notifications = true;
      enable-fullscreen = true; # Auto-enable when fullscreen apps are running
    };
  };
}
