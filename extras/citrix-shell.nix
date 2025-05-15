{ pkgs ? import <nixpkgs> {} }:

pkgs.mkShell {
  name = "citrix-setup-environment";
  
  buildInputs = with pkgs; [
    # JavaScript runtime and dependencies
    nodejs_20
    nodePackages.npm
    
    # Browser options for automation (in order of preference)
    firefox  # Primary browser for automation
    chromium # Fallback browser
    
    # Build tools (required for puppeteer and native Node.js modules)
    gnumake
    gcc
    binutils
    pkg-config
    
    # Download and hash utilities
    curl
    wget
    nix-prefetch-scripts
    
    # RPM handling tools
    rpm
    cpio
    
    # Graphics and display libraries (needed by Citrix and browsers)
    libsecret
    glib
    gtk3
    webkitgtk_4_1
    nss
    nspr
    
    # X11 libraries (may be needed by Citrix)
    xorg.libX11
    xorg.libXext
    
    # Audio libraries (for Citrix audio support)
    alsa-lib
    pulseaudio
    
    # Helpful utilities
    jq     # For JSON processing
    pv     # For progress visualization
    xdg-utils # For handling file associations
    ripgrep  # For efficient text searching
  ];
  
  # Set environment variables to improve reliability
  shellHook = ''
    # Create cache directory if it doesn't exist
    mkdir -p $HOME/.cache
    
    # Skip Chromium download since we're providing the browser
    export PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=true
    
    # Auto-detect best browser to use with fallback options
    if [ -x "${pkgs.firefox}/bin/firefox" ]; then
      export PUPPETEER_EXECUTABLE_PATH="${pkgs.firefox}/bin/firefox"
      echo "Using Firefox for browser automation"
    elif [ -x "${pkgs.chromium}/bin/chromium" ]; then
      export PUPPETEER_EXECUTABLE_PATH="${pkgs.chromium}/bin/chromium"
      echo "Using Chromium for browser automation"
    else
      echo "Warning: No compatible browser found for automation"
      echo "Will attempt to auto-detect system browsers"
    fi
    
    # Increase Node.js memory limit for larger operations
    export NODE_OPTIONS="--max-old-space-size=4096"
    
    # Install required Node.js packages if they don't exist
    if [ ! -d "node_modules" ]; then
      echo "Installing required Node.js packages..."
      npm install puppeteer-core minimist
    fi
    
    echo "┌──────────────────────────────────────────┐"
    echo "│ Citrix Workspace Setup Environment Ready │"
    echo "└──────────────────────────────────────────┘"
    echo ""
    echo "Available commands:"
    echo "  • ./add-citrix-to-nix.sh            - Full automated setup"
    echo "  • node auto-download-citrix.js      - Just download the RPM"
    echo "  • node auto-download-citrix.js --debug - Download with browser visible"
    echo ""
  '';
}