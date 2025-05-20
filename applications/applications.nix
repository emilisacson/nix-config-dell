{ pkgs, ... }:

{
  # Import specific application modules
  imports = [
    ./citrix.nix
    ./vscode.nix
    ./steam.nix
    ./python.nix
    ./brave.nix
    ./evolution.nix
  ];

  # Install applications
  home.packages = with pkgs; [
    # Password manager
    keepassxc

    # Microsoft applications and alternatives
    p3x-onenote # OneNote alternative (patrikx3/onenote)
    onedrive # OneDrive client (abraunegg/onedrive)
    teams-for-linux # Microsoft Teams client (IsmaelMartinez/teams-for-linux)

    git
    obsidian
  ];
}
