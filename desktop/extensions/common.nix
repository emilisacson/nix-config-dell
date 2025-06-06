{ config, lib, ... }:

{
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
    ddterm-toggle-hotkey = [ "<Super>grave" ]; # Super + ` (backtick) to toggle
    window-position = "top";
    window-size = 0.25; # 25% of screen height
    window-monitor = "primary";
    tab-policy = "automatic";
    hide-when-focus-lost = true;
    animation-time = 0.2;
  };

  # Caffeine extension settings
  "org/gnome/shell/extensions/caffeine" = {
    indicator-position-max = 2; # Position in system tray
    show-indicator = "always";
    show-notifications = true;
    enable-fullscreen = true; # Auto-enable when fullscreen apps are running
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

  # Tiling Assistant settings (can be expanded as needed)
  "org/gnome/shell/extensions/tiling-assistant" = {
    # Add tiling assistant specific settings here if needed
    # This extension typically works well with default settings
  };
}
