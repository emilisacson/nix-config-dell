{ config, pkgs, lib, ... }:

let
  # Only enable Obsidian on specific systems
  systemSpecs = config.systemSpecs;
  systemId = systemSpecs.system_id or "unknown";
  enableObsidian = systemId
    == "laptop-20Y30016MX-hybrid"; # "laptop-Latitude_7410-intel";

in lib.mkIf enableObsidian {
  home.packages = with pkgs;
    [
      obsidian

      # nixGL wrappers - include both Intel and NVIDIA with explicit version
      nixgl.auto.nixGLDefault # Auto-detect (always included)
    ] ++ lib.optionals (config.systemSpecs.hasIntelGPU or false) [
      nixgl.nixGLIntel # Include Intel support
    ] ++ lib.optionals (config.systemSpecs.hasNvidiaGPU or false) [
      # Use explicit NVIDIA version to avoid auto-detection issues
      (nixgl.override { nvidiaVersion = "575.64.03"; }).auto.nixGLNvidia
    ];

  # Wrapper script to launch Obsidian with nixGL
  home.file.".local/bin/obsidian-nixgl" = {
    text = ''
      #!/usr/bin/env bash
      # Obsidian launcher with nixGL for graphics support

      # Try to detect the best nixGL wrapper to use (prefer specific NVIDIA version that works)
      if command -v nixGLNvidia-575.64.03 &> /dev/null; then
          echo "Using nixGLNvidia-575.64.03 for Obsidian..."
          exec nixGLNvidia-575.64.03 obsidian "$@"
      elif command -v nixGLNvidia &> /dev/null; then
          echo "Using nixGLNvidia for Obsidian..."
          exec nixGLNvidia obsidian "$@"
      elif command -v nixGLNvidia-570.153.02 &> /dev/null; then
          echo "Using nixGLNvidia-570.153.02 for Obsidian..."
          exec nixGLNvidia-570.153.02 obsidian "$@"
      elif command -v nixGLDefault &> /dev/null; then
          echo "Using nixGLDefault (auto-detect) for Obsidian..."
          exec nixGLDefault obsidian "$@"
      elif command -v nixGLNvidia &> /dev/null; then
          echo "Using nixGLNvidia for Obsidian..."
          exec nixGLNvidia obsidian "$@"
      elif command -v nixGLIntel &> /dev/null; then
          echo "Using nixGLIntel for Obsidian..."
          exec nixGLIntel obsidian "$@"
      else
          echo "No nixGL wrapper found, trying to run Obsidian directly..."
          echo "If this fails, make sure nixGL is properly installed."
          exec obsidian "$@"
      fi
    '';
    executable = true;
  };

  # Override the default Obsidian desktop entry to use the nixGL wrapper
  # This ensures proper taskbar integration by using the expected desktop file name
  home.file.".local/share/applications/obsidian.desktop" = {
    text = ''
      [Desktop Entry]
      Name=Obsidian (nixGL)
      Comment=A knowledge base that works on local Markdown files.
      Exec=obsidian-nixgl %U
      Icon=obsidian
      Terminal=false
      Type=Application
      Categories=Office;Utility;TextEditor;Development;
      StartupNotify=true
      StartupWMClass=obsidian
      MimeType=x-scheme-handler/obsidian;application/x-obsidian-vault;
      Keywords=KnowledgeBase;Markdown;Notes;Editor;
    '';
  };
}
