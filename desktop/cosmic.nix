{ config, pkgs, systemConfig ? null, ... }:

{
  # Enable cosmic-manager base configuration
  programs.cosmic-manager = { enable = true; };

  # Configure COSMIC desktop settings
  wayland.desktopManager.cosmic = {
    enable = true;
    applets.time.settings = {
      military_time = true; # Enable 24-hour time format
      show_date_in_top_panel = true;
      show_seconds = true;
      show_weekday = true;
      first_day_of_week = 0; # Monday
    };
  };
}
