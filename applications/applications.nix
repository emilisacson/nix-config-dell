{ pkgs, ... }:

{
  # Import specific application modules
  imports = [ ./citrix.nix ./vscode.nix ./steam.nix ./python.nix ./brave.nix ];

  # Install applications
  home.packages = with pkgs; [
    # Password manager
    keepassxc

    # Email client
    evolution
    evolution-data-server # Backend data service for Evolution
    pkgs.gnome-calendar # Calendar integration with Evolution

    # Microsoft applications and alternatives
    p3x-onenote # OneNote alternative (patrikx3/onenote)
    onedrive # OneDrive client (abraunegg/onedrive)
    teams-for-linux # Microsoft Teams client (IsmaelMartinez/teams-for-linux)

    git
    obsidian
  ];
}
