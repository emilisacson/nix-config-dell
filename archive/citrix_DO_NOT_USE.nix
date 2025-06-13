{ pkgs, config, lib, ... }:

let
  # Define the version and package info
  citrixVersion = "25.03.0.66";
  citrixFilename = "ICAClient-rhel-${citrixVersion}-0.x86_64.rpm";
  
  # Create a Citrix package from the official RPM
  citrixWorkspace = pkgs.stdenv.mkDerivation rec {
    pname = "citrix-workspace";
    version = citrixVersion;
    
    # Use the RPM that we've already prefetched
    src = pkgs.fetchurl {
      url = "file://${config.home.homeDirectory}/Downloads/${citrixFilename}";
      hash = "sha256-vxWIrVB05weggQQst5rTY8GF7aMXdZ2kcHq7cZ9CnGE=";
    };
    
    # Tools needed to extract and process the RPM
    nativeBuildInputs = with pkgs; [ 
      rpm
      makeWrapper
      cpio
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
    
    # CRITICAL: Disable patchelf and other automatic fixes
    dontPatchELF = true;
    dontPatchShebangs = true;
    dontStrip = true;
    dontAutoPatchelf = true;
    
    unpackPhase = ''
      # Extract the RPM contents
      rpm2cpio $src | cpio -idmv
    '';
    
    installPhase = ''
      # Create the directory structure
      mkdir -p $out/opt/Citrix/ICAClient
      mkdir -p $out/opt/Citrix/ICAClient/lib
      mkdir -p $out/bin
      mkdir -p $out/share/applications
      
      # Check if the extracted directory exists
      if [ -d "./opt/Citrix/ICAClient" ]; then
        echo "Found ICAClient directory, copying files..."
        cp -r ./opt/Citrix/ICAClient/* $out/opt/Citrix/ICAClient/
      else
        echo "ERROR: Cannot find extracted ICAClient directory"
        find . -type d | grep -i citrix
        exit 1
      fi
      
      # WebKit library integration - find the most suitable library
      echo "Setting up WebKit libraries..."
      WEBKIT_PATHS=(
        "${pkgs.webkitgtk}/lib/libwebkit2gtk-4.0.so.37"
        "${pkgs.webkitgtk}/lib/libwebkit2gtk-4.0.so"
        "${pkgs.webkitgtk_4_1}/lib/libwebkit2gtk-4.1.so.0"
        "${pkgs.webkitgtk_4_1}/lib/libwebkit2gtk-4.1.so"
      )
      
      # Use the first existing WebKit library we find
      WEBKIT_LIB=""
      for path in "''${WEBKIT_PATHS[@]}"; do
        if [ -f "$path" ]; then
          WEBKIT_LIB="$path"
          echo "Found WebKit library: $WEBKIT_LIB"
          break
        fi
      done
      
      if [ -z "$WEBKIT_LIB" ]; then
        echo "WARNING: Could not find WebKit library in expected paths, searching Nix store..."
        # Try to find it in the Nix store as fallback
        WEBKIT_LIB=$(find /nix/store -path "*/lib/libwebkit2gtk-4.0.so.37" | head -n 1)
      fi
      
      if [ -z "$WEBKIT_LIB" ]; then
        echo "ERROR: Could not find any WebKit library!"
      else
        echo "Using WebKit library: $WEBKIT_LIB"
        
        # Create all necessary WebKit symlinks in the lib directory
        ln -sf "$WEBKIT_LIB" "$out/opt/Citrix/ICAClient/lib/libwebkit2gtk-4.0.so.37"
        ln -sf "$WEBKIT_LIB" "$out/opt/Citrix/ICAClient/lib/libwebkit2gtk-4.0.so"
        ln -sf "$WEBKIT_LIB" "$out/opt/Citrix/ICAClient/libwebkit2gtk-4.0.so.37"
        ln -sf "$WEBKIT_LIB" "$out/opt/Citrix/ICAClient/libwebkit2gtk-4.0.so"
      fi
      
      # Copy system certificates
      mkdir -p $out/opt/Citrix/ICAClient/keystore/cacerts
      cp -L ${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt $out/opt/Citrix/ICAClient/keystore/cacerts/
      
      # Ensure files have correct permissions
      chmod -R +x $out/opt/Citrix/ICAClient/
      
      echo "Creating wrapper scripts..."
      
      # Create main launcher script
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

# Fix for Internal error -1
export GTK_MODULES=""
export WEBKIT_DISABLE_COMPOSITING_MODE=1
export WEBKIT_FORCE_SANDBOX=0

# Set up library paths with all necessary dependencies
export LD_LIBRARY_PATH=${pkgs.lib.makeLibraryPath [
  pkgs.webkitgtk
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
  pkgs.libxml2
  pkgs.libxslt
]}:$ICAROOT:$ICAROOT/lib

# Accept EULA automatically
mkdir -p \$HOME/.ICAClient
echo "1" > \$HOME/.ICAClient/.eula_accepted 2>/dev/null

# Create a more compatible module.ini file if it doesn't exist
if [ ! -f "\$HOME/.ICAClient/module.ini" ]; then
  echo "Creating module.ini in \$HOME/.ICAClient"
  cat > \$HOME/.ICAClient/module.ini << EOT
[WFClient]
UseSystemCertificates=On
CertificatePath=${pkgs.cacert}/etc/ssl/certs
SSLCertificateRevocationCheckPolicy=NoCheck
CertificateRevocationCheckPolicy=NoCheck
UseCertificateAsProgramID=1
[WFClient.old]
UseSystemCertificates=On
[Hotkey Keys]
DisableCtrlAltDel=True
EOT
fi

# Create a config.ini file if it doesn't exist
if [ ! -f "\$HOME/.ICAClient/config.ini" ]; then
  echo "Creating config.ini in \$HOME/.ICAClient"
  cat > \$HOME/.ICAClient/config.ini << EOT
[Thinwire3.0]
DesktopBackgroundDefault=1
[Authentication]
UseSystemStore=True
EOT
fi

# Create All_Regions.ini file directly in user's home directory
cat > \$HOME/.ICAClient/All_Regions.ini << EOT
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
EOT

# Sets logging location to prevent permission issues
mkdir -p \$HOME/.ICAClient/logs

# Fix for Internal error -1
rm -f \$HOME/.ICAClient/cache/* 2>/dev/null
rm -f \$HOME/.ICAClient/.tmp/* 2>/dev/null

# Run the correct selfservice binary without the unsupported -logfile parameter
exec $out/opt/Citrix/ICAClient/selfservice "\$@"
EOF
      chmod +x $out/bin/citrix-workspace
      
      # Create debug launcher
      cat > $out/bin/citrix-workspace-debug << EOF
#!/bin/sh
echo "Starting Citrix Workspace in debug mode..."
export CITRIX_DEBUG=1
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
  pkgs.libxml2
  pkgs.libxslt
]}:$ICAROOT:$ICAROOT/lib

echo "ICAROOT=$ICAROOT"
echo "LD_LIBRARY_PATH=$LD_LIBRARY_PATH"

# Create the same configuration files as in the regular launcher
if [ ! -f "\$HOME/.ICAClient/module.ini" ]; then
  echo "Creating module.ini in \$HOME/.ICAClient"
  cat > \$HOME/.ICAClient/module.ini << EOT
[WFClient]
UseSystemCertificates=On
CertificatePath=${pkgs.cacert}/etc/ssl/certs
SSLCertificateRevocationCheckPolicy=NoCheck
CertificateRevocationCheckPolicy=NoCheck
UseCertificateAsProgramID=1
[WFClient.old]
UseSystemCertificates=On
[Hotkey Keys]
DisableCtrlAltDel=True
EOT
fi

cat > \$HOME/.ICAClient/All_Regions.ini << EOT
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
EOT

exec $out/opt/Citrix/ICAClient/selfservice "\$@"
EOF
      chmod +x $out/bin/citrix-workspace-debug
      
      # Create wfica wrapper
      cat > $out/bin/wfica << EOF
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
  pkgs.libxml2
  pkgs.libxslt
]}:$ICAROOT:$ICAROOT/lib

# Create the same configuration files as in the regular launcher
if [ ! -f "\$HOME/.ICAClient/module.ini" ]; then
  cat > \$HOME/.ICAClient/module.ini << EOT
[WFClient]
UseSystemCertificates=On
CertificatePath=${pkgs.cacert}/etc/ssl/certs
SSLCertificateRevocationCheckPolicy=NoCheck
CertificateRevocationCheckPolicy=NoCheck
UseCertificateAsProgramID=1
[WFClient.old]
UseSystemCertificates=On
[Hotkey Keys]
DisableCtrlAltDel=True
EOT
fi

exec $out/opt/Citrix/ICAClient/wfica "\$@"
EOF
      chmod +x $out/bin/wfica
      
      # Create desktop entry
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
    '';
    
    # Skip fixup phase entirely
    fixupPhase = ''
      echo "Skipping automatic patching - using wrapper scripts instead"
    '';
    
    meta = with lib; {
      description = "Citrix Workspace App (previously Citrix Receiver)";
      homepage = "https://www.citrix.com/";
      license = licenses.unfree;
      platforms = [ "x86_64-linux" ];
      maintainers = with maintainers; [ ];
    };
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
    mkdir -p $HOME/.ICAClient/config
    mkdir -p $HOME/.ICAClient/keystore/cacerts
    
    # Accept EULA automatically
    echo "1" > $HOME/.ICAClient/.eula_accepted
    
    # Fix SSL certificate configuration - important for preventing "corrupt ICA file" errors
    
    # Create module.ini - critical for certificate handling
    echo "Creating module.ini in $HOME/.ICAClient"
    cat > $HOME/.ICAClient/module.ini << EOF
[WFClient]
UseSystemCertificates=On
CertificatePath=${pkgs.cacert}/etc/ssl/certs
SSLCertificateRevocationCheckPolicy=NoCheck
CertificateRevocationCheckPolicy=NoCheck
UseCertificateAsProgramID=1
ClientHostedApps=0
UseFullScreen=True
TWIDefaultBrush=Off
DesiredColor=8
DesiredHRES=1024
DesiredVRES=768
[WFClient.old]
UseSystemCertificates=On
[Hotkey Keys]
DisableCtrlAltDel=True
EOF
    
    # Create config.ini
    echo "Creating config.ini in $HOME/.ICAClient"
    cat > $HOME/.ICAClient/config.ini << EOF
[Thinwire3.0]
DesktopBackgroundDefault=1
[Authentication]
UseSystemStore=True
EOF
    
    # Create wfclient.ini with proper SSL settings
    echo "Creating wfclient.ini in $HOME/.ICAClient"
    cat > $HOME/.ICAClient/wfclient.ini << EOF
[WFClient]
Version=2
KeyboardLayout=Universal
KeyboardType=ScanCode
KeyboardMappingFile=non_us.kbd
ProxyFavorIEConnectionSetting=Yes
ProxyTimeout=30000
ProxyType=Auto
ProxyUseFQDN=Off
RemoveICAFile=yes
TransportReconnectEnabled=Off
# Critical SSL certificate settings
SSLCertificateRevocationCheckPolicy=NoCheck
CertificateRevocationCheckPolicy=NoCheck
ValidateServerCertificatesSSL=0
ValidateServerCertificates=0
UseSystemCertificates=1
SSLEnable=On
UseSystemStore=1
SSLProxyHost=*:443
UseNSCwithIPandSSL=1

[Thinwire3.0]
DesktopBackgroundDefault=1
EOF

    # Create All_Regions.ini in both locations to ensure it's found
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
CleanupReleasedHotkeys=True
UseEUKS=True
UseRelativeHotkey=True
RemoveICAFile=Yes
# Use system certificate store to validate server certificates
UseSystemStore=1

[Http]
UseJWT=True

[ApplicationServers]
# Empty section needed

[Connection]
# Empty section needed

[PreferredClient]
Path=\$ICAROOT/selfservice
EOF

    # Also create it in the config directory as a backup
    mkdir -p $HOME/.ICAClient/config
    cp $HOME/.ICAClient/All_Regions.ini $HOME/.ICAClient/config/

    # Link system certificates
    echo "Linking system certificates"
    # Make sure directories exist and have correct permissions
    mkdir -p $HOME/.ICAClient/keystore
    mkdir -p $HOME/.ICAClient/keystore/cacerts
    chmod -R u+rw $HOME/.ICAClient/keystore
    
    # Now try to copy the certificate
    if cp -L ${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt $HOME/.ICAClient/keystore/cacerts/ 2>/dev/null; then
      echo "Successfully copied system certificates"
    else
      echo "Warning: Could not copy system certificates, trying alternate approach"
      # Try to create a symbolic link instead
      ln -sf ${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt $HOME/.ICAClient/keystore/cacerts/ 2>/dev/null || true
    fi

    # Create symlink for certificates if needed
    mkdir -p $HOME/.pki/nssdb || true
    
    # Manually check if the Citrix RPM file exists and update the hash if needed
    RPM_FILE="${config.home.homeDirectory}/Downloads/ICAClient-rhel-${citrixVersion}-0.x86_64.rpm"
    if [ -f "$RPM_FILE" ]; then
      echo "Found Citrix RPM: $RPM_FILE"
      
      # Calculate the hash using nix hash command
      NEW_HASH=$(nix hash file --type sha256 "$RPM_FILE" 2>/dev/null)
      
      if [ -n "$NEW_HASH" ]; then
        echo "Calculated hash: $NEW_HASH"
        
        # Update the hash in the citrix.nix file if it has changed
        CURRENT_HASH=$(grep -o 'hash = "sha256-[^"]*' ${config.home.homeDirectory}/nix-config/applications/citrix.nix | cut -d'-' -f2)
        
        if [ "$NEW_HASH" != "sha256-$CURRENT_HASH" ]; then
          echo "Updating hash in citrix.nix file..."
          sed -i "s|hash = \"sha256-[A-ZaZ0-9+=]*\"|hash = \"$NEW_HASH\"|" ${config.home.homeDirectory}/nix-config/applications/citrix.nix
        else
          echo "Hash is already up to date."
        fi
      else
        echo "Warning: Could not calculate hash for RPM file."
      fi
    else
      echo "Warning: Citrix RPM file not found at $RPM_FILE"
    fi
  '';
  
  # Add the option to make the citrix-workspace command available system-wide
  home.file.".bashrc.d/citrix-aliases.sh" = {
    executable = true;
    text = ''
      # Add Citrix Workspace aliases
      alias citrix="citrix-workspace"
      alias citrix-debug="citrix-workspace-debug"
    '';
  };
}
