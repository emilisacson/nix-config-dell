{ pkgs, config, lib, ... }:

let
  citrixVersion = "24.11.0.85";
  citrixTarball = "${config.home.homeDirectory}/Downloads/linuxx64-${citrixVersion}.tar.gz";
  
  # Create a script to extract and set up the Citrix Workspace app
  citrixSetupScript = pkgs.writeShellScriptBin "setup-citrix-workspace" ''
    #!/usr/bin/env bash
    set -eo pipefail
    
    CITRIX_DIR="$HOME/.citrix-workspace"
    TARGET_DIR="$CITRIX_DIR/ICAClient"
    TARBALL="${citrixTarball}"
    VERSION="${citrixVersion}"
    
    # Clean up previous installation attempts if they exist
    rm -rf "$CITRIX_DIR"
    
    # Also clean up old installation if it exists
    rm -rf "$HOME/ICAClient"
    
    # Create directories
    mkdir -p "$CITRIX_DIR"
    mkdir -p "$TARGET_DIR"
    mkdir -p "$HOME/.ICAClient/cache"
    mkdir -p "$HOME/.ICAClient/keystore/cacerts"
    
    # Extract the tarball and run the setupwfc script with non-interactive options
    echo "Extracting and installing Citrix Workspace $VERSION..."
    cd "$CITRIX_DIR"
    tar -xzf "$TARBALL" --strip-components=0
    
    # Create a non-interactive answers file for the setup script
    cat > "$CITRIX_DIR/answers" << EOA
1
$TARGET_DIR
y
y
y
EOA
    
    # Run the setup with our answers
    echo "Running Citrix setup script non-interactively..."
    cat "$CITRIX_DIR/answers" | ./setupwfc || true
    rm -f "$CITRIX_DIR/answers"
    
    # Set up SSL certificates
    mkdir -p "$TARGET_DIR/keystore/cacerts"
    ln -sf /etc/ssl/certs/* "$TARGET_DIR/keystore/cacerts/" 2>/dev/null || true
    
    # Fix permissions
    chmod -R u+rw "$TARGET_DIR" 2>/dev/null || true
    chmod +x "$TARGET_DIR/selfservice" 2>/dev/null || true
    chmod +x "$TARGET_DIR/wfica" 2>/dev/null || true
    chmod +x "$TARGET_DIR/util/configmgr" 2>/dev/null || true
    
    # Create symbolic links
    mkdir -p "$HOME/.local/bin"
    ln -sf "$TARGET_DIR/selfservice" "$HOME/.local/bin/selfservice" 2>/dev/null || true
    ln -sf "$TARGET_DIR/wfica" "$HOME/.local/bin/wfica" 2>/dev/null || true
    ln -sf "$TARGET_DIR/util/configmgr" "$HOME/.local/bin/configmgr" 2>/dev/null || true
    
    # Set up client config files
    mkdir -p "$HOME/.ICAClient"
    mkdir -p "$HOME/.ICAClient/cache"
    mkdir -p "$HOME/.ICAClient/keystore/cacerts"
    
    cat > "$HOME/.ICAClient/module.ini" << EOC
[WFClient]
UseSystemCertificates=On
CertificatePath=/etc/ssl/certs
SSLCertificateRevocationCheckPolicy=NoCheck
CertificateRevocationCheckPolicy=NoCheck
UseCertificateAsProgramID=1
[WFClient.old]
UseSystemCertificates=On
[Hotkey Keys]
DisableCtrlAltDel=True
EOC
    
    cat > "$HOME/.ICAClient/All_Regions.ini" << EOC
[Trusted_Domains]
SystemRootCerts=1
UseSysStore=1

[WFClient]
UseSystemStore=1
SSLCertificateRevocationCheckPolicy=NoCheck
CertificateRevocationCheckPolicy=NoCheck
UseCertificateAsProgramID=1
UseSystemCertificates=1
SystemRootCerts=1
EOC
    
    # Accept EULA automatically
    echo "1" > "$HOME/.ICAClient/.eula_accepted"
    
    # Disable problematic services
    rm -f "$HOME/.config/systemd/user/ctxcwalogd.service" 2>/dev/null || true
    rm -f "$HOME/.config/systemd/user/default.target.wants/ctxcwalogd.service" 2>/dev/null || true
    
    # Verify installation
    if [ -f "$TARGET_DIR/selfservice" ] && [ -x "$TARGET_DIR/selfservice" ]; then
      echo "Citrix Workspace installation completed successfully"
      echo "You can launch it with 'citrix-workspace' command"
    else
      echo "Warning: Installation may not be complete."
      echo "Try running 'repair-citrix' to fix issues"
      
      # Try to find selfservice binary anyway
      SELFSERVICE=$(find "$CITRIX_DIR" -name "selfservice" -type f 2>/dev/null | head -n 1)
      if [ -n "$SELFSERVICE" ]; then
        echo "Found selfservice at: $SELFSERVICE"
        ICAROOT=$(dirname "$SELFSERVICE")
        chmod +x "$SELFSERVICE" 2>/dev/null || true
        ln -sf "$SELFSERVICE" "$HOME/.local/bin/selfservice" 2>/dev/null || true
        echo "Created symlink in ~/.local/bin"
      fi
    fi
    
    echo ""
    echo "NOTE: If you encounter WebKit library errors, run 'install-citrix-deps'"
  '';
  
  # Create a launcher script that will handle specific issues
  citrixLauncher = pkgs.writeShellScriptBin "citrix-workspace" ''
    #!/usr/bin/env bash
    
    # Find the selfservice binary - check multiple locations
    if [ -x "$HOME/.local/bin/selfservice" ]; then
      SELFSERVICE="$HOME/.local/bin/selfservice"
    elif [ -x "$HOME/.citrix-workspace/ICAClient/selfservice" ]; then
      SELFSERVICE="$HOME/.citrix-workspace/ICAClient/selfservice"
    else
      # Last resort - search for it
      SELFSERVICE=$(find "$HOME/.citrix-workspace" -name "selfservice" -type f -executable 2>/dev/null | head -n 1)
    fi
    
    if [ -z "$SELFSERVICE" ] || [ ! -x "$SELFSERVICE" ]; then
      echo "Error: The Citrix selfservice binary is not found or not executable."
      echo "Please run 'setup-citrix-workspace' first."
      exit 1
    fi
    
    # Set up environment variables
    ICAROOT=$(dirname "$SELFSERVICE")
    export ICAROOT
    export CITRIX_NO_SUDO=1
    export WEBKIT_DISABLE_COMPOSITING_MODE=1
    
    # Accept EULA in all possible locations
    mkdir -p "$HOME/.ICAClient"
    echo "1" > "$HOME/.ICAClient/.eula_accepted"
    
    # Also create EULA acceptance file in the installation directory
    # Citrix sometimes looks for it here
    mkdir -p "$ICAROOT/cache"
    echo "1" > "$ICAROOT/.eula_accepted" 2>/dev/null || true
    echo "1" > "$ICAROOT/cache/.eula_accepted" 2>/dev/null || true
    
    # Run with error filtering
    "$SELFSERVICE" "$@" 2>&1 | grep -v "userdel:" | grep -v "Permission denied" | grep -v "cannot lock /etc/passwd" || true
  '';
  
  # Create a launcher for wfica (ICA client) with better path handling
  citrixIcaLauncher = pkgs.writeShellScriptBin "citrix-ica" ''
    #!/usr/bin/env bash
    
    # Find the wfica binary - check multiple locations
    if [ -x "$HOME/.local/bin/wfica" ]; then
      WFICA="$HOME/.local/bin/wfica"
    elif [ -x "$HOME/.citrix-workspace/ICAClient/wfica" ]; then
      WFICA="$HOME/.citrix-workspace/ICAClient/wfica"
    else
      # Last resort - search for it
      WFICA=$(find "$HOME/.citrix-workspace" -name "wfica" -type f -executable 2>/dev/null | head -n 1)
    fi
    
    if [ -z "$WFICA" ] || [ ! -x "$WFICA" ]; then
      echo "Error: The Citrix wfica binary is not found or not executable."
      echo "Please run 'setup-citrix-workspace' first."
      exit 1
    fi
    
    # Set up environment variables
    ICAROOT=$(dirname "$WFICA")
    export ICAROOT
    export CITRIX_NO_SUDO=1
    export WEBKIT_DISABLE_COMPOSITING_MODE=1
    
    # Run with error filtering
    "$WFICA" "$@" 2>&1 | grep -v "userdel:" | grep -v "Permission denied" | grep -v "cannot lock /etc/passwd" || true
  '';
  
  # Create a more comprehensive repair script
  citrixRepair = pkgs.writeShellScriptBin "repair-citrix" ''
    #!/usr/bin/env bash
    echo "Repairing Citrix Workspace installation..."
    
    # Locate the Citrix installation
    SELFSERVICE=$(find "$HOME/.citrix-workspace" -name "selfservice" -type f -executable 2>/dev/null | head -n 1)
    
    if [ -z "$SELFSERVICE" ]; then
      echo "Error: Could not find Citrix selfservice binary."
      echo "Your Citrix installation may be corrupt or incomplete."
      echo "Please run 'setup-citrix-workspace' again."
      exit 1
    fi
    
    ICAROOT=$(dirname "$SELFSERVICE")
    echo "Found Citrix installation at $ICAROOT"
    
    # Fix permissions
    echo "Setting permissions..."
    chmod -R u+rw "$ICAROOT" 2>/dev/null || true
    
    # Disable problematic services
    echo "Disabling problematic services..."
    systemctl --user stop ctxcwalogd.service 2>/dev/null || true
    systemctl --user disable ctxcwalogd.service 2>/dev/null || true
    rm -f "$HOME/.config/systemd/user/default.target.wants/ctxcwalogd.service" 2>/dev/null || true
    
    # Fix symlinks
    echo "Creating symlinks..."
    mkdir -p "$HOME/.local/bin"
    ln -sf "$SELFSERVICE" "$HOME/.local/bin/selfservice"
    
    WFICA=$(find "$ICAROOT" -name "wfica" -type f -executable 2>/dev/null | head -n 1)
    if [ -n "$WFICA" ]; then
      ln -sf "$WFICA" "$HOME/.local/bin/wfica"
    fi
    
    CONFIGMGR=$(find "$ICAROOT" -name "configmgr" -type f -executable 2>/dev/null | head -n 1)
    if [ -n "$CONFIGMGR" ]; then
      ln -sf "$CONFIGMGR" "$HOME/.local/bin/configmgr"
    fi
    
    # Set up certificates
    echo "Setting up certificates..."
    mkdir -p "$HOME/.ICAClient/keystore/cacerts"
    ln -sf /etc/ssl/certs/* "$HOME/.ICAClient/keystore/cacerts/" 2>/dev/null || true
    
    # Fix config files
    echo "Setting up config files..."
    mkdir -p "$HOME/.ICAClient"
    
    cat > "$HOME/.ICAClient/module.ini" << EOC
[WFClient]
UseSystemCertificates=On
CertificatePath=/etc/ssl/certs
SSLCertificateRevocationCheckPolicy=NoCheck
CertificateRevocationCheckPolicy=NoCheck
UseCertificateAsProgramID=1
[WFClient.old]
UseSystemCertificates=On
[Hotkey Keys]
DisableCtrlAltDel=True
EOC

    cat > "$HOME/.ICAClient/All_Regions.ini" << EOC
[Trusted_Domains]
SystemRootCerts=1
UseSysStore=1

[WFClient]
UseSystemStore=1
SSLCertificateRevocationCheckPolicy=NoCheck
CertificateRevocationCheckPolicy=NoCheck
UseCertificateAsProgramID=1
UseSystemCertificates=1
SystemRootCerts=1
EOC

    # Accept EULA
    echo "1" > "$HOME/.ICAClient/.eula_accepted"
    
    echo "Repair complete. Try running 'citrix-workspace' again."
  '';
  
  # Create a desktop entry for Citrix Workspace
  citrixDesktopEntry = pkgs.writeTextFile {
    name = "citrix-workspace.desktop";
    destination = "/share/applications/citrix-workspace.desktop";
    text = ''
      [Desktop Entry]
      Name=Citrix Workspace
      Comment=Access remote Citrix applications
      Exec=citrix-workspace %u
      Terminal=false
      Type=Application
      Categories=Network;RemoteAccess;
      MimeType=application/x-ica;
    '';
  };
  
  # Create another desktop entry for the ICA client
  citrixIcaDesktopEntry = pkgs.writeTextFile {
    name = "citrix-ica.desktop";
    destination = "/share/applications/citrix-ica.desktop";
    text = ''
      [Desktop Entry]
      Name=Citrix ICA Client
      Comment=Launch Citrix ICA sessions
      Exec=citrix-ica %f
      Terminal=false
      Type=Application
      Categories=Network;RemoteAccess;
      MimeType=application/x-ica;
      NoDisplay=true
    '';
  };

  # Create a helpful script to install system dependencies - with more specific packages
  citrixSystemDeps = pkgs.writeShellScriptBin "install-citrix-deps" ''
    #!/usr/bin/env bash
    
    echo "This script will help install system dependencies for Citrix Workspace"
    echo "It requires sudo access to install packages"
    
    # Detect the Linux distribution
    if [ -f /etc/os-release ]; then
      . /etc/os-release
      DISTRO=$ID
    else
      echo "Could not detect your Linux distribution"
      exit 1
    fi
    
    case "$DISTRO" in
      fedora)
        echo "Detected Fedora. Installing dependencies..."
        sudo dnf install -y webkit2gtk4.0-devel libidn openssl gtk3 cups-libs libpng \
          libXdamage libXrandr libXfixes gcc-c++ motif libXaw mesa-libGL \
          xorg-x11-server-Xvfb gdk-pixbuf2-devel pango cairo dbus-x11 \
          gstreamer1-plugins-base libxml2 libxslt
        
        # Create a symlink for libwebkit2gtk-4.0.so.37 which Citrix specifically looks for
        WEBKIT_PATH=$(find /usr/lib64 -name "libwebkit2gtk-4.0.so*" | grep -v ".a$" | head -n 1)
        if [ -n "$WEBKIT_PATH" ] && [ ! -e "/usr/lib64/libwebkit2gtk-4.0.so.37" ]; then
          echo "Creating WebKit symlink for Citrix..."
          sudo ln -sf "$WEBKIT_PATH" /usr/lib64/libwebkit2gtk-4.0.so.37
        fi
        ;;
        
      ubuntu|debian|pop)
        echo "Detected Ubuntu/Debian/Pop_OS. Installing dependencies..."
        sudo apt install -y libwebkit2gtk-4.0-37 libidn11 libcups2 libgtk-3-0 libpng16-16 \
          libxdamage1 libxfixes3 libxrandr2 g++ libmotif-common libxaw7 \
          gstreamer1.0-plugins-base libgdk-pixbuf2.0-0 libpango-1.0-0 libcairo2 \
          dbus-x11 libxml2 libxslt1.1
        ;;
        
      arch|manjaro)
        echo "Detected Arch/Manjaro. Installing dependencies..."
        sudo pacman -S --needed webkit2gtk libidn openssl gtk3 libcups libpng \
          libxdamage libxrandr libxfixes gcc motif libxaw \
          gstreamer-plugins-base gdk-pixbuf2 pango cairo dbus-x11 \
          libxml2 libxslt
        ;;
        
      *)
        echo "Your distribution ($DISTRO) is not directly supported by this script."
        echo "You need to install the following packages manually:"
        echo " - webkit2gtk 4.0 (libwebkit2gtk-4.0.so.37)"
        echo " - libidn"
        echo " - openssl"
        echo " - gtk3"
        echo " - cups libraries"
        echo " - X11 libraries (libXdamage, libXrandr, libXfixes)"
        echo " - gstreamer plugins base"
        ;;
    esac
    
    echo ""
    echo "Dependencies installation completed."
    echo "Run 'repair-citrix' to make sure the configuration is correct."
  '';

  # Create a cleanup script to remove Citrix installation
  citrixCleanup = pkgs.writeShellScriptBin "cleanup-citrix" ''
    #!/usr/bin/env bash
    
    echo "This script will remove your Citrix Workspace installation."
    echo "Warning: This will delete all Citrix configuration files."
    read -p "Continue? (y/n) " confirm
    
    if [ "$confirm" != "y" ]; then
      echo "Operation cancelled."
      exit 0
    fi
    
    echo "Cleaning up Citrix Workspace installation..."
    
    # Stop and disable services
    systemctl --user stop ctxcwalogd.service 2>/dev/null || true
    systemctl --user disable ctxcwalogd.service 2>/dev/null || true
    
    # Remove symlinks
    rm -f "$HOME/.local/bin/selfservice" 2>/dev/null || true
    rm -f "$HOME/.local/bin/wfica" 2>/dev/null || true
    rm -f "$HOME/.local/bin/configmgr" 2>/dev/null || true
    
    # Remove directories
    rm -rf "$HOME/.citrix-workspace" 2>/dev/null || true
    rm -rf "$HOME/.ICAClient" 2>/dev/null || true
    rm -f "$HOME/.config/systemd/user/ctxcwalogd.service" 2>/dev/null || true
    rm -f "$HOME/.config/systemd/user/default.target.wants/ctxcwalogd.service" 2>/dev/null || true
    
    echo "Citrix Workspace has been removed."
    echo "You can run 'setup-citrix-workspace' to install it again."
  '';
  
  # Create a debug launcher
  citrixDebugLauncher = pkgs.writeShellScriptBin "citrix-workspace-debug" ''
    #!/usr/bin/env bash
    
    # Find the selfservice binary - check multiple locations
    if [ -x "$HOME/.local/bin/selfservice" ]; then
      SELFSERVICE="$HOME/.local/bin/selfservice"
    elif [ -x "$HOME/.citrix-workspace/ICAClient/selfservice" ]; then
      SELFSERVICE="$HOME/.citrix-workspace/ICAClient/selfservice"
    else
      # Last resort - search for it
      SELFSERVICE=$(find "$HOME/.citrix-workspace" -name "selfservice" -type f -executable 2>/dev/null | head -n 1)
    fi
    
    if [ -z "$SELFSERVICE" ] || [ ! -x "$SELFSERVICE" ]; then
      echo "Error: The Citrix selfservice binary is not found or not executable."
      echo "Please run 'setup-citrix-workspace' first."
      exit 1
    fi
    
    # Set up environment variables
    ICAROOT=$(dirname "$SELFSERVICE")
    export ICAROOT
    export CITRIX_NO_SUDO=1
    export CITRIX_DEBUG=1
    export WEBKIT_DISABLE_COMPOSITING_MODE=1
    
    echo "Starting Citrix Workspace in debug mode..."
    echo "Debug logs will be shown in the terminal."
    
    # Run with error filtering
    "$SELFSERVICE" "$@" 2>&1
  '';
  
  # Create a separate script to configure certificates
  citrixCertSetup = pkgs.writeShellScriptBin "setup-citrix-certs" ''
    #!/usr/bin/env bash
    mkdir -p $HOME/.ICAClient/keystore/cacerts
    
    # Copy certificates to Citrix directory
    echo "Setting up Citrix certificates..."
    ln -sf /etc/ssl/certs/* $HOME/.ICAClient/keystore/cacerts/ 2>/dev/null || true
    
    # Create module.ini if it doesn't exist
    if [ ! -f "$HOME/.ICAClient/module.ini" ]; then
      echo "Creating module.ini in $HOME/.ICAClient"
      cat > $HOME/.ICAClient/module.ini << EOF
[WFClient]
UseSystemCertificates=On
CertificatePath=/etc/ssl/certs
SSLCertificateRevocationCheckPolicy=NoCheck
CertificateRevocationCheckPolicy=NoCheck
UseCertificateAsProgramID=1
[WFClient.old]
UseSystemCertificates=On
[Hotkey Keys]
DisableCtrlAltDel=True
EOF
    fi

    # Create All_Regions.ini
    echo "Creating All_Regions.ini in $HOME/.ICAClient"
    cat > $HOME/.ICAClient/All_Regions.ini << EOF
[Trusted_Domains]
SystemRootCerts=1
UseSysStore=1

[WFClient]
UseSystemStore=1
SSLCertificateRevocationCheckPolicy=NoCheck
CertificateRevocationCheckPolicy=NoCheck
UseCertificateAsProgramID=1
UseSystemCertificates=1
SystemRootCerts=1
EOF

    echo "Certificate setup complete."
  '';
  
in {
  # Add the Citrix scripts and desktop entries to home packages
  home.packages = [
    citrixSetupScript
    citrixLauncher
    citrixIcaLauncher
    citrixDebugLauncher
    citrixCertSetup
    citrixRepair
    citrixDesktopEntry
    citrixIcaDesktopEntry
    citrixSystemDeps
    citrixCleanup
    
    # Add ONLY essential dependencies that won't trigger large builds
    pkgs.libidn
    pkgs.openssl
    
    # We avoid adding webkitgtk here since it takes too long to build
    # Instead, we'll use the distro's package via the install-citrix-deps script
  ];
  
  # Create file handlers for .ica files without replacing the entire mimeapps.list
  xdg = {
    enable = true;
    # Only manage the associations we need, don't replace the whole file
    mimeApps = {
      enable = true; 
      # Use associations instead of defaultApplications to more gently handle existing config
      associations.added = {
        "application/x-ica" = "citrix-workspace.desktop";
      };
      defaultApplications = lib.mkForce {}; # Don't force any defaults
    };
  };

  # Add convenient aliases for Citrix commands
  programs.bash.shellAliases = {
    selfservice = "citrix-workspace";
    wfica = "citrix-ica";
  };

  # Add activation for Citrix setup
  home.activation.citrixSetup = lib.hm.dag.entryAfter ["writeBoundary"] ''
    # Create required directories
    mkdir -p $HOME/.ICAClient/cache
    mkdir -p $HOME/.ICAClient/keystore/cacerts
    
    # Accept EULA automatically
    echo "1" > $HOME/.ICAClient/.eula_accepted
    
    # Disable problematic services
    systemctl --user stop ctxcwalogd.service 2>/dev/null || true
    systemctl --user disable ctxcwalogd.service 2>/dev/null || true
    rm -f "$HOME/.config/systemd/user/default.target.wants/ctxcwalogd.service" 2>/dev/null || true
    
    echo "Citrix Workspace configuration is prepared."
    echo "To complete installation, run these commands in order:"
    echo "1. install-citrix-deps (to install system dependencies)"
    echo "2. setup-citrix-workspace (to set up Citrix)"
    echo "3. After installation, you can launch Citrix with 'citrix-workspace'"
    echo "If you encounter any issues, run 'repair-citrix'"
  '';
}