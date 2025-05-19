{ pkgs, unstable, ... }:

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

    # Allow VS Code to manage its own extensions directory
    mutableExtensionsDir = true;

    profiles.default = {
      extensions = with unstable.vscode-extensions; [
        arrterian.nix-env-selector
        jnoortheen.nix-ide
        github.copilot
        github.copilot-chat
      ];

      userSettings = {
        "editor.formatOnSave" = true;
        "nix.enableLanguageServer" = true;
        "github.copilot.enable" = true;
        "nix.formatterPath" = "${pkgs.nixfmt-classic}/bin/nixfmt";
      };
    };
  };

  # Make nixfmt available in PATH for VS Code
  home.packages = [ pkgs.nixfmt-classic ];

  # Old configuration for reference
  # programs.vscode = {
  #   enable = true;
  #   package = pkgs.vscode;
  #
  #   profiles.default = {
  #     extensions = with pkgs.vscode-extensions; [
  #       arrterian.nix-env-selector
  #       jnoortheen.nix-ide
  #       github.copilot
  #       github.copilot-chat
  #     ];
  #
  #     userSettings = {
  #       "editor.formatOnSave" = true;
  #       "nix.enableLanguageServer" = true;
  #       "github.copilot.enable" = true;
  #       "update.mode" = "none";  # Disables update checking
  #     };
  #   };
  # };
}
