{
  config,
  pkgs,
  lib,
  ...
}:

let
  ageKeyDir = "${config.home.homeDirectory}/.config/sops/age";
  ageKeyFile = "${ageKeyDir}/keys.txt";
  repoRoot = "${config.home.homeDirectory}/.nix-config";
  repoSecretsDir = ../secrets;
  repoSecretEntries =
    if builtins.pathExists repoSecretsDir then
      builtins.attrNames (builtins.readDir repoSecretsDir)
    else
      [ ];
  relevantSecretEntries = builtins.filter (
    name:
    !(builtins.elem name [
      "README.md"
      ".gitkeep"
    ])
  ) repoSecretEntries;
  hasEncryptedSecrets = relevantSecretEntries != [ ];
in
{
  home.packages = with pkgs; [
    age
    sops
    ssh-to-age
  ];

  sops.age.keyFile = ageKeyFile;

  home.sessionVariables = {
    SOPS_AGE_KEY_FILE = ageKeyFile;
  };

  home.activation.checkSecretsBootstrap = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    echo "Checking secrets manager bootstrap..."
    if [ ! -f "${ageKeyFile}" ]; then
      if ${lib.boolToString hasEncryptedSecrets}; then
        echo "⚠️  No sops age key found, but encrypted repo secrets are present."
        echo "    Run: ~/.nix-config/extras/setup-sops-age.sh"
      else
        echo "ℹ️  No sops age key found yet. That is fine until you start using encrypted repo secrets."
      fi
    else
      echo "✅ sops age key detected at ${ageKeyFile}"
    fi

    if [ ! -f "${repoRoot}/.sops.yaml" ]; then
      if ${lib.boolToString hasEncryptedSecrets}; then
        echo "⚠️  Missing .sops.yaml in repo root while encrypted secrets are present."
      else
        echo "ℹ️  No .sops.yaml in repo root yet."
      fi
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
