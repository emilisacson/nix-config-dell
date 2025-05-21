{ pkgs, ... }:

{
  # Import specific application modules
  imports = [
    #./citrix.nix
    ./vscode.nix
    ./steam.nix
    ./python.nix
    ./brave.nix
    # ./evolution.nix
    ./onedrive.nix
    # ./onenote.nix
    ./discord.nix
    ./flameshot.nix
    ./obs-studio.nix
    ./media-codecs.nix
    ./obsidian.nix
  ];

  # Install applications
  home.packages = with pkgs; [
    keepassxc

    p3x-onenote # OneNote alternative (patrikx3/onenote)
    #teams-for-linux # Microsoft Teams client (IsmaelMartinez/teams-for-linux)

    git
    tmux
  ];
}
