{ config, pkgs, lib, ... }:

{
  # Install p3x-onenote with better graphics support approach
  home.packages = with pkgs;
    [
      # Regular p3x-onenote package
      p3x-onenote

      # System fonts and graphics libraries
      fontconfig
      dejavu_fonts
      liberation_ttf

      # GTK modules to fix missing module warnings
      gtk3
      libcanberra-gtk3
      polkit_gnome

      # Mesa software renderer as fallback
      mesa

      # Only include nixGL if available
    ] ++ lib.optionals (pkgs ? nixgl) [ nixgl.auto.nixGLDefault ]
    ++ lib.optionals (config.systemSpecs.hasNvidiaGPU && pkgs ? nixgl)
    [ nixgl.auto.nixGLNvidia ]
    ++ lib.optionals (config.systemSpecs.hasIntelGPU && pkgs ? nixgl)
    [ nixgl.nixGLIntel ];

  # Create a wrapper script for p3x-onenote with enhanced configuration  
  home.file.".local/bin/onenote-nixgl" = {
    text = ''
      #!/usr/bin/env bash
      # p3x-onenote launcher with graphics and rendering fixes

      # Enhanced environment variables for authentication and stability
      export ELECTRON_ENABLE_LOGGING=true
      export ELECTRON_ENABLE_STACK_DUMPING=true
      export ELECTRON_NO_ASAR=1
      # Remove NODE_OPTIONS to avoid packaged app warnings
      unset NODE_OPTIONS

      # Graphics environment fixes for hybrid GPU setup
      export LIBGL_ALWAYS_SOFTWARE=1
      export GALLIUM_DRIVER=llvmpipe  
      export MESA_GL_VERSION_OVERRIDE=3.3
      export __GLX_VENDOR_LIBRARY_NAME=mesa

      # Suppress MESA DRI warnings by setting fallback paths
      export LIBGL_DRIVERS_PATH=/run/opengl-driver/lib/dri:/usr/lib/dri:/usr/lib64/dri
      export __EGL_VENDOR_LIBRARY_DIRS=/run/opengl-driver/share/glvnd/egl_vendor.d:/usr/share/glvnd/egl_vendor.d

      # Font and display environment
      export FONTCONFIG_PATH=/etc/fonts:~/.nix-profile/etc/fonts
      export GTK_THEME=Adwaita
      export GDK_SCALE=1

      # GTK module path to reduce module loading warnings
      export GTK_PATH=~/.nix-profile/lib/gtk-3.0:~/.nix-profile/lib/gtk-2.0

      # Set user agent to Chrome to bypass authentication restrictions
      USER_AGENT="Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"

      # p3x-onenote flags optimized for software rendering and stability
      ONENOTE_ARGS=(
        --no-sandbox
        --disable-web-security
        --ignore-certificate-errors
        --disable-gpu
        --disable-gpu-sandbox
        --disable-software-rasterizer
        --enable-features=UseOzonePlatform
        --ozone-platform=wayland
        --allow-insecure-localhost
        --disable-background-timer-throttling
        --disable-renderer-backgrounding
        --disable-backgrounding-occluded-windows
        --user-agent="$USER_AGENT"
      )

      echo "Starting OneNote with software rendering and Wayland backend..."

      # Try nixGL first since it's working for you
      if command -v nixGL &> /dev/null; then
          echo "Using nixGL wrapper for graphics support..."
          exec nixGL p3x-onenote "''${ONENOTE_ARGS[@]}" "$@"
      elif command -v nixGLNvidia-570.153.02 &> /dev/null; then
          echo "Using NVIDIA nixGL wrapper..."
          exec nixGLNvidia-570.153.02 p3x-onenote "''${ONENOTE_ARGS[@]}" "$@"
      else
          echo "No nixGL found, running directly with software rendering..."
          exec p3x-onenote "''${ONENOTE_ARGS[@]}" "$@"
      fi
    '';
    executable = true;
  };

  # Create a browser-based wrapper for fallback
  home.file.".local/bin/onenote-browser" = {
    text = ''
      #!/usr/bin/env bash
      # OneNote browser launcher as fallback option

      # Use either Brave or Chromium, depending on what's installed
      if command -v brave &> /dev/null; then
        BROWSER="brave"
      elif command -v chromium &> /dev/null; then
        BROWSER="chromium"
      else
        echo "No supported browser found (brave/chromium)"
        exit 1
      fi

      # Run the browser in app mode pointing to OneNote
      exec $BROWSER --app=https://www.onenote.com/notebooks "$@"
    '';
    executable = true;
  };

  # Create a corporate-specific OneNote launcher for O365 enterprise accounts
  home.file.".local/bin/onenote-corporate" = {
    text = ''
      #!/usr/bin/env bash
      # OneNote corporate launcher for O365 enterprise accounts
      # This bypasses p3x-onenote authentication issues with corporate MFA

      echo "Launching OneNote for Corporate/Enterprise O365 accounts..."
      echo "This uses the web browser to avoid MFA authentication loops."

      # Use either Brave or Chromium, depending on what's installed
      if command -v brave &> /dev/null; then
        BROWSER="brave"
        echo "Using Brave browser..."
      elif command -v chromium &> /dev/null; then
        BROWSER="chromium"
        echo "Using Chromium browser..."
      else
        echo "No supported browser found (brave/chromium)"
        exit 1
      fi

      # Set up environment for better browser compatibility
      export LIBGL_ALWAYS_SOFTWARE=1
      export GALLIUM_DRIVER=llvmpipe
      export MESA_GL_VERSION_OVERRIDE=3.3

      # Browser arguments for corporate-friendly settings
      BROWSER_ARGS=(
        --app=https://www.office.com/launch/onenote
        --user-data-dir="$HOME/.config/onenote-corporate"
        --enable-features=UseOzonePlatform
        --ozone-platform=wayland
        --disable-gpu-sandbox
        --no-sandbox
      )

      # Try with nixGL first, fallback to direct execution
      if command -v nixGL &> /dev/null; then
        echo "Using nixGL for browser graphics support..."
        exec nixGL $BROWSER "''${BROWSER_ARGS[@]}" "$@"
      else
        echo "Running browser directly..."
        exec $BROWSER "''${BROWSER_ARGS[@]}" "$@"
      fi
    '';
    executable = true;
  };

  # Override the default p3x-onenote desktop entry to use the nixGL wrapper
  home.file.".local/share/applications/p3x-onenote.desktop" = {
    text = ''
      [Desktop Entry]
      Name=OneNote
      Comment=Microsoft OneNote with enhanced graphics support
      Exec=onenote-nixgl %U
      Icon=p3x-onenote
      Terminal=false
      Type=Application
      Categories=Office;Utility;TextEditor;
      StartupNotify=true
      StartupWMClass=p3x-onenote
      Keywords=OneNote;Microsoft;Notes;Office;
    '';
  };

  # Alternative desktop entries
  xdg.desktopEntries = {
    # Browser-based fallback entry
    onenote-browser = {
      name = "OneNote (Browser)";
      exec = "onenote-browser %U";
      icon = "p3x-onenote";
      comment = "Access OneNote directly in browser as reliable fallback";
      categories = [ "Office" "Network" ];
      terminal = false;
      startupNotify = true;
    };

    # Corporate O365 entry for enterprise accounts with MFA issues
    onenote-corporate = {
      name = "OneNote (Corporate)";
      exec = "onenote-corporate %U";
      icon = "p3x-onenote";
      comment =
        "OneNote for Corporate/Enterprise O365 accounts (avoids MFA loops)";
      categories = [ "Office" "Network" ];
      terminal = false;
      startupNotify = true;
    };
  };
}
