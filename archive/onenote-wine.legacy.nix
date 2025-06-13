{ config, pkgs, lib, ... }:

let
  # Wine prefix for OneNote
  winePrefix = "${config.home.homeDirectory}/.wine-onenote";

  # Determine available nixGL packages based on system hardware
  nixGLPackages = with pkgs;
    [ nixgl.auto.nixGLDefault ]
    ++ lib.optionals (builtins.pathExists /proc/driver/nvidia/version)
    [ nixgl.auto.nixGLNvidia ] ++ [ nixgl.nixGLIntel ];

  # Create Wine-based OneNote launcher
  onenote-wine = pkgs.writeShellScriptBin "onenote-wine" ''
    set -e

    export WINEPREFIX="${winePrefix}"
    export WINEDLLOVERRIDES="mscoree,msxml3,msxml6,vcrun2019=n,b"
    # Use 32-bit Wine for better compatibility with Office Setup installers
    export WINEARCH="win32"

    # Ensure Wine prefix exists and is initialized
    if [ ! -d "$WINEPREFIX" ]; then
      echo "Creating Wine prefix for OneNote..."
      
      # Remove any existing prefix remnants to avoid conflicts
      rm -rf "$WINEPREFIX"
      mkdir -p "$WINEPREFIX"
      
      # Initialize Wine prefix with explicit 32-bit architecture
      echo "Initializing Wine prefix with 32-bit architecture..."
      ${pkgs.wine-staging}/bin/wineboot --init
      
      # Install necessary Windows components
      echo "Installing Windows components via winetricks..."
      ${pkgs.winetricks}/bin/winetricks -q \
        corefonts \
        vcrun2019 \
        msxml3 \
        msxml6 \
        dotnet48 \
        win10
      
      echo "Wine prefix initialized successfully!"
      echo ""
      echo "To install Office/OneNote:"
      echo "1. Download Office Setup from Microsoft:"
      echo "   https://go.microsoft.com/fwlink/?linkid=2110341"
      echo "2. Run: onenote-wine-config install-downloaded"
      echo ""
    fi

    # Function to detect and use the best nixGL variant for Wine
    detect_nixgl_wine() {
      local nixgl_variants=(
        "${pkgs.nixgl.auto.nixGLDefault}/bin/nixGL"
        "${pkgs.nixgl.auto.nixGLNvidia}/bin/nixGL"  
        "${pkgs.nixgl.nixGLIntel}/bin/nixGLIntel"
      )
      
      for variant in "''${nixgl_variants[@]}"; do
        if [ -x "$variant" ]; then
          echo "Using nixGL variant: $variant" >&2
          exec "$variant" ${pkgs.wine-staging}/bin/wine "$@"
        fi
      done
      
      # Fallback: run without nixGL
      echo "Warning: No nixGL variant found, running without GPU acceleration" >&2
      exec ${pkgs.wine-staging}/bin/wine "$@"
    }

    # Try to find OneNote executable in Wine prefix
    ONENOTE_EXE=""
    POSSIBLE_PATHS=(
      "$WINEPREFIX/drive_c/Program Files/Microsoft Office/root/Office16/ONENOTE.EXE"
      "$WINEPREFIX/drive_c/Program Files (x86)/Microsoft Office/root/Office16/ONENOTE.EXE"
      "$WINEPREFIX/drive_c/Program Files/Microsoft Office/Office16/ONENOTE.EXE"
      "$WINEPREFIX/drive_c/Program Files (x86)/Microsoft Office/Office16/ONENOTE.EXE"
      "$WINEPREFIX/drive_c/users/$USER/Desktop/OneNote.exe"
      "$WINEPREFIX/drive_c/users/$USER/Downloads/OneNote.exe"
    )

    for path in "''${POSSIBLE_PATHS[@]}"; do
      if [ -f "$path" ]; then
        ONENOTE_EXE="$path"
        break
      fi
    done

    if [ -n "$ONENOTE_EXE" ]; then
      echo "Launching OneNote via Wine..."
      # Convert Unix path to Windows path
      WIN_PATH="''${ONENOTE_EXE//\/drive_c/C:}"
      WIN_PATH="''${WIN_PATH//\//\\}"
      detect_nixgl_wine "$WIN_PATH"
    else
      echo "OneNote not found in Wine prefix."
      echo "Please install OneNote first using: onenote-wine-config install-onenote"
      echo ""
      echo "Opening Wine prefix directory for manual installation..."
      ${pkgs.xdg-utils}/bin/xdg-open "$WINEPREFIX"
    fi
  '';

  # Create Wine configuration helper
  onenote-wine-config = pkgs.writeShellScriptBin "onenote-wine-config" ''
    set -e

    export WINEPREFIX="${winePrefix}"
    export WINEARCH="win32"

    echo "OneNote Wine Configuration Helper"
    echo "================================="
    echo ""
    echo "Wine prefix: $WINEPREFIX"
    echo ""

    case "''${1:-help}" in
      "winecfg")
        echo "Opening Wine configuration..."
        ${pkgs.nixgl.auto.nixGLDefault}/bin/nixGL ${pkgs.wine-staging}/bin/winecfg
        ;;
      "winetricks")
        echo "Opening winetricks..."
        shift
        ${pkgs.winetricks}/bin/winetricks "$@"
        ;;
      "wine-cmd")
        echo "Opening Windows command prompt..."
        ${pkgs.nixgl.auto.nixGLDefault}/bin/nixGL ${pkgs.wine-staging}/bin/wine cmd
        ;;
      "install-onenote")
        echo "Microsoft Office/OneNote Installation Guide:"
        echo "==========================================="
        echo ""
        echo "OneNote is now bundled with Microsoft Office."
        echo ""
        echo "1. Download Office Setup from Microsoft:"
        echo "   https://go.microsoft.com/fwlink/?linkid=2110341"
        echo ""
        echo "2. Save the OfficeSetup.exe to:"
        echo "   $WINEPREFIX/drive_c/users/$USER/Downloads/"
        echo ""
        echo "3. Run the installer with:"
        echo "   onenote-wine-config install-downloaded"
        echo ""
        echo "Alternative: Manual installation"
        echo "1. Download OfficeSetup.exe to ~/Downloads/"
        echo "2. Copy to Wine prefix: cp ~/Downloads/OfficeSetup.exe $WINEPREFIX/drive_c/users/$USER/Downloads/"
        echo "3. Run: onenote-wine-config install-downloaded"
        echo ""
        echo "Note: You can choose to install only OneNote during Office setup."
        ;;
      "install-downloaded")
        INSTALLER_PATH="$WINEPREFIX/drive_c/users/$USER/Downloads"
        mkdir -p "$INSTALLER_PATH"
        
        # Check both Wine Downloads and system Downloads for Office Setup
        FOUND_INSTALLER=""
        for location in "$INSTALLER_PATH" "$HOME/Downloads"; do
          # Look for Office Setup files
          if ls "$location"/OfficeSetup.exe 1> /dev/null 2>&1; then
            FOUND_INSTALLER=$(ls "$location"/OfficeSetup.exe | head -1)
            break
          fi
          if ls "$location"/*Office*Setup*.exe 1> /dev/null 2>&1; then
            FOUND_INSTALLER=$(ls "$location"/*Office*Setup*.exe | head -1)
            break
          fi
          # Fallback: Look for any Office-related installer
          if ls "$location"/*Office*.exe 1> /dev/null 2>&1; then
            FOUND_INSTALLER=$(ls "$location"/*Office*.exe | head -1)
            break
          fi
        done
        
        if [ -n "$FOUND_INSTALLER" ]; then
          echo "Found Office installer: $(basename "$FOUND_INSTALLER")"
          
          # Copy to Wine prefix if needed
          if [[ "$FOUND_INSTALLER" != "$INSTALLER_PATH"* ]]; then
            echo "Copying installer to Wine prefix..."
            cp "$FOUND_INSTALLER" "$INSTALLER_PATH/"
            FOUND_INSTALLER="$INSTALLER_PATH/$(basename "$FOUND_INSTALLER")"
          fi
          
          echo "Installing Microsoft Office (including OneNote)..."
          echo "Note: During installation, you can choose to install only OneNote if desired."
          
          # Convert Unix path to Windows path
          # First ensure we have the full Wine prefix path
          if [[ "$FOUND_INSTALLER" == "$WINEPREFIX"* ]]; then
            # Path is already in Wine prefix, convert to Windows format
            WIN_INSTALLER="''${FOUND_INSTALLER#$WINEPREFIX/drive_c}"
            WIN_INSTALLER="C:''${WIN_INSTALLER//\//\\}"
          else
            # Shouldn't happen, but fallback
            WIN_INSTALLER="C:\\users\\$USER\\Downloads\\$(basename "$FOUND_INSTALLER")"
          fi
          
          ${pkgs.nixgl.auto.nixGLDefault}/bin/nixGL ${pkgs.wine-staging}/bin/wine "$WIN_INSTALLER"
        else
          echo "No Office Setup installer found!"
          echo "Please download Office Setup first:"
          echo "  onenote-wine-config install-onenote"
        fi
        ;;
      "uninstall")
        echo "Uninstalling OneNote Wine prefix..."
        read -p "This will delete the entire Wine prefix. Continue? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
          rm -rf "$WINEPREFIX"
          echo "OneNote Wine prefix removed."
        else
          echo "Uninstall cancelled."
        fi
        ;;
      "reset")
        echo "Resetting OneNote Wine prefix..."
        read -p "This will reset the Wine prefix to a clean state. Continue? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
          rm -rf "$WINEPREFIX"
          echo "Wine prefix reset. Run 'onenote-wine' to reinitialize."
        else
          echo "Reset cancelled."
        fi
        ;;
      *)
        echo "Available commands:"
        echo "  winecfg           - Configure Wine settings"
        echo "  winetricks        - Install Windows components"
        echo "  wine-cmd          - Open Windows command prompt"
        echo "  install-onenote   - Show OneNote installation guide"
        echo "  install-downloaded - Install OneNote from Downloads folder"
        echo "  reset             - Reset Wine prefix to clean state"
        echo "  uninstall         - Remove OneNote Wine prefix completely"
        echo ""
        echo "Usage: onenote-wine-config [command]"
        ;;
    esac
  ''; # Create Office Setup installer helper
  office-setup-installer = pkgs.writeShellScriptBin "office-setup-installer" ''
    set -e

    export WINEPREFIX="${winePrefix}"

    echo "Microsoft Office Setup Installer"
    echo "==============================="
    echo ""
    echo "This script downloads and installs Microsoft Office (including OneNote)"
    echo "using the official Office Setup from Microsoft."
    echo ""

    # Office Setup URL
    OFFICE_SETUP_URL="https://go.microsoft.com/fwlink/?linkid=2110341"

    echo "Downloading Office Setup..."
    cd "$HOME/Downloads"

    if command -v curl &> /dev/null; then
      curl -L -o "OfficeSetup.exe" "$OFFICE_SETUP_URL"
    elif command -v wget &> /dev/null; then
      wget -O "OfficeSetup.exe" "$OFFICE_SETUP_URL"
    else
      echo "Error: Neither curl nor wget available for download"
      echo "Please manually download Office Setup from:"
      echo "$OFFICE_SETUP_URL"
      echo "Save as: $HOME/Downloads/OfficeSetup.exe"
      exit 1
    fi

    echo "Installing Microsoft Office..."
    echo "Note: During installation, you can choose to install only OneNote."
    echo ""

    # Copy to Wine prefix and install
    mkdir -p "$WINEPREFIX/drive_c/users/$USER/Downloads/"
    cp "OfficeSetup.exe" "$WINEPREFIX/drive_c/users/$USER/Downloads/"

    ${pkgs.nixgl.auto.nixGLDefault}/bin/nixGL ${pkgs.wine-staging}/bin/wine \
      "$WINEPREFIX/drive_c/users/$USER/Downloads/OfficeSetup.exe"

    echo "Office Setup launched! Follow the installation wizard to install OneNote."
  '';

in {
  home.packages = with pkgs;
    [
      # Wine-based OneNote launchers
      onenote-wine
      onenote-wine-config
      office-setup-installer

      # Wine and related tools - with 32-bit support for Office compatibility
      wine-staging
      wineWowPackages.staging # 32-bit support
      winetricks

      # Required nixGL packages for graphics acceleration
    ] ++ nixGLPackages ++ [
      # Graphics and display libraries
      mesa

      # Font support for Wine
      fontconfig
      dejavu_fonts
      liberation_ttf

      # Additional Wine runtime dependencies
      glib
      gdk-pixbuf
      gtk3
      libcanberra-gtk3

      # Audio support
      alsa-lib
      pulseaudio

      # Network and crypto libraries
      openssl
      curl
      wget

      # Utilities
      xdg-utils
      unzip
      p7zip
    ];

  # Create desktop entries for Wine-based OneNote
  home.file.".local/share/applications/onenote-wine.desktop".text = ''
    [Desktop Entry]
    Name=OneNote (Wine)
    Comment=Microsoft OneNote via Wine for maximum compatibility
    Exec=${onenote-wine}/bin/onenote-wine
    Icon=onenote
    Type=Application
    Categories=Office;
    StartupNotify=true
  '';

  home.file.".local/share/applications/onenote-wine-config.desktop".text = ''
    [Desktop Entry]
    Name=OneNote Wine Config
    Comment=Configure OneNote Wine environment
    Exec=${onenote-wine-config}/bin/onenote-wine-config
    Icon=wine
    Type=Application
    Categories=System;Settings;
    StartupNotify=true
  '';

  home.file.".local/share/applications/office-setup-installer.desktop".text = ''
    [Desktop Entry]
    Name=Install Office/OneNote
    Comment=Download and install Microsoft Office (including OneNote) via Wine
    Exec=${office-setup-installer}/bin/office-setup-installer
    Icon=office
    Type=Application
    Categories=System;Settings;
    StartupNotify=true
  ''; # Environment variables for Wine compatibility
  home.sessionVariables = {
    # Wine-specific environment variables - use 32-bit for Office compatibility
    WINEDLLOVERRIDES = "mscoree,msxml3,msxml6,vcrun2019=n,b";

    # Graphics acceleration settings
    MESA_GL_VERSION_OVERRIDE = "3.3";
    MESA_GLSL_VERSION_OVERRIDE = "330";

    # Font configuration
    FONTCONFIG_PATH = "${pkgs.fontconfig.out}/etc/fonts";
  };
}
