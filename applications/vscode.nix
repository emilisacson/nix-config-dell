{ pkgs, unstable, lib, config, ... }:

let
  # Toggle between VS Code Insiders and stable version
  useInsiders = false; # Set to false to use stable version

  vscodePackage = if useInsiders then
  # VS Code Insiders version
    (pkgs.vscode.override { isInsiders = true; }).overrideAttrs (oldAttrs: rec {
      src = (builtins.fetchTarball {
        url =
          "https://code.visualstudio.com/sha/download?build=insider&os=linux-x64";
        sha256 = "sha256:0yad7xdr28lbq4m0h97fapzifjbkb47m6ds6szzalpz8m9lc1hvj";
      });
      version = "latest";
      buildInputs = oldAttrs.buildInputs ++ [ pkgs.krb5 ];
      postInstall = (oldAttrs.postInstall or "") + ''
        # Create a 'code' symlink for VS Code Insiders
        ln -sf $out/bin/code-insiders $out/bin/code || true

        # Create a standard 'code.desktop' entry for GNOME launcher
        if [ -f $out/share/applications/code-insiders.desktop ]; then
          cp $out/share/applications/code-insiders.desktop $out/share/applications/code.desktop
          # Update the desktop entry to use the generic 'code' command
          sed -i 's/code-insiders/code/g' $out/share/applications/code.desktop
          sed -i 's/Code - Insiders/Visual Studio Code/g' $out/share/applications/code.desktop
          sed -i 's/Visual Studio Code - Insiders/Visual Studio Code/g' $out/share/applications/code.desktop
        fi
      '';
    })
  else
  # VS Code stable version
    (pkgs.vscode.override { }).overrideAttrs (oldAttrs: rec {
      src = (builtins.fetchTarball {
        url = "https://update.code.visualstudio.com/latest/linux-x64/stable";
        sha256 = "sha256:1gicmx3lkifigwr6dqf8gghbm1fmiafdzrbw2x5069absji3x6pg";
      });
      version = "latest";
      buildInputs = oldAttrs.buildInputs ++ [ pkgs.krb5 pkgs.nixfmt-classic ];
    });
in {
  # VS Code configuration with configurable version
  programs.vscode = {
    enable = true;
    package = vscodePackage;

    # Allow VS Code to manage extensions
    mutableExtensionsDir = true;

    # Just install the extensions, but let VS Code manage the settings
    profiles.default = {
      extensions = let
        yutengjing-modify-file-warning =
          unstable.vscode-utils.extensionFromVscodeMarketplace {
            name = "modify-file-warning";
            publisher = "yutengjing";
            version = "1.0.0";
            sha256 = "sha256-U86l4XIfr2LVD93tU6wfMREvnRGejnJWxDaLJAXiJes=";
          };
      in with unstable.vscode-extensions; [
        arrterian.nix-env-selector
        jnoortheen.nix-ide
        github.copilot
        github.copilot-chat
        ms-python.python
        ms-python.vscode-pylance
        shd101wyy.markdown-preview-enhanced
        yutengjing-modify-file-warning # Custom extension from marketplace
      ];
    };
  };

  # Make nixfmt available in PATH for VS Code
  home.packages = [ pkgs.nixfmt-classic ];

  # Add an activation script to set up VS Code settings
  home.activation.vscodeProfiles = lib.mkForce
    (lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      echo "Setting up VS Code settings..."
      $DRY_RUN_CMD ${config.home.homeDirectory}/.nix-config/extras/setup-vscode-settings.sh
    '');
}
