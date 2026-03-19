#!/usr/bin/env bash

ALIAS_LINE='alias nix-home-rebuild="cd ~/.nix-config && NIXPKGS_ALLOW_UNFREE=1 nix run --impure \"path:$HOME/.nix-config#homeConfigurations.$USER.activationPackage\""'
BASHRC="$HOME/.bashrc"

# Check if alias already exists
if grep -Fxq "$ALIAS_LINE" "$BASHRC"; then
  echo "Alias already exists in .bashrc."
elif grep -Eq '^alias nix-home-rebuild=' "$BASHRC"; then
  sed -i "s|^alias nix-home-rebuild=.*$|$ALIAS_LINE|" "$BASHRC"
  echo "Updated existing nix-home-rebuild alias in .bashrc. Run 'source ~/.bashrc' or restart the terminal."
else
  echo "$ALIAS_LINE" >> "$BASHRC"
  echo "Alias added to .bashrc. Run 'source ~/.bashrc' or restart the terminal."
fi