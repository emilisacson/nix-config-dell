#!/usr/bin/env bash

ALIAS_LINE='alias nix-home-rebuild="cd ~/.nix-config && NIXPKGS_ALLOW_UNFREE=1 nix run --impure .#homeConfigurations.$USER.activationPackage"'
BASHRC="$HOME/.bashrc"

# Check if alias already exists
if ! grep -Fxq "$ALIAS_LINE" "$BASHRC"; then
  echo "$ALIAS_LINE" >> "$BASHRC"
  echo "Alias added to .bashrc. Run 'source ~/.bashrc' or restart the terminal."
else
  echo "Alias already exists in .bashrc."
fi