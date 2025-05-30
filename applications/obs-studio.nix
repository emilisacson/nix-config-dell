{ pkgs, lib, nixgl ? { }, systemConfig ? null, ... }:

{
  # Install OBS Studio with nixGL wrapper for graphics support
  home.packages = with pkgs;
    [
      # Regular OBS Studio package
      obs-studio

      # Include appropriate nixGL wrappers based on system detection
    ] ++ (if systemConfig != null && systemConfig ? currentSystem
    && systemConfig.currentSystem ? hasNvidia && systemConfig.currentSystem
    ? hasIntel then
      (if systemConfig.currentSystem.hasNvidia && nixgl ? auto && nixgl.auto
      ? nixGLNvidia then [
        nixgl.auto.nixGLDefault # Auto-detect (recommended)
        nixgl.auto.nixGLNvidia # Nvidia proprietary drivers
      ] else
        [ ])
      ++ (if systemConfig.currentSystem.hasIntel && nixgl ? nixGLIntel then
        [
          nixgl.nixGLIntel # Intel/Mesa drivers
        ]
      else if systemConfig.currentSystem.hasIntel && nixgl ? auto && nixgl.auto
      ? nixGLDefault then
        [
          nixgl.auto.nixGLDefault # Fallback for Intel
        ]
      else
        [ ])
    else
    # Fallback if systemConfig is not available - include available wrappers
      (if nixgl ? auto && nixgl.auto ? nixGLDefault then
        [ nixgl.auto.nixGLDefault ]
      else
        [ ]) ++ (if nixgl ? nixGLIntel then [ nixgl.nixGLIntel ] else [ ])
      ++ lib.optionals (nixgl ? auto && nixgl.auto ? nixGLNvidia)
      [ nixgl.auto.nixGLNvidia ]);

  # Create a wrapper script for OBS Studio with nixGL
  home.file.".local/bin/obs-nixgl" = {
    text = ''
      #!/usr/bin/env bash
      # OBS Studio launcher with nixGL for graphics support

      # Try to detect the best nixGL wrapper to use
      if command -v nixGLDefault &> /dev/null; then
          echo "Using nixGLDefault (auto-detect) for OBS Studio..."
          exec nixGLDefault obs
      elif command -v nixGLNvidia &> /dev/null; then
          echo "Using nixGLNvidia for OBS Studio..."
          exec nixGLNvidia obs
      elif command -v nixGLIntel &> /dev/null; then
          echo "Using nixGLIntel for OBS Studio..."
          exec nixGLIntel obs
      else
          echo "No nixGL wrapper found, trying to run OBS Studio directly..."
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
  }
  # Conditionally add Nvidia entry
    // lib.optionalAttrs (nixgl ? auto && nixgl.auto ? nixGLNvidia) {
      obs-studio-nvidia = {
        name = "OBS Studio (Nvidia)";
        comment = "OBS Studio with Nvidia graphics support";
        exec =
          "${nixgl.auto.nixGLNvidia}/bin/nixGLNvidia ${pkgs.obs-studio}/bin/obs";
        icon = "com.obsproject.Studio";
        terminal = false;
        categories = [ "AudioVideo" "Recorder" ];
        noDisplay = true; # Hidden by default, available if needed
      };
    }
    # Conditionally add Intel entry
    // lib.optionalAttrs (nixgl ? nixGLIntel) {
      obs-studio-intel = {
        name = "OBS Studio (Intel)";
        comment = "OBS Studio with Intel graphics support";
        exec = "${nixgl.nixGLIntel}/bin/nixGLIntel ${pkgs.obs-studio}/bin/obs";
        icon = "com.obsproject.Studio";
        terminal = false;
        categories = [ "AudioVideo" "Recorder" ];
        noDisplay = true; # Hidden by default, available if needed
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
