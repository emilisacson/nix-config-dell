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
    # Add nixGL for OpenGL support in non-NixOS systems
    nixgl = {
      url = "github:nix-community/nixGL";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs@{ nixpkgs, nixpkgs-unstable, home-manager, cosmic-manager
    , nixgl, ... }:
    let
      system = "x86_64-linux";
      username = "emil";

      # Configure pkgs with overlays
      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
        overlays = [ nixgl.overlay ];
      };

      unstable = nixpkgs-unstable.legacyPackages.${system};

      # Import system detection module - using the fixed version
      systemDetection =
        import ./lib/system-detection-fixed.nix { lib = nixpkgs.lib; };
    in {
      homeConfigurations.${username} =
        home-manager.lib.homeManagerConfiguration {
          inherit pkgs;
          extraSpecialArgs = {
            inherit inputs unstable nixgl;
            systemConfig = systemDetection;
          };
          modules =
            [ ./home.nix cosmic-manager.homeManagerModules.cosmic-manager ];
        };
    };
}
