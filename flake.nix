{
  description = "Home Manager configuration of Emil Isacson";

  inputs = {
    # Specify the source of Home Manager and Nixpkgs.
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/master";

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
  };

  outputs =
    inputs@{ nixpkgs, nixpkgs-unstable, home-manager, cosmic-manager, ... }:
    let
      system = "x86_64-linux";
      username = "emil";
      
      # Configure pkgs with overlays
      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };
      
      unstable = nixpkgs-unstable.legacyPackages.${system};
    in {
      homeConfigurations.${username} =
        home-manager.lib.homeManagerConfiguration {
          inherit pkgs;
          extraSpecialArgs = { inherit inputs unstable; };
          modules =
            [ ./home.nix cosmic-manager.homeManagerModules.cosmic-manager ];
        };
    };
}
