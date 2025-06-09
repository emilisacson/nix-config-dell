{ pkgs, ... }:

{
  # Install OBS Studio with nixGL wrapper for graphics support
  home.packages = with pkgs; [
    # Regular OBS Studio package
    obs-studio

    # nixGL wrappers for different graphics configurations
    nixgl.auto.nixGLDefault # Auto-detect (recommended)
    nixgl.auto.nixGLNvidia # Nvidia proprietary drivers
    nixgl.nixGLIntel # Intel/Mesa drivers
  ];

  # Create a wrapper script for OBS Studio with nixGL
  home.file.".local/bin/obs-nixgl" = {
    text = ''
      #!/usr/bin/env bash
      # OBS Studio launcher with nixGL for graphics support

      # Try to detect the best nixGL wrapper to use
      if command -v nixGLDefault &> /dev/null; then
          echo "Using nixGLDefault (auto-detect) for OBS Studio..."
          exec nixGLDefault obs &
      elif command -v nixGLNvidia &> /dev/null; then
          echo "Using nixGLNvidia for OBS Studio..."
          exec nixGLNvidia obs &
      elif command -v nixGLIntel &> /dev/null; then
          echo "Using nixGLIntel for OBS Studio..."
          exec nixGLIntel obs &
      else
          echo "No nixGL wrapper found, trying to run OBS Studio directly..."
          echo "If this fails, make sure nixGL is properly installed."
          exec obs &
      fi
    '';
    executable = true;
  };

  # Create desktop entry for OBS Studio with nixGL
  xdg.desktopEntries.obs-studio = {
    name = "OBS Studio (with nixGL)";
    comment =
      "Free and open source software for live streaming and screen recording";
    exec = "obs-nixgl"; # Changed to run the custom wrapper script
    icon = "com.obsproject.Studio";
    terminal = false;
    categories = [ "AudioVideo" "Recorder" ];
    mimeType = [ "application/x-obs-scene" ];
    startupNotify = true;
  };

  # Alternative desktop entries for specific graphics drivers
  xdg.desktopEntries.obs-studio-nvidia = {
    name = "OBS Studio (Nvidia)";
    comment = "OBS Studio with Nvidia graphics support";
    exec =
      "${pkgs.nixgl.auto.nixGLNvidia}/bin/nixGLNvidia ${pkgs.obs-studio}/bin/obs";
    icon = "com.obsproject.Studio";
    terminal = false;
    categories = [ "AudioVideo" "Recorder" ];
    noDisplay = true; # Hidden by default, available if needed
  };

  xdg.desktopEntries.obs-studio-intel = {
    name = "OBS Studio (Intel)";
    comment = "OBS Studio with Intel graphics support";
    exec = "${pkgs.nixgl.nixGLIntel}/bin/nixGLIntel ${pkgs.obs-studio}/bin/obs";
    icon = "com.obsproject.Studio";
    terminal = false;
    categories = [ "AudioVideo" "Recorder" ];
    noDisplay = true; # Hidden by default, available if needed
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
    # This ensures the file is created if it doesn't exist, or overwritten if it does.
    # It will be managed by Home Manager.
  };
}
