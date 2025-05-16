{ pkgs, config, lib, ... }:

let
  # Create a Citrix package from the official RPM
  citrixWorkspace = pkgs.stdenv.mkDerivation {
    name = "citrix-workspace";
    
    # Use the RPM with its exact filename from the Downloads directory
    src = builtins.path {
      name = "citrix-workspace-rpm";
      path = "${config.home.homeDirectory}/Downloads/ICAClient-rhel-25.03.0.66-0.x86_64.rpm";
      filter = path: type: true;
    };
    
    # Tools needed to extract and process the RPM
    nativeBuildInputs = with pkgs; [ 
      rpm
      makeWrapper
      cpio
    ];
    
    # Runtime dependencies that will be added to the wrapper script's LD_LIBRARY_PATH
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
      libunwind
      freetype
      fontconfig
      zlib
      libpng
      libxml2
    ];
    
    # Disable automatic patching of ELF files
    dontPatchELF = true;
    
    # Extract files from the RPM
    unpackPhase = ''
      # Extract .rpm content (creates cpio archive)
      rpm2cpio $src > citrix.cpio
      
      # Extract the cpio archive
      mkdir -p extracted
      cd extracted
      cpio -idm < ../citrix.cpio
    '';
    
    installPhase = ''
      # Create target directory structure
      mkdir -p $out/opt/Citrix/ICAClient
      mkdir -p $out/bin
      mkdir -p $out/share/applications
      
      # Copy all extracted files
      cp -r opt/Citrix/ICAClient/* $out/opt/Citrix/ICAClient/
      
      # Ensure executables have proper permissions
      find $out/opt/Citrix/ICAClient -type f -name "*.so*" -exec chmod +x {} \;
      find $out/opt/Citrix/ICAClient -type f -executable -exec chmod +x {} \;
      
      # Create the config directory structure and important files
      mkdir -p $out/opt/Citrix/ICAClient/keystore/cacerts
      mkdir -p $out/opt/Citrix/ICAClient/config
      
      # Pre-accept the EULA directly in the Citrix installation directory
      echo "1" > $out/opt/Citrix/ICAClient/.eula_accepted
      echo "1" > $out/opt/Citrix/ICAClient/config/.eula_accepted
      
      # Link system certificates
      for cert in ${pkgs.cacert}/etc/ssl/certs/*.pem; do
        ln -sf $cert $out/opt/Citrix/ICAClient/keystore/cacerts/
      done
      
      # Create desktop file for launching .ica files directly
      cat > $out/share/applications/citrix-ica.desktop << INNEREOF
[Desktop Entry]
Type=Application
Name=Citrix ICA Client
Comment=Access Citrix virtual desktops and applications
Exec=$out/bin/citrix-ica %f
Icon=$out/opt/Citrix/ICAClient/icons/receiver.png
Terminal=false
Categories=Network;RemoteAccess;
MimeType=application/x-ica;
INNEREOF

      # Define LD_LIBRARY_PATH 
      CITRIX_LIB_PATH=${pkgs.lib.makeLibraryPath [
        pkgs.gtk3
        pkgs.glib
        pkgs.webkitgtk
        pkgs.webkitgtk_4_1
        pkgs.nss
        pkgs.nspr
        pkgs.openssl
        pkgs.libidn
        pkgs.gst_all_1.gstreamer
        pkgs.gst_all_1.gst-plugins-base
        pkgs.libunwind
        pkgs.libxml2
        pkgs.libsecret
        pkgs.xorg.libX11
        pkgs.xorg.libXext
        pkgs.xorg.libXfixes
        pkgs.xorg.libXmu
        pkgs.xorg.libXtst
        pkgs.stdenv.cc.cc.lib
      ]}

      # Create a direct ICA launcher that bypasses the selfservice app
      makeWrapper $out/opt/Citrix/ICAClient/wfica $out/bin/citrix-ica \
        --set ICAROOT "$out/opt/Citrix/ICAClient" \
        --set GTK_PATH "${pkgs.gtk3}/lib/gtk-3.0" \
        --set SSL_CERT_FILE "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt" \
        --set GIO_MODULE_DIR "${pkgs.glib-networking}/lib/gio/modules" \
        --set LIBCITRIX_DISABLE_CTX_MITM_CHECK "1" \
        --set LIBCITRIX_CTX_SSL_FORCE_ACCEPT "1" \
        --set LIBCITRIX_CTX_SSL_VERIFY_MODE "0" \
        --set ICA_SSL_VERIFY_MODE "0" \
        --prefix LD_LIBRARY_PATH : "$CITRIX_LIB_PATH:$out/opt/Citrix/ICAClient" \
        --run "mkdir -p \$HOME/.ICAClient/cache \$HOME/.ICAClient/keystore/cacerts" \
        --run "echo 1 > \$HOME/.ICAClient/.eula_accepted" \
        --run "ln -sf ${pkgs.cacert}/etc/ssl/certs/* \$HOME/.ICAClient/keystore/cacerts/ 2>/dev/null || true"

      # Create a simple shell script that users can run to connect to their Citrix portal
      cat > $out/bin/connect-to-citrix << INNEREOF
#!/bin/sh
# Simple script to help users connect to Citrix

echo ""
echo "===== Citrix Workspace ICA Connection ====="
echo ""
echo "To connect to your Citrix environment, you need to:"
echo ""
echo "1. Go to your organization's Citrix web portal in a browser"
echo "2. Log in to the portal"
echo "3. Click on the app or desktop you want to access"
echo "4. When prompted to open or save the .ica file, choose 'Open'"
echo "   (This will automatically launch the Citrix ICA client)"
echo ""
echo "If the file gets downloaded instead, you can open it with:"
echo "citrix-ica /path/to/downloaded/file.ica"
echo ""
echo "Your Citrix client is configured and ready to use!"
echo ""

# Check if an argument was provided (URL to portal)
if [ ! -z "\$1" ]; then
  echo "Opening \$1 in your default browser..."
  xdg-open "\$1"
fi
INNEREOF
      chmod +x $out/bin/connect-to-citrix
    '';
  };

in {
  # Add citrixWorkspace to the user's packages
  home.packages = [ citrixWorkspace ];
  
  # Create file handlers for .ica files
  xdg.mimeApps = {
    enable = true;
    defaultApplications = {
      "application/x-ica" = "citrix-ica.desktop";
    };
  };
  
  # Add an activation script to set up required files
  home.activation.setupCitrix = lib.hm.dag.entryAfter ["writeBoundary"] ''
    # Create required directories
    mkdir -p $HOME/.ICAClient/cache
    mkdir -p $HOME/.ICAClient/keystore/cacerts
    
    # Accept EULA automatically
    echo "1" > $HOME/.ICAClient/.eula_accepted
    
    # Create symlink for certificates if needed
    mkdir -p $HOME/.pki/nssdb || true
    
    # Copy certificates to Citrix directory
    echo "Setting up Citrix certificates..."
    ln -sf ${pkgs.cacert}/etc/ssl/certs/* $HOME/.ICAClient/keystore/cacerts/ 2>/dev/null || true
  '';
}