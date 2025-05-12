{ config, pkgs, inputs, ... }:

{
  home.username = "emil";
  home.homeDirectory = "/home/emil";

  home.stateVersion = "24.11";

  programs.home-manager.enable = true;

  xdg.enable = true;

  nixpkgs.config.allowUnfreePredicate = _: true;

  home.packages = with pkgs; [
    git
    vscode
    brave
  ];

  imports = [
    inputs.cosmic-manager.homeManagerModules.default
    ./applications/vscode.nix
    ./desktop/cosmic.nix  # Import the COSMIC settings from the dedicated file
  ];
}