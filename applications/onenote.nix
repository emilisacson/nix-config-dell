{ config, pkgs, lib, ... }:

let
  # Custom wrapper for p3x-onenote with patched Electron
  onenotePatcher = pkgs.writeShellScriptBin "onenote-patched" ''
    #!/usr/bin/env bash

    # Enhanced fix for p3x-onenote with patched environment

    # Enable debugging
    export ELECTRON_ENABLE_LOGGING=true
    export ELECTRON_ENABLE_STACK_DUMPING=true

    # Additional environment variables to help with authentication
    export ELECTRON_NO_ASAR=1
    export NODE_OPTIONS="--no-force-async-hooks-checks"

    # Set user agent to Chrome to bypass some authentication restrictions
    USER_AGENT="Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/114.0.0.0 Safari/537.36"

    # Run p3x-onenote with comprehensive flags
    exec p3x-onenote \
      --no-sandbox \
      --disable-web-security \
      --ignore-certificate-errors \
      --ignore-gpu-blacklist \
      --disable-gpu-sandbox \
      --allow-insecure-localhost \
      --disable-background-timer-throttling \
      --disable-renderer-backgrounding \
      --disable-backgrounding-occluded-windows \
      --user-agent="$USER_AGENT" \
      "$@"
  '';

  # Create a wrapper for running OneNote using Chromium directly
  onenoteChromiumWrapper = pkgs.writeShellScriptBin "onenote-chromium" ''
    #!/usr/bin/env bash

    # This script opens OneNote in Chromium/Brave as an app window
    # It bypasses the p3x-onenote Electron wrapper entirely

    # Use either Brave or Chromium, depending on what's installed
    if command -v brave &> /dev/null; then
      BROWSER="brave"
    else
      BROWSER="chromium"
    fi

    # Run the browser in app mode pointing to OneNote
    exec $BROWSER --app=https://www.onenote.com/notebooks "$@"
  '';
in {
  # Install OneNote alternative and our patched wrappers
  home.packages = with pkgs; [
    # p3x-onenote is already included in applications.nix
    onenotePatcher
    onenoteChromiumWrapper
  ];

  # Keep the original fix script for reference
  home.file.".local/bin/onenote-fixed" = {
    source = ../extras/fix-onenote.sh;
    executable = true;
  };

  # Create desktop entries for all approaches
  xdg.desktopEntries = {
    # Entry for the original fixed version
    onenote-fixed = {
      name = "OneNote (Fixed)";
      exec = "${config.home.homeDirectory}/.local/bin/onenote-fixed %U";
      icon = "p3x-onenote";
      comment = "Access OneNote with authentication fixes";
      categories = [ "Office" ];
      terminal = false;
      startupNotify = true;
    };

    # Entry for our enhanced patched version
    onenote-patched = {
      name = "OneNote (Patched)";
      exec = "onenote-patched %U";
      icon = "p3x-onenote";
      comment = "Access OneNote with enhanced authentication fixes";
      categories = [ "Office" ];
      terminal = false;
      startupNotify = true;
    };

    # Entry for the browser-based approach
    onenote-chromium = {
      name = "OneNote (Web App)";
      exec = "onenote-chromium %U";
      icon = "p3x-onenote";
      comment = "Access OneNote directly in Chromium/Brave";
      categories = [ "Office" ];
      terminal = false;
      startupNotify = true;
    };
  };
}
