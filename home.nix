{ config, pkgs, inputs, ... }:

{
  home.username = "emil";
  home.homeDirectory = "/home/emil";

  home.stateVersion = "24.11";

  programs.home-manager.enable = true;

  xdg.enable = true;

  nixpkgs.config.allowUnfreePredicate = _: true;

  imports = [
    inputs.cosmic-manager.homeManagerModules.default
    ./applications/applications.nix
    ./desktop/cosmic.nix
  ];
}