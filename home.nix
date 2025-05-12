{ config, pkgs, ... }:

{
  home.username = "emil";
  home.homeDirectory = "/home/emil";

  home.stateVersion = "24.11";

  programs.home-manager.enable = true;

  xdg.enable = true;

  home.packages = with pkgs; [
    git
    vscodium
  ];

  imports = [
    ./applications/vscode.nix
  ];
}