{ config, pkgs, inputs, ... }:

let
  # Create a parameter to switch between desktop environments
  # Valid options: "cosmic" or "gnome"
  desktopEnvironment = "gnome";
  # desktopEnvironment = "cosmic";
in {
  home.username = "emil";
  home.homeDirectory = "/home/emil";

  home.stateVersion = "25.05";

  programs.home-manager.enable = true;

  xdg.enable = true;

  nixpkgs.config.allowUnfreePredicate = _: true;

  imports = [
    ./applications/applications.nix
    ./desktop/keyboard.nix # Import keyboard configuration
    ./desktop/nvidia.nix # Import NVIDIA configuration
    ./network/network.nix # Import network configuration
  ] ++ (if desktopEnvironment == "cosmic" then [
    inputs.cosmic-manager.homeManagerModules.default
    ./desktop/cosmic.nix
  ] else
    [ ./desktop/gnome.nix ]);
}
