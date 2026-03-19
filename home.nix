{
  config,
  pkgs,
  inputs,
  lib,
  ...
}:

let
  # Create a parameter to switch between desktop environments
  # Valid options: "cosmic" or "gnome"
  desktopEnvironment = "gnome";
  # desktopEnvironment = "cosmic";
in
{
  home.username = "emil";
  home.homeDirectory = "/home/emil";

  home.stateVersion = "25.05";

  programs.home-manager.enable = true;

  xdg.enable = true;

  nixpkgs.config.allowUnfreePredicate = _: true;

  repoFeatures.tailscale = {
    enableSystray = true; # Toggle to true to install and autostart tailscale-systray
    autoToggle = {
      enable = true;
      homeConnectionNames = [
        "Crynet_5G"
        "Crynet"
        "Crynet_IoT"
      ];
      homeSsids = [
        "Crynet_5G"
        "Crynet"
        "Crynet_IoT"
      ];
      homeGateways = [
        "192.168.2.1"
        "192.168.3.1"
      ];
    };
  };

  imports = [
    ./lib/system-specs.nix # System specifications from JSON
    ./lib/system-info.nix # System information display
    ./modules/secrets.nix # Shared secrets manager integration
    ./applications/applications.nix
    ./desktop/keyboard.nix # Import keyboard configuration
    ./desktop/graphics.nix # Import general graphics configuration
    ./desktop/nvidia.nix # Import NVIDIA-specific configuration
    ./desktop/performance.nix # Import system-specific performance configuration
    ./network/network.nix # Import network configuration
  ]
  ++ (
    if desktopEnvironment == "cosmic" then
      [
        inputs.cosmic-manager.homeManagerModules.default
        ./desktop/cosmic.nix
      ]
    else
      [ ./desktop/gnome.nix ]
  );

}
