{ config, pkgs, lib, ... }:

{
  # Install nixGL packages for hardware acceleration
  home.packages = with pkgs;
    [ ] ++ lib.optionals (config.systemSpecs.hasIntelGPU or false) [
      nixgl.nixGLIntel # Include Intel support
    ] ++ lib.optionals (config.systemSpecs.hasNvidiaGPU or false) [
      # Use explicit NVIDIA version to avoid auto-detection issues
      (nixgl.override { nvidiaVersion = "575.64.03"; }).auto.nixGLNvidia
    ];

  # Install and configure Brave Browser using chromium module
  programs.chromium = {
    enable = true;
    package = pkgs.brave; # Use Brave as the package
    extensions = [
      "oboonakemofpalcgghocfoadofidjkkk" # KeePassXC-Browser
      "cjpalhdlnbpafiamejdnhcphjbkeiagm" # uBlock Origin
      "nngceckbapebfimnlniiiahkandclblb" # Bitwarden
      "eimadpbcbfnmbkopoojfekhnkhdbieeh" # Dark Reader
      "gphhapmejobijbbhgpjhcjognlahblep" # GNOME Shell Integration
      "bjfgambnhccakkhmkepdoekmckoijdlc" # Browser MCP - Automate your browser
    ];
  };

  # Configure Brave as the default browser
  xdg.mimeApps = {
    enable = true;
    defaultApplications = {
      "text/html" = [ "brave-browser-nixgl.desktop" ];
      "x-scheme-handler/http" = [ "brave-browser-nixgl.desktop" ];
      "x-scheme-handler/https" = [ "brave-browser-nixgl.desktop" ];
      "x-scheme-handler/about" = [ "brave-browser-nixgl.desktop" ];
      "x-scheme-handler/unknown" = [ "brave-browser-nixgl.desktop" ];
    };
  };

  # Create a policy directory with extension force-install policy
  home.file.".config/BraveSoftware/Brave-Browser/policies/managed/extensions_policy.json".text =
    builtins.toJSON {
      ExtensionSettings = {
        "oboonakemofpalcgghocfoadofidjkkk" = {
          installation_mode = "force_installed";
          update_url = "https://clients2.google.com/service/update2/crx";
        };
        "cjpalhdlnbpafiamejdnhcphjbkeiagm" = {
          installation_mode = "force_installed";
          update_url = "https://clients2.google.com/service/update2/crx";
        };
        "nngceckbapebfimnlniiiahkandclblb" = {
          installation_mode = "force_installed";
          update_url = "https://clients2.google.com/service/update2/crx";
        };
        "eimadpbcbfnmbkopoojfekhnkhdbieeh" = {
          installation_mode = "force_installed";
          update_url = "https://clients2.google.com/service/update2/crx";
        };
        "gphhapmejobijbbhgpjhcjognlahblep" = {
          installation_mode = "force_installed";
          update_url = "https://clients2.google.com/service/update2/crx";
        };
        "bjfgambnhccakkhmkepdoekmckoijdlc" = {
          installation_mode = "force_installed";
          update_url = "https://clients2.google.com/service/update2/crx";
        };
      };
    };

  # Make sure the policies directory exists and is properly set up
  home.activation.ensureBravePolicies =
    lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      $DRY_RUN_CMD mkdir -p $VERBOSE_ARG ~/.config/BraveSoftware/Brave-Browser/policies/managed
    '';

  # Create a wrapper script for Brave with nixGL
  home.file.".local/bin/brave-nixgl" = {
    text = ''
      #!/usr/bin/env bash
      # Brave launcher with nixGL for graphics support

      # Try to detect the best nixGL wrapper to use (prefer NVIDIA, then Intel, then default)
      if command -v nixGLNvidia-575.64.03 &> /dev/null; then
          echo "Using nixGLNvidia-575.64.03 for Brave..."
          exec nixGLNvidia-575.64.03 brave "$@"
      elif command -v nixGLNvidia &> /dev/null; then
          echo "Using nixGLNvidia for Brave..."
          exec nixGLNvidia brave "$@"
      elif command -v nixGLIntel &> /dev/null; then
          echo "Using nixGLIntel for Brave..."
          exec nixGLIntel brave "$@"
      elif command -v nixGLDefault &> /dev/null; then
          echo "Using nixGLDefault for Brave..."
          exec nixGLDefault brave "$@"
      else
          echo "No nixGL wrapper found, trying to run Brave directly..."
          echo "If you experience graphics issues, make sure nixGL is properly installed."
          exec brave "$@"
      fi
    '';
    executable = true;
  };

  # Create a custom desktop entry that uses the nixGL wrapper
  home.file.".local/share/applications/brave-browser-nixgl.desktop" = {
    text = ''
      [Desktop Entry]
      Version=1.0
      Name=Brave Web Browser (nixGL)
      Comment=Access the Internet with hardware acceleration
      GenericName=Web Browser
      Keywords=Internet;WWW;Browser;Web;Explorer
      Exec=brave-nixgl %U
      Terminal=false
      X-MultipleArgs=false
      Type=Application
      Icon=brave-browser
      Categories=Network;WebBrowser;
      MimeType=application/pdf;application/rdf+xml;application/rss+xml;application/xhtml+xml;application/xhtml_xml;application/xml;image/gif;image/jpeg;image/png;image/webp;text/html;text/xml;x-scheme-handler/http;x-scheme-handler/https;x-scheme-handler/ftp;
      StartupNotify=true
      StartupWMClass=brave-browser
      Actions=new-window;new-private-window;

      [Desktop Action new-window]
      Name=New Window
      Exec=brave-nixgl

      [Desktop Action new-private-window]
      Name=New Incognito Window
      Exec=brave-nixgl --incognito
    '';
  };

  # Hide the original Brave desktop entries to avoid duplicates
  home.file.".local/share/applications/brave-browser.desktop" = {
    text = ''
      [Desktop Entry]
      Hidden=true
    '';
  };

  home.file.".local/share/applications/com.brave.Browser.desktop" = {
    text = ''
      [Desktop Entry]
      Hidden=true
    '';
  };
}
