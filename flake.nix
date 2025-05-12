{
  description = "Home Manager configuration of Emil Isacson";

  inputs = {
    # Specify the source of Home Manager and Nixpkgs.
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    cosmic-manager = {
      url = "github:HeitorAugustoLN/cosmic-manager";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        home-manager.follows = "home-manager";
      };
    };
    #nix-vscode-extensions.url = "github:nix-community/nix-vscode-extensions/00e11463876a04a77fb97ba50c015ab9e5bee90d";
  };

  outputs = inputs@{ nixpkgs, home-manager, cosmic-manager, ... }:
    let
      system = "x86_64-linux";
      username = "emil";
      pkgs = nixpkgs.legacyPackages.${system};
      #allowed-unfree-packages = [
      #  "vscode-extension-github-copilot"
      #];
      #nix-vscode-extensions = import (
      #  builtins.fetchGit {
      #    url = "https://github.com/nix-community/nix-vscode-extensions";
      #    ref = "refs/heads/master";
      #    rev = "00e11463876a04a77fb97ba50c015ab9e5bee90d";
      #  }
      #);
    in
    {
      homeConfigurations.${username} = home-manager.lib.homeManagerConfiguration {
        inherit pkgs;
        extraSpecialArgs = { inherit inputs; };
        modules = [
          ./home.nix
          cosmic-manager.homeManagerModules.cosmic-manager
        ];
      };
    };
}
