{ config, pkgs, lib, ... }:

{
  # Enable GNOME desktop environment configuration
  home.packages = with pkgs; [
    gnome-tweaks
    gnome-extension-manager
    gnome-browser-connector # Allows browser integration for extensions.gnome.org
    chrome-gnome-shell # Browser connector for Chrome/Firefox
    gnome-shell-extensions
    gnomeExtensions.dash-to-panel # For all monitors with configurable positions
    gnomeExtensions.gsconnect # Add GSConnect extension
    gnomeExtensions.tiling-assistant # Advanced window tiling with multi-monitor support
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

      enabled-extensions = [
        "appindicatorsupport@rgcjonas.gmail.com"
        "caffeine@patapon.info"
        "dash-to-panel@jderose9.github.com" # Add Dash to Panel extension
        "gsconnect@andyholmes.github.io" # Enable GSConnect extension
        "tiling-assistant@leleat-on-github" # Tiling assistant
        "status-icons@gnome-shell-extensions.gcampax.github.com"
        "system-monitor@gnome-shell-extensions.gcampax.github.com"
      ];
    };

    # Dash to Panel settings (for multi-monitor setup)
    "org/gnome/shell/extensions/dash-to-panel" = {
      animate-appicon-hover-animation-extent =
        ''{"RIPPLE": 4, "PLANK": 4, "SIMPLE": 1}'';
      appicon-margin = 8;
      appicon-padding = 4;
      dot-position = "LEFT";
      dot-style-focused = "METRO";
      dot-style-unfocused = "DOTS";
      extension-version = 68;
      group-apps = true;
      hotkeys-overlay-combo = "TEMPORARILY";
      intellihide = false;
      isolate-monitors = true;
      isolate-workspaces = true;
      multi-monitors = true;
      panel-anchors = ''
        {"AOC-PCSN4JA000069":"MIDDLE","LGD-0x00000000":"MIDDLE","AOC-PCSN4JA000072":"MIDDLE"}'';
      panel-element-positions = ''
        {"AOC-PCSN4JA000069":[{"element":"showAppsButton","visible":true,"position":"stackedTL"},{"element":"activitiesButton","visible":false,"position":"stackedTL"},{"element":"leftBox","visible":true,"position":"stackedTL"},{"element":"taskbar","visible":true,"position":"centerMonitor"},{"element":"centerBox","visible":true,"position":"centerMonitor"},{"element":"rightBox","visible":true,"position":"stackedBR"},{"element":"dateMenu","visible":true,"position":"stackedBR"},{"element":"systemMenu","visible":true,"position":"stackedBR"},{"element":"desktopButton","visible":true,"position":"stackedBR"}]}'';
      panel-element-positions-monitors-sync = false;
      panel-lengths =
        ''{"AOC-PCSN4JA000069":-1,"LGD-0x00000000":-1,"AOC-PCSN4JA000072":-1}'';
      panel-positions = ''
        {"AOC-PCSN4JA000069":"TOP","LGD-0x00000000":"RIGHT","AOC-PCSN4JA000072":"RIGHT"}'';
      panel-sizes = ''{"AOC-PCSN4JA000069":48}'';
      prefs-opened = true;
      primary-monitor = "AOC-PCSN4JA000069";
      show-favorites = true;
      show-running-apps = true;
      show-window-previews = true;
      stockgs-keep-top-panel = false;
      stockgs-panelbtn-click-only = false;
      trans-panel-opacity = 0.8;
      trans-use-custom-opacity = true;
      trans-use-dynamic-opacity = true;
      tray-size = 16;
      window-preview-title-position = "TOP";
    };

    # Default applications
    "org/gnome/desktop/applications/browser" = { exec = "brave"; };

    # Set Evolution as default email client
    "org/gnome/desktop/applications/mail" = { exec = "evolution"; };

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
  };
}
