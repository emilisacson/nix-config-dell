{ pkgs, config, lib, ... }:

let
  # Define the version and package info
  citrixVersion = "25.03.0.66";
  citrixFilename = "icaclientWeb_25.3.0.66_rhel8.4x64.rpm";
  
  # Create a Citrix package from the official RPM
  citrixWorkspace = pkgs.stdenv.mkDerivation {
    name = "citrix-workspace-${citrixVersion}";
    
    # Use the RPM that we've downloaded locally
    src = pkgs.fetchurl {
      name = citrixFilename;
      url = "file://${config.home.homeDirectory}/Downloads/${citrixFilename}";
      # The hash will be determined by the add-citrix-to-nix.sh script
      # You don't need to set this manually
      hash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="; # Placeholder
    };
    
    # Tools needed to extract and process the RPM
    nativeBuildInputs = with pkgs; [ 
      rpm
      autoPatchelfHook
      makeWrapper
      cpio
    ];
    
    # Runtime dependencies
    buildInputs = with pkgs; [
      gtk3
      glib
      gdk-pixbuf
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
    ];
    
    # Extract files from the RPM
    unpackPhase = ''
      # Extract .rpm content (creates cpio archive)
      rpm2cpio $src > citrix.cpio
      
      # Extract the cpio archive
      mkdir -p extracted
      cd extracted
      cpio -idm < ../citrix.cpio
      
      # Now we're in the directory with the extracted content
      cd ..
      
      # Debug info - see what files were extracted
      find extracted -type f -name "selfservice" | sort
    '';
    
    installPhase = ''
      # Create target directory structure
      mkdir -p $out/opt/Citrix/ICAClient
      mkdir -p $out/bin
      mkdir -p $out/share/applications
      
      # Copy all extracted files
      cp -r extracted/opt/Citrix/ICAClient/* $out/opt/Citrix/ICAClient/
      
      # Ensure executables have proper permissions
      find $out/opt/Citrix/ICAClient -type f -name "*.so*" -exec chmod +x {} \;
      find $out/opt/Citrix/ICAClient -type f -executable -exec chmod +x {} \;
      
      # Create desktop file
      cat > $out/share/applications/citrix-workspace.desktop << EOF
[Desktop Entry]
Type=Application
Name=Citrix Workspace
Comment=Access virtual desktops and applications
Exec=$out/bin/citrix-workspace %U
Icon=$out/opt/Citrix/ICAClient/icons/receiver.png
Terminal=false
Categories=Network;RemoteAccess;
MimeType=application/x-ica;
EOF
      
      # Create wrapper script
      cat > $out/bin/citrix-workspace << EOF
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

# Set up library paths
export LD_LIBRARY_PATH=${pkgs.lib.makeLibraryPath [
  pkgs.webkitgtk_4_1
  pkgs.gtk3
  pkgs.glib
  pkgs.nss
  pkgs.openssl
  pkgs.libidn
  pkgs.gst_all_1.gstreamer
  pkgs.gst_all_1.gst-plugins-base
]}:$ICAROOT

# Accept EULA automatically
mkdir -p \$HOME/.ICAClient
echo "1" > \$HOME/.ICAClient/.eula_accepted 2>/dev/null

exec $out/opt/Citrix/ICAClient/selfservice "\$@"
EOF
      chmod +x $out/bin/citrix-workspace
      
      # Create symlinks for main executables
      ln -sf $out/opt/Citrix/ICAClient/wfica $out/bin/wfica
      
      # Also create a debug launcher
      cat > $out/bin/citrix-workspace-debug << EOF
#!/bin/sh
echo "Starting Citrix Workspace in debug mode..."
export CITRIX_DEBUG=1
export ICAROOT=$out/opt/Citrix/ICAClient
export GTK_PATH=${pkgs.gtk3}/lib/gtk-3.0
export SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt
export GIO_MODULE_DIR=${pkgs.glib-networking}/lib/gio/modules

# Set up library paths
export LD_LIBRARY_PATH=${pkgs.lib.makeLibraryPath [
  pkgs.webkitgtk_4_1
  pkgs.gtk3
  pkgs.glib
  pkgs.nss
  pkgs.openssl
  pkgs.libidn
  pkgs.gst_all_1.gstreamer
  pkgs.gst_all_1.gst-plugins-base
]}:$ICAROOT

echo "ICAROOT=$ICAROOT"
echo "LD_LIBRARY_PATH=$LD_LIBRARY_PATH"
exec $out/opt/Citrix/ICAClient/selfservice "\$@"
EOF
      chmod +x $out/bin/citrix-workspace-debug
    '';
    
    # Let autoPatchelfHook do its job
    dontPatchELF = false;
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