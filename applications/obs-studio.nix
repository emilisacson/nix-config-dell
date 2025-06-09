{ config, pkgs, lib, ... }:

{
  # Install OBS Studio with nixGL wrapper for graphics support
  home.packages = with pkgs;
    [
      # Regular OBS Studio package
      obs-studio

      # nixGL wrappers based on detected hardware
      nixgl.auto.nixGLDefault # Auto-detect (always included)
    ] ++ lib.optionals config.systemSpecs.hasNvidiaGPU [
      nixgl.auto.nixGLNvidia # Only include if Nvidia GPU detected
    ] ++ lib.optionals config.systemSpecs.hasIntelGPU [
      nixgl.nixGLIntel # Only include if Intel GPU detected
    ];

  # Create a wrapper script for OBS Studio with nixGL
  home.file.".local/bin/obs-nixgl" = {
    text = ''
      #!/usr/bin/env bash
      # OBS Studio launcher with nixGL for graphics support

      # Try to detect the best nixGL wrapper to use
      if command -v nixGLDefault &> /dev/null; then
          echo "Using nixGLDefault (auto-detect) for OBS Studio..."
          exec nixGLDefault obs "$@"
      elif command -v nixGLNvidia &> /dev/null; then
          echo "Using nixGLNvidia for OBS Studio..."
          exec nixGLNvidia obs "$@"
      elif command -v nixGLIntel &> /dev/null; then
          echo "Using nixGLIntel for OBS Studio..."
          exec nixGLIntel obs "$@"
      else
          echo "No nixGL wrapper found, trying to run OBS Studio directly..."
          echo "If this fails, make sure nixGL is properly installed."
          exec obs "$@"
      fi
    '';
    executable = true;
  };

  # Note: Main desktop entry is created below via home.file override
  # This ensures proper taskbar integration with the expected filename

  # Alternative desktop entries for specific graphics drivers - only create if GPU is available
  xdg.desktopEntries.obs-studio-nvidia =
    lib.mkIf config.systemSpecs.hasNvidiaGPU {
      name = "OBS Studio (Nvidia)";
      comment = "OBS Studio with Nvidia graphics support";
      exec = "nixGLNvidia obs";
      icon = "com.obsproject.Studio";
      terminal = false;
      categories = [ "AudioVideo" "Recorder" ];
      noDisplay = true; # Hidden by default, available if needed
      startupNotify = true;
    };

  xdg.desktopEntries.obs-studio-intel =
    lib.mkIf config.systemSpecs.hasIntelGPU {
      name = "OBS Studio (Intel)";
      comment = "OBS Studio with Intel graphics support";
      exec = "nixGLIntel obs";
      icon = "com.obsproject.Studio";
      terminal = false;
      categories = [ "AudioVideo" "Recorder" ];
      noDisplay = true; # Hidden by default, available if needed
      startupNotify = true;
    };

  # Override the default com.obsproject.Studio.desktop with our nixGL version
  # This ensures proper taskbar integration by using the expected desktop file name
  home.file.".local/share/applications/com.obsproject.Studio.desktop" = {
    text = ''
      [Desktop Entry]
      Version=1.0
      Type=Application
      Name=OBS Studio (nixGL)
      Comment=Free and open source software for live streaming and screen recording
      Exec=obs-nixgl
      Icon=com.obsproject.Studio
      Terminal=false
      Categories=AudioVideo;Recorder;
      MimeType=application/x-obs-scene;
      StartupNotify=true
      StartupWMClass=obs
      Keywords=streaming;recording;broadcast;
    '';
    # This completely replaces the original desktop file for proper taskbar integration
  };
}
