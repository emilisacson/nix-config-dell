{ pkgs, lib, nixgl ? { }, systemConfig ? null, ... }:

{
  home.packages = with pkgs; [
    obsidian
    # Install nixGL for OpenGL support (it's available through the overlay)
    nixgl
  ];

  # Wrapper script to launch Obsidian with nixGL
  home.file.".local/bin/obsidian-nixgl" = {
    text = ''
      #!/usr/bin/env bash
      # Obsidian launcher with nixGL for graphics support

      if command -v nixGL &> /dev/null; then
          echo "Using nixGL for Obsidian..."
          exec nixGL obsidian "$@" &
      else
          echo "nixGL not found, trying to run Obsidian directly..."
          echo "If this fails, make sure nixGL is properly installed."
          exec obsidian "$@" &
      fi
    '';
    executable = true;
  };

  # Override the default Obsidian desktop entry to use the nixGL wrapper
  # The obsidian package creates 'obsidian.desktop', so we override that
  home.file.".local/share/applications/obsidian.desktop" = {
    text = ''
      [Desktop Entry]
      Name=Obsidian
      Comment=A knowledge base that works on local Markdown files.
      Exec=obsidian-nixgl %U
      Icon=obsidian
      Terminal=false
      Type=Application
      Categories=Office;Utility;TextEditor;Development;
      StartupWMClass=obsidian
      MimeType=x-scheme-handler/obsidian;application/x-obsidian-vault;
      Keywords=KnowledgeBase;Markdown;Notes;Editor;
    '';
  };
}
