{ config, pkgs, ... }:

{
  home.username = "emil";
  home.homeDirectory = "/home/emil";

  home.stateVersion = "24.11"; # or current NixOS version, just pick a recent one

  programs.home-manager.enable = true;

  home.packages = with pkgs; [
    git
  ];
}
