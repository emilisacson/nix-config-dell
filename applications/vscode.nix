{ pkgs, unstable, lib, config, ... }:

{
  /* Insiders version of VS Code
     (pkgs.vscode.override { isInsiders = true; }).overrideAttrs (oldAttrs: rec {
       src = (builtins.fetchTarball {
         url = "https://code.visualstudio.com/sha/download?build=insider&os=linux-x64";
         sha256 = "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA";
       });
       version = "lat est";

       buildInputs = oldAttrs.buildInputs ++ [ pkgs.krb5 ];
     });
  */

  # VS Code configuration with latest version from Microsoft
  programs.vscode = {
    enable = true;
    package = (pkgs.vscode.override { }).overrideAttrs (oldAttrs: rec {
      src = (builtins.fetchTarball {
        url = "https://update.code.visualstudio.com/latest/linux-x64/stable";
        sha256 = "sha256:1gicmx3lkifigwr6dqf8gghbm1fmiafdzrbw2x5069absji3x6pg";
      });
      version = "latest";
      buildInputs = oldAttrs.buildInputs ++ [ pkgs.krb5 pkgs.nixfmt-classic ];
    });

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
