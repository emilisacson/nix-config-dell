{ pkgs, config, lib, ... }:

let
  # Define the version and package info
  citrixVersion = "25.03.0.66";
  citrixFilename = "ICAClient-rhel-25.03.0.66-0.x86_64.rpm";
  
  # Create a Citrix package from the official RPM
  citrixWorkspace = pkgs.stdenv.mkDerivation {
    name = "citrix-workspace-${citrixVersion}";
    
    # Use the RPM that we've already prefetched
    src = pkgs.fetchurl {
      name = citrixFilename;
      url = "file://${config.home.homeDirectory}/Downloads/${citrixFilename}";
      hash = "sha256-vxWIrVB05weggQQst5rTY8GF7aMXdZ2kcHq7cZ9CnGE=";
    };
    
    # Tools needed to extract and process the RPM
    nativeBuildInputs = with pkgs; [ 
      rpm
      makeWrapper
      cpio
      patchelf
    ];
    
    # Runtime dependencies
    buildInputs = with pkgs; [
      gtk3
      glib
      gdk-pixbuf
      webkitgtk
      webkitgtk_4_1
      nss
      nspr
      xorg.libxkbfile
      libsecret
      libidn
      openssl
      xorg.libXmu
      xorg.libXtst
      xorg.libXaw
      xorg.libXinerama
      xorg.libX11
      xorg.libXext
      xorg.libXrender
      xorg.libXfixes
      gst_all_1.gstreamer
      gst_all_1.gst-plugins-base
      alsa-lib
      pcsclite
      libopus
      opencv
    ];
    
    # Allow impure paths for the RPM and skip standard phases
    dontUnpack = true;
    dontConfigure = true;
    dontBuild = true;
    dontStrip = true;
    
    # Important: disable autoPatchelf completely to avoid issues
    dontAutoPatchelf = true;
    
    # Combine unpacking and installation into a single phase
    installPhase = ''
      # Create target directory structure
      mkdir -p $out/opt/Citrix/ICAClient
      mkdir -p $out/bin
      mkdir -p $out/share/applications
      
      # Create a temporary directory for extraction
      EXTRACT_DIR=$(mktemp -d)
      
      echo "Extracting RPM to $EXTRACT_DIR"
      cd $EXTRACT_DIR
      
      # Extract .rpm content (creates cpio archive)
      rpm2cpio $src > citrix.cpio
      
      # Extract the cpio archive
      mkdir -p extracted
      cd extracted
      cpio -idm < ../citrix.cpio
      
      echo "RPM extracted, checking directory structure:"
      find . -maxdepth 3 -type d
      
      # Check for ICAClient in standard location
      if [ -d "./opt/Citrix/ICAClient" ]; then
        echo "Found ICAClient in standard location"
        cp -r ./opt/Citrix/ICAClient/* $out/opt/Citrix/ICAClient/
      elif [ -d "./usr/share/Citrix" ]; then
        echo "Found Citrix in usr/share"
        cp -r ./usr/share/Citrix/* $out/opt/Citrix/ICAClient/
      else
        # Search for ICAClient directory anywhere in the extracted files
        echo "Searching for ICAClient directory..."
        ICACLIENT_DIR=$(find . -name "ICAClient" -type d | head -1)
        
        if [ -n "$ICACLIENT_DIR" ]; then
          echo "Found ICAClient directory at $ICACLIENT_DIR"
          cp -r $ICACLIENT_DIR/* $out/opt/Citrix/ICAClient/
        else
          echo "ERROR: Could not find ICAClient directory"
          find . -type d | sort
          exit 1
        fi
      fi
      
      # Clean up
      cd /
      rm -rf $EXTRACT_DIR
      
      # Ensure executables have proper permissions
      find $out/opt/Citrix/ICAClient -type f -name "*.so*" -exec chmod +x {} \;
      find $out/opt/Citrix/ICAClient -type f -executable -exec chmod +x {} \;
      
      # Create desktop file
      cat > $out/share/applications/citrix-workspace.desktop << INNEREOF
[Desktop Entry]
Type=Application
Name=Citrix Workspace
Comment=Access virtual desktops and applications
Exec=$out/bin/citrix-workspace %U
Icon=$out/opt/Citrix/ICAClient/icons/receiver.png
Terminal=false
Categories=Network;RemoteAccess;
MimeType=application/x-ica;
INNEREOF
    '';
    
    # Use a custom postInstall phase instead of autoPatchelfHook for more control
    postInstall = ''
      echo "Creating wrapper scripts..."
      
      # Create main launcher script
      cat > $out/bin/citrix-workspace << INNEREOF
#!/bin/sh
export ICAROOT=$out/opt/Citrix/ICAClient
export GTK_PATH=${pkgs.gtk3}/lib/gtk-3.0
export SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt
export GIO_MODULE_DIR=${pkgs.glib-networking}/lib/gio/modules

# SSL settings
export LIBCITRIX_DISABLE_CTX_MITM_CHECK=1
export LIBCITRIX_CTX_SSL_FORCE_ACCEPT=1
export LIBCITRIX_CTX_SSL_VERIFY_MODE=0
export ICA_SSL_VERIFY_MODE=0

# Set up library paths - this is the key to making it work without autoPatchelf
export LD_LIBRARY_PATH=${pkgs.lib.makeLibraryPath [
  pkgs.webkitgtk_4_1
  pkgs.gtk3
  pkgs.glib
  pkgs.nss
  pkgs.nspr
  pkgs.openssl
  pkgs.libidn
  pkgs.gst_all_1.gstreamer
  pkgs.gst_all_1.gst-plugins-base
  pkgs.alsa-lib
  pkgs.pcsclite
  pkgs.libopus
  pkgs.opencv
  pkgs.xorg.libXmu
  pkgs.xorg.libXtst
  pkgs.xorg.libXaw
  pkgs.xorg.libXinerama
  pkgs.xorg.libX11
  pkgs.xorg.libXext
  pkgs.xorg.libXrender
  pkgs.xorg.libXfixes
  pkgs.libsecret
  pkgs.stdenv.cc.cc.lib
]}:$ICAROOT

# Accept EULA automatically
mkdir -p \$HOME/.ICAClient
echo "1" > \$HOME/.ICAClient/.eula_accepted 2>/dev/null

exec $out/opt/Citrix/ICAClient/selfservice "\$@"
INNEREOF
      chmod +x $out/bin/citrix-workspace
      
      # Create symlinks for main executables
      ln -sf $out/opt/Citrix/ICAClient/wfica $out/bin/wfica
      
      # Also create a debug launcher
      cat > $out/bin/citrix-workspace-debug << INNEREOF
#!/bin/sh
echo "Starting Citrix Workspace in debug mode..."
export CITRIX_DEBUG=1
export ICAROOT=$out/opt/Citrix/ICAClient
export GTK_PATH=${pkgs.gtk3}/lib/gtk-3.0
export SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt
export GIO_MODULE_DIR=${pkgs.glib-networking}/lib/gio/modules

# Set up library paths - this is the key to making it work without autoPatchelf
export LD_LIBRARY_PATH=${pkgs.lib.makeLibraryPath [
  pkgs.webkitgtk_4_1
  pkgs.gtk3
  pkgs.glib
  pkgs.nss
  pkgs.nspr
  pkgs.openssl
  pkgs.libidn
  pkgs.gst_all_1.gstreamer
  pkgs.gst_all_1.gst-plugins-base
  pkgs.alsa-lib
  pkgs.pcsclite
  pkgs.libopus
  pkgs.opencv
  pkgs.xorg.libXmu
  pkgs.xorg.libXtst
  pkgs.xorg.libXaw
  pkgs.xorg.libXinerama
  pkgs.xorg.libX11
  pkgs.xorg.libXext
  pkgs.xorg.libXrender
  pkgs.xorg.libXfixes
  pkgs.libsecret
  pkgs.stdenv.cc.cc.lib
]}:$ICAROOT

echo "ICAROOT=$ICAROOT"
echo "LD_LIBRARY_PATH=$LD_LIBRARY_PATH"
exec $out/opt/Citrix/ICAClient/selfservice "\$@"
INNEREOF
      chmod +x $out/bin/citrix-workspace-debug
    '';
  };

in {
  # Add citrixWorkspace to the user's packages
  home.packages = [ citrixWorkspace ];
  
  # Create file handlers for .ica files
  xdg.mimeApps = {
    enable = true;
    defaultApplications = {
      "application/x-ica" = "citrix-workspace.desktop";
    };
  };
  
  # Add an activation script to set up required files
  home.activation.setupCitrix = lib.hm.dag.entryAfter ["writeBoundary"] ''
    # Create required directories
    mkdir -p $HOME/.ICAClient/cache
    
    # Accept EULA automatically
    echo "1" > $HOME/.ICAClient/.eula_accepted
    
    # Create symlink for certificates if needed
    mkdir -p $HOME/.pki/nssdb || true
  '';
}
