{ pkgs, ... }:

{
  /*(pkgs.vscode.override { isInsiders = true; }).overrideAttrs (oldAttrs: rec {
    src = (builtins.fetchTarball {
      url = "https://code.visualstudio.com/sha/download?build=insider&os=linux-x64";
      sha256 = "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA";
    });
    version = "lat est";

    buildInputs = oldAttrs.buildInputs ++ [ pkgs.krb5 ];
  });*/

  programs.vscode = {
    enable = true;
    package = pkgs.vscode;

    profiles.default = {
      extensions = with pkgs.vscode-extensions; [
        arrterian.nix-env-selector
        jnoortheen.nix-ide
        github.copilot
        github.copilot-chat
      ];

      userSettings = {
        "editor.formatOnSave" = true;
        "nix.enableLanguageServer" = true;
        "github.copilot.enable" = true;
      };
    };
  };
}