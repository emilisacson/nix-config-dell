{ config, pkgs, lib, ... }:

{
  # Install Evolution and related packages
  home.packages = with pkgs; [
    evolution
    evolution-data-server
    gnome.gnome-calendar
    gnome-online-accounts # For online account integration
  ];

  # Configure Evolution dconf settings
  dconf.settings = {
    # General Evolution settings
    "org/gnome/evolution/mail" = {
      layout = 1; # 0 = classic view, 1 = vertical view
      forward-style-name = "attached"; # Forwarding style: inline, attached, quoted
      reply-style-name = "quoted"; # Reply style
      composer-reply-start-bottom = true; # Start typing at the bottom when replying
    };

    # Default folder settings
    "org/gnome/evolution/mail/folder-settings" = {
      show-to-do-bar = true; # Show To-Do bar
      show-deleted = true; # Show deleted emails
    };

    # Calendar settings
    "org/gnome/evolution/calendar" = {
      use-24hour-format = true; # Use 24-hour format for time
      week-start-day-name = "monday"; # Start week on Monday
      show-week-numbers = true; # Show week numbers
      editor-show-timezone = true; # Show time zone in editor
    };
  };
}
