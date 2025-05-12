{ config, pkgs, inputs, ... }:

{
  home.username = "emil";
  home.homeDirectory = "/home/emil";

  home.stateVersion = "24.11";

  programs.home-manager.enable = true;

  xdg.enable = true;

  # nixpkgs.config.allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) [
  #   "vscode"
  # ];

  nixpkgs.config.allowUnfreePredicate = _: true;

  home.packages = with pkgs; [
    git
    vscode
    brave
  ];

  imports = [
    inputs.cosmic-manager.homeManagerModules.default
    ./applications/vscode.nix
  ];

  programs.cosmic-manager.enable = true;

/*   programs.cosmic-manager.settings = {
    wayland.desktopManager.cosmic.applets.time.settings = {
      millitary_time = true;
      show_seconds = true;
    };

    wayland.desktopManager.cosmic.applets.calendar.settings = {
      week_start = "monday";
    };
  }; */
}