{ config, pkgs, lib, ... }:

{
  # Discord configuration with additional fixes for Fedora
  home.packages = with pkgs;
    [
      # Include Discord package for icons and dependencies
      # The actual launcher will use our wrapper script
      discord
    ];

  # Create a wrapper script for Discord with fixes for Fedora
  home.file.".local/bin/discord-fixed" = {
    executable = true;
    text = ''
      #!/usr/bin/env bash

      # Wrapper script for Discord with fixes for Fedora
      # This helps avoid the "Invalid argument (22)" crash

      # Set environment variables to avoid crashes
      export NIXOS_OZONE_WL=1
      export DISABLE_DISCORD_SANDBOX=1

      # Set Chrome flags to work around common issues
      DISCORD_FLAGS="--no-sandbox --disable-gpu-sandbox --disable-seccomp-filter-sandbox --disable-setuid-sandbox"

      # For Wayland
      if [[ "$XDG_SESSION_TYPE" == "wayland" ]]; then
        DISCORD_FLAGS="$DISCORD_FLAGS --enable-features=WaylandWindowDecorations --ozone-platform-hint=auto"
      fi

      # Run Discord with the flags
      exec ${pkgs.discord}/bin/discord $DISCORD_FLAGS "$@"
    '';
  };

  # Create a desktop entry that uses our fixed launcher
  xdg.desktopEntries.discord = {
    name = "Discord";
    genericName = "Discord Chat";
    exec = "${config.home.homeDirectory}/.local/bin/discord-fixed %U";
    icon = "discord";
    comment = "Chat, voice, and video communication platform";
    categories = [ "Network" "InstantMessaging" "Chat" ];
    terminal = false;
    startupNotify = true;
    type = "Application";
    settings = {
      Keywords = "chat;voice;video;community;";
      StartupWMClass = "discord";
      X-GNOME-UsesNotifications = "true";
    };
  };
}
