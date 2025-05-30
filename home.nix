{ config, pkgs, inputs, lib, systemConfig ? null, ... }:

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
    ./lib/system-info.nix # System information display
    ./applications/applications.nix
    ./desktop/keyboard.nix # Import keyboard configuration
    ./desktop/graphics.nix # Import general graphics configuration
    ./desktop/nvidia.nix # Import NVIDIA-specific configuration
    ./network/network.nix # Import network configuration
  ] ++ (if desktopEnvironment == "cosmic" then [
    inputs.cosmic-manager.homeManagerModules.default
    ./desktop/cosmic.nix
  ] else
    [ ./desktop/gnome.nix ]);
}
