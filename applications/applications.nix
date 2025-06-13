{ config, pkgs, lib, ... }:

let
  # System-specific application configurations
  # Define which applications should be installed per system
  systemSpecs = config.systemSpecs;
  systemId = systemSpecs.system_id or "unknown";

  # System-specific application mappings
  systemSpecificApps = {
    "laptop-20Y30016MX-hybrid" = [
      pkgs.teams-for-linux # Microsoft Teams client (IsmaelMartinez/teams-for-linux)
    ];
    "laptop-Latitude_7410-intel" = [
      # No system-specific apps for this system
    ];
  };

  # Get applications for current system (fallback to empty list if system not found)
  currentSystemApps = systemSpecificApps.${systemId} or [ ];

in {
  # Import specific application modules
  imports = [
    #./citrix.nix
    ./vscode.nix
    ./steam.nix
    ./python.nix
    ./brave.nix
    ./onedrive.nix
    ./discord.nix
    ./flameshot.nix
    ./obs-studio.nix
    ./media-codecs.nix
    ./obsidian.nix
    ./onenote-graph.nix
  ];

  home.packages = with pkgs;
    [
      # Core applications (installed on all systems)
      keepassxc
      git
      tmux
      appeditor
      hwinfo
    ] ++ currentSystemApps; # Add system-specific applications
}
