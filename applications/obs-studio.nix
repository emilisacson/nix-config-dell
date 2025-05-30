{ pkgs, lib, nixgl ? { }, systemConfig ? null, ... }:

{ # Install OBS Studio with nixGL wrapper for graphics support
  home.packages = with pkgs; [
    # Regular OBS Studio package
    obs-studio

    # Install nixGL for OpenGL support (it's available through the overlay)
    nixgl
  ];

  # Create a wrapper script for OBS Studio with nixGL
  home.file.".local/bin/obs-nixgl" = {
    text = ''
      #!/usr/bin/env bash
      # OBS Studio launcher with nixGL for graphics support

      if command -v nixGL &> /dev/null; then
          echo "Using nixGL for OBS Studio..."
          exec nixGL obs
      else
          echo "nixGL not found, trying to run OBS Studio directly..."
          echo "If this fails, make sure nixGL is properly installed."
          exec obs
      fi
    '';
    executable = true;
  };

  # Add all desktop entries in a single definition to avoid duplicated attribute errors
  xdg.desktopEntries = {
    # Base OBS Studio entry with nixGL wrapper
    obs-studio = {
      name = "OBS Studio (with nixGL)";
      comment =
        "Free and open source software for live streaming and screen recording";
      exec = "obs-nixgl";
      icon = "com.obsproject.Studio";
      terminal = false;
      categories = [ "AudioVideo" "Recorder" ];
      mimeType = [ "application/x-obs-scene" ];
      startupNotify = true;
    };
  };

  # Declaratively override the default com.obsproject.Studio.desktop
  # to hide it, ensuring the nixGL version is preferred.
  home.file.".local/share/applications/com.obsproject.Studio.desktop" = {
    text = ''
      [Desktop Entry]
      Name=OBS Studio (Default - Hidden by Nix)
      Comment=Default OBS Studio entry, hidden by Nix to prefer nixGL version
      NoDisplay=true
      Type=Application
    '';
  };
}
