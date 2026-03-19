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
    nix-flatpak = {
      url = "github:gmodena/nix-flatpak/?ref=latest";
    };
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # Add nixGL for OpenGL support in non-NixOS systems
    nixgl = {
      url = "github:nix-community/nixGL";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    inputs@{
      nixpkgs,
      nixpkgs-unstable,
      home-manager,
      cosmic-manager,
      nix-flatpak,
      sops-nix,
      nixgl,
      ...
    }:
    let
      system = "x86_64-linux";
      username = "emil";
      nixglOverlay =
        final: _prev:
        let
          isIntelX86Platform = final.stdenv.hostPlatform.system == "x86_64-linux";
        in
        {
          nixgl = import "${nixgl.outPath}/default.nix" {
            pkgs = final;
            enable32bits = isIntelX86Platform;
            enableIntelX86Extensions = isIntelX86Platform;
          };
        };

      # Configure pkgs with overlays
      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
        overlays = [ nixglOverlay ];
      };

      unstable = nixpkgs-unstable.legacyPackages.${system};
    in
    {
      homeConfigurations.${username} = home-manager.lib.homeManagerConfiguration {
        inherit pkgs;
        extraSpecialArgs = { inherit inputs unstable nixgl; };
        modules = [
          sops-nix.homeManagerModules.sops
          ./home.nix
          cosmic-manager.homeManagerModules.cosmic-manager
          nix-flatpak.homeManagerModules.nix-flatpak
        ];
      };
    };
}
