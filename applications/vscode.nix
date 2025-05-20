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

    # Extensions managable by VS Code
    mutableExtensionsDir = true;

    profiles.default = {
      extensions = with unstable.vscode-extensions; [
        arrterian.nix-env-selector
        jnoortheen.nix-ide
        github.copilot
        github.copilot-chat
        ms-python.python
        ms-python.vscode-pylance
      ];

      userSettings = {
        "editor.formatOnSave" = true;
        "nix.enableLanguageServer" = true;
        "github.copilot.enable" = true;
        "nix.formatterPath" = "${pkgs.nixfmt-classic}/bin/nixfmt";

        # Python settings
        "python.defaultInterpreterPath" =
          "${pkgs.python3.withPackages (ps: with ps; [ tkinter ])}/bin/python3";
        "python.formatting.provider" = "black";
        "python.formatting.blackPath" =
          "${pkgs.python3Packages.black}/bin/black";
        "python.linting.enabled" = true;
        "python.linting.flake8Enabled" = true;
        "python.linting.flake8Path" =
          "${pkgs.python3Packages.flake8}/bin/flake8";
        "python.linting.mypyEnabled" = true;
        "python.linting.mypyPath" = "${pkgs.python3Packages.mypy}/bin/mypy";
        "python.analysis.extraPaths" = [
          "${
            pkgs.python3.withPackages (ps: with ps; [ tkinter ])
          }/lib/python3.12/site-packages"
        ]; # Using Python 3.12
        "[python]" = {
          "editor.formatOnSave" = true;
          "editor.codeActionsOnSave" = { "source.organizeImports" = true; };
        };
      };
    };
  };

  # Make nixfmt available in PATH for VS Code
  home.packages = [ pkgs.nixfmt-classic ];
}
