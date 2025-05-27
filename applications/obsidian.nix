{ pkgs, ... }:

{
  home.packages = with pkgs; [
    obsidian
    nixgl.auto.nixGLDefault # For auto-detection
    # You can add specific nixGL wrappers if needed, e.g.:
    # nixgl.auto.nixGLNvidia
    # nixgl.nixGLIntel
  ];

  # Wrapper script to launch Obsidian with nixGL
  home.file.".local/bin/obsidian-nixgl" = {
    text = ''
      #!/usr/bin/env bash
      # Obsidian launcher with nixGL for graphics support

      # Prefer nixGLDefault if available
      if command -v nixGLDefault &> /dev/null; then
          echo "Using nixGLDefault (auto-detect) for Obsidian..."
          exec nixGLDefault obsidian "$@" &
      # Add elif blocks here for nixGLNvidia or nixGLIntel if you've included them above
      # and want to prioritize them or have specific logic.
      # Example:
      # elif command -v nixGLNvidia &> /dev/null; then
      #     echo "Using nixGLNvidia for Obsidian..."
      #     exec nixGLNvidia obsidian "$@" &
      else
          echo "No suitable nixGL wrapper found in PATH, trying to run Obsidian directly..."
          exec obsidian "$@" &
      fi
    '';
    executable = true;
  };

  # Override the default Obsidian desktop entry to use the nixGL wrapper.
  # This assumes the .desktop file installed by the obsidian package is named 'obsidian.desktop'
  # or 'md.obsidian.Obsidian.desktop'. We will try to cover both common names.
  # This file will be placed in ~/.local/share/applications/ to take precedence.

  # Attempt to override 'md.obsidian.Obsidian.desktop' (common for AppImages/Electron apps)
  home.file.".local/share/applications/md.obsidian.Obsidian.desktop" = {
    text = ''
      [Desktop Entry]
      Name=Obsidian (nixGL)
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

  # Also attempt to override 'obsidian.desktop' as a fallback or if it's the primary one.
  # If both md.obsidian.Obsidian.desktop and obsidian.desktop are created by the package,
  # this ensures our nixGL version is preferred for both potential names.
  # If only one exists, only that one will be effectively overridden.
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
      StartupWMClass=obsidian
      MimeType=x-scheme-handler/obsidian;application/x-obsidian-vault;
      Keywords=KnowledgeBase;Markdown;Notes;Editor;
    '';
  };
}
