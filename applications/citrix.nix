{ pkgs, config, lib, ... }:

let
  # Define a custom citrix package by overriding the existing one in nixpkgs
  customCitrix = pkgs.citrix_workspace.overrideAttrs (attrs: {
    version = "24.11.0.85";
    # The src is already defined in citrix_workspace, we don't need to override it
    # unless you want to use a different version than what's included in nixpkgs
  });
  
  # Create wrapper scripts for Citrix commands with proper bin directory
  citrixWrapperScripts = pkgs.symlinkJoin {
    name = "citrix-workspace-wrappers";
    paths = [
      (pkgs.writeShellScriptBin "citrix-workspace" ''
        exec selfservice "$@"
      '')
      (pkgs.writeShellScriptBin "citrix-ica" ''
        exec wfica "$@"
      '')
      (pkgs.writeShellScriptBin "citrix-workspace-debug" ''
        CITRIX_DEBUG=1 exec selfservice "$@"
      '')
    ];
  };
in {
  # Use the custom citrix package and wrapper scripts
  home.packages = [ 
    customCitrix
    citrixWrapperScripts
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

  # Add convenient aliases for Citrix commands (as a backup)
  programs.bash.shellAliases = {
    citrix-workspace = "selfservice";
    citrix-ica = "wfica";
  };

  # If you use zsh, uncomment these lines
  # programs.zsh.shellAliases = {
  #   citrix-workspace = "selfservice";
  #   citrix-ica = "wfica";
  # };
  
  # Add an activation script to set up required files
  /*home.activation.setupCitrix = lib.hm.dag.entryAfter ["writeBoundary"] ''
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
    
    # Create module.ini if it doesn't exist
    if [ ! -f "$HOME/.ICAClient/module.ini" ]; then
      echo "Creating module.ini in $HOME/.ICAClient"
      cat > $HOME/.ICAClient/module.ini << EOF
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
  '';*/
}