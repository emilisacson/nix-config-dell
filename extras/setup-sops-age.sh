#!/usr/bin/env bash
set -euo pipefail

KEY_DIR="${HOME}/.config/sops/age"
KEY_FILE="${KEY_DIR}/keys.txt"
REPO_ROOT="${HOME}/.nix-config"
SOPS_CONFIG="${REPO_ROOT}/.sops.yaml"

if ! command -v age-keygen >/dev/null 2>&1; then
  echo "age-keygen was not found in PATH."
  echo "Rebuild Home Manager first so the secrets tooling is installed:"
  echo "  cd ~/.nix-config && NIXPKGS_ALLOW_UNFREE=1 nix run --impure \"path:$HOME/.nix-config#homeConfigurations.$USER.activationPackage\""
  exit 1
fi

mkdir -p "$KEY_DIR"
chmod 700 "$KEY_DIR"

if [[ -f "$KEY_FILE" ]]; then
  echo "Using existing age key: $KEY_FILE"
else
  echo "Generating new age key at: $KEY_FILE"
  age-keygen -o "$KEY_FILE"
  chmod 600 "$KEY_FILE"
fi

PUBLIC_KEY="$(age-keygen -y "$KEY_FILE")"

echo
echo "Public age key:"
echo "  $PUBLIC_KEY"
echo

echo "Next steps:"
echo "1. Open ${SOPS_CONFIG}"
echo "2. Replace the empty 'age: []' list with your public key"
echo "3. Create your first encrypted secret file, for example:"
echo "     sops ${REPO_ROOT}/secrets/common.yaml"
echo "4. Commit only encrypted files, never plaintext exports or private keys"
