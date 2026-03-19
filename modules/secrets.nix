{ config, pkgs, lib, ... }:

let
  ageKeyDir = "${config.home.homeDirectory}/.config/sops/age";
  ageKeyFile = "${ageKeyDir}/keys.txt";
  repoRoot = "${config.home.homeDirectory}/.nix-config";
in {
  home.packages = with pkgs; [ age sops ssh-to-age ];

  sops.age.keyFile = ageKeyFile;

  home.sessionVariables = { SOPS_AGE_KEY_FILE = ageKeyFile; };

  home.activation.checkSecretsBootstrap =
    lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      echo "Checking secrets manager bootstrap..."
      if [ ! -f "${ageKeyFile}" ]; then
        echo "⚠️  No sops age key found."
        echo "    Run: ~/.nix-config/extras/setup-sops-age.sh"
      else
        echo "✅ sops age key detected at ${ageKeyFile}"
      fi

      if [ ! -f "${repoRoot}/.sops.yaml" ]; then
        echo "⚠️  Missing .sops.yaml in repo root."
      fi
    '';

  home.file.".local/bin/show-sops-age-public-key" = {
    executable = true;
    text = ''
      #!/usr/bin/env bash
      set -euo pipefail

      KEY_FILE="${ageKeyFile}"

      if [[ ! -f "$KEY_FILE" ]]; then
        echo "No age key found at $KEY_FILE"
        echo "Run: ~/.nix-config/extras/setup-sops-age.sh"
        exit 1
      fi

      exec ${pkgs.age}/bin/age-keygen -y "$KEY_FILE"
    '';
  };
}
