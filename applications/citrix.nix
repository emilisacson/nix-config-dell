{ config, pkgs, lib, ... }:

{
  # Create an overlay to customize the Citrix Workspace package
  nixpkgs.overlays = [
    (final: prev: {
      citrix_workspace = prev.citrix_workspace.overrideAttrs (attrs: {
        version = "24.11.0.85";
        src = final.stdenv.mkDerivation {
          name = "linuxx64-24.11.0.85.tar.gz";
          outputHash = "0kylvqdzkw0635mbb6r5k1lamdjf1hr9pk5rxcff63z4f8q0g3zf";
          outputHashAlgo = "sha256";
          outputHashMode = "flat";
          allowSubstitutes = true;
          builder = builtins.toFile "builder.sh" ''
            source $stdenv/setup
            cp ${config.home.homeDirectory}/Downloads/linuxx64-24.11.0.85.tar.gz $out
          '';
        };
        
        # Add dependencies for GTK modules
        buildInputs = (attrs.buildInputs or []) ++ [
          final.libcanberra-gtk3
          final.packagekit
        ];
        
        # Modify the wrapper to include the GTK modules path
        installPhase = (attrs.installPhase or "") + ''
          # Make sure the GTK modules are available
          for f in $out/bin/*; do
            if [ -x "$f" ]; then
              wrapProgram "$f" \
                --set GTK_PATH "${final.libcanberra-gtk3}/lib/gtk-3.0:${final.packagekit}/lib/gtk-3.0:$GTK_PATH" \
                --prefix XDG_DATA_DIRS : "${final.libcanberra-gtk3}/share:${final.packagekit}/share:$XDG_DATA_DIRS"
            fi
          done
        '';
      });
    })
  ];

  # Install the modified Citrix Workspace package
  home.packages = with pkgs; [
    citrix_workspace
    # Include additional packages that provide the missing GTK modules
    libcanberra-gtk3
    packagekit
  ];

  # Create an alias for easier access
  home.shellAliases = {
    "citrix-workspace" = "selfservice";
  };
}