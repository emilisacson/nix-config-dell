#!/usr/bin/env bash
# Adds a convenience alias 'nix-vscode-update' to the user's ~/.bashrc if absent.
# This alias wraps the update script for VS Code hashes.

ALIAS_LINE='alias nix-vscode-update="cd ~/.nix-config && ./extras/update-vscode-hash.sh"'
BASHRC="$HOME/.bashrc"

if [[ ! -f "$BASHRC" ]]; then
  echo "[INFO] No existing .bashrc found, creating one." >&2
  touch "$BASHRC"
fi

if grep -Fxq "$ALIAS_LINE" "$BASHRC"; then
  echo "Alias already exists in .bashrc: nix-vscode-update"
else
  echo "$ALIAS_LINE" >> "$BASHRC"
  echo "Alias added. Run: source ~/.bashrc  (or open a new shell)"
fi
