{ config, pkgs, lib, ... }:

{
  # Install and configure Brave Browser using chromium module
  programs.chromium = {
    enable = true;
    package = pkgs.brave; # Use Brave as the package
    extensions = [
      "oboonakemofpalcgghocfoadofidjkkk" # KeePassXC-Browser
      "cjpalhdlnbpafiamejdnhcphjbkeiagm" # uBlock Origin
      "nngceckbapebfimnlniiiahkandclblb" # Bitwarden
      "eimadpbcbfnmbkopoojfekhnkhdbieeh" # Dark Reader
      "gphhapmejobijbbhgpjhcjognlahblep" # GNOME Shell Integration
    ];
    commandLineArgs = [
      "--enable-features=VaapiVideoDecoder,VaapiVideoEncoder,ExtensionServiceMaybeAllowManagement"
      "--disable-features=UseChromeOSDirectVideoDecoder"
      "--force-dark-mode"
      "--auth-server-whitelist='*'"
    ];
  };

  # Configure Brave as the default browser
  xdg.mimeApps = {
    enable = true;
    defaultApplications = {
      "text/html" = [ "brave-browser.desktop" ];
      "x-scheme-handler/http" = [ "brave-browser.desktop" ];
      "x-scheme-handler/https" = [ "brave-browser.desktop" ];
      "x-scheme-handler/about" = [ "brave-browser.desktop" ];
      "x-scheme-handler/unknown" = [ "brave-browser.desktop" ];
    };
  };

  # Create a policy directory with extension force-install policy
  home.file.".config/BraveSoftware/Brave-Browser/policies/managed/extensions_policy.json".text =
    builtins.toJSON {
      ExtensionSettings = {
        "oboonakemofpalcgghocfoadofidjkkk" = {
          installation_mode = "force_installed";
          update_url = "https://clients2.google.com/service/update2/crx";
        };
        "cjpalhdlnbpafiamejdnhcphjbkeiagm" = {
          installation_mode = "force_installed";
          update_url = "https://clients2.google.com/service/update2/crx";
        };
        "nngceckbapebfimnlniiiahkandclblb" = {
          installation_mode = "force_installed";
          update_url = "https://clients2.google.com/service/update2/crx";
        };
        "eimadpbcbfnmbkopoojfekhnkhdbieeh" = {
          installation_mode = "force_installed";
          update_url = "https://clients2.google.com/service/update2/crx";
        };
        "gphhapmejobijbbhgpjhcjognlahblep" = {
          installation_mode = "force_installed";
          update_url = "https://clients2.google.com/service/update2/crx";
        };
      };
    };

  # Make sure the policies directory exists and is properly set up
  home.activation.ensureBravePolicies =
    lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      $DRY_RUN_CMD mkdir -p $VERBOSE_ARG ~/.config/BraveSoftware/Brave-Browser/policies/managed
    '';
}
