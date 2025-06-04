{ config, pkgs, lib, ... }:

let
  # Import extension configurations as attribute sets (not as modules)
  commonExtensionsConfig = import ./common.nix { inherit config lib; };

in {
  # Import the dash-to-panel module directly
  imports = [ ./dash-to-panel.nix ];

  # GNOME Extensions packages
  home.packages = with pkgs; [
    gnomeExtensions.dash-to-panel # For all monitors with configurable positions
    gnomeExtensions.gsconnect # Add GSConnect extension
    gnomeExtensions.tiling-assistant # Advanced window tiling with multi-monitor support
    gnomeExtensions.vitals # System monitor (CPU, memory, temp, etc.)
    gnomeExtensions.caffeine # Prevent screen lock/suspend
    gnomeExtensions.ddterm # Drop-down terminal
    # Note: Custom Command Menu not available in nixpkgs, install manually from extensions.gnome.org
  ];

  # Extension configurations
  dconf.settings = lib.mkMerge [
    # Common extension configurations
    commonExtensionsConfig

    # GNOME Shell Extensions settings - Allow network access and enable extensions
    {
      "org/gnome/shell/extensions" = {
        allowed-extensions = [ "extensions.gnome.org" "localhost" ];
        user-extensions-enabled = true;
      };

      # Extension enablement in GNOME Shell
      "org/gnome/shell" = {
        enabled-extensions = [
          "appindicatorsupport@rgcjonas.gmail.com"
          "caffeine@patapon.info"
          "dash-to-panel@jderose9.github.com" # Add Dash to Panel extension
          "gsconnect@andyholmes.github.io" # Enable GSConnect extension
          "tiling-assistant@leleat-on-github" # Tiling assistant
          "status-icons@gnome-shell-extensions.gcampax.github.com"
          "Vitals@CoreCoding.com" # System monitor with CPU, memory, temperature, etc.
          "ddterm@amezin.github.com" # Drop-down terminal
          # "custom-command-menu@storageb.github.com" # Install manually from extensions.gnome.org
        ];
      };
    }
  ];
}
