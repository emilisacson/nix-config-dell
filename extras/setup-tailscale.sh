#!/usr/bin/env bash
set -euo pipefail

TAILSCALED_BIN="$(command -v tailscaled || true)"
SYSTEMCTL_BIN="/usr/bin/systemctl"
DNF_BIN="/usr/bin/dnf"
REPO_FILE_URL="https://pkgs.tailscale.com/stable/fedora/tailscale.repo"
REPO_FILE_PATH="/etc/yum.repos.d/tailscale.repo"

print_next_steps() {
  echo
  echo "Next steps:"
  echo "1. Rebuild Home Manager if you have not already:"
  echo "   cd ~/.nix-config && NIXPKGS_ALLOW_UNFREE=1 nix run --impure \"path:$HOME/.nix-config#homeConfigurations.$USER.activationPackage\""
  echo "2. Connect interactively: tailscale-connect"
  echo "3. Check status: tailscale-status"
  echo
  echo "Optional later: provide TAILSCALE_AUTHKEY or TAILSCALE_AUTHKEY_FILE for non-interactive login"
}

ensure_tailscale_repo() {
  if [[ -f "$REPO_FILE_PATH" ]]; then
    return 0
  fi

  echo "Adding the official Tailscale Fedora repository..."

  if command -v curl >/dev/null 2>&1; then
    sudo curl -fsSL "$REPO_FILE_URL" -o "$REPO_FILE_PATH"
  elif command -v wget >/dev/null 2>&1; then
    sudo wget -qO "$REPO_FILE_PATH" "$REPO_FILE_URL"
  else
    echo "Neither curl nor wget is available to install the Tailscale repo file automatically."
    echo "Please install one of them or add the repo manually: $REPO_FILE_URL"
    exit 1
  fi
}

if [[ ! -x "$SYSTEMCTL_BIN" ]]; then
  echo "systemctl was not found at $SYSTEMCTL_BIN"
  exit 1
fi

if [[ -z "$TAILSCALED_BIN" ]]; then
  echo "tailscaled is not installed system-wide."

  if [[ -x "$DNF_BIN" ]]; then
    echo "Attempting to install tailscale via dnf..."
    if ! sudo "$DNF_BIN" install -y tailscale; then
      ensure_tailscale_repo
      echo "Retrying tailscale installation after adding the official repo..."

      if ! sudo "$DNF_BIN" install -y tailscale; then
        echo
        echo "Automatic installation failed."
        echo "Install the Tailscale package system-wide and rerun this script."
        exit 1
      fi
    fi
  else
    echo "dnf was not found. Install the Tailscale package system-wide, then rerun this script."
    exit 1
  fi
fi

echo "Enabling and starting tailscaled..."
sudo "$SYSTEMCTL_BIN" enable --now tailscaled

if "$SYSTEMCTL_BIN" is-active --quiet tailscaled; then
  echo "✅ tailscaled is active"
else
  echo "❌ tailscaled did not start correctly"
  sudo "$SYSTEMCTL_BIN" --no-pager --full status tailscaled || true
  exit 1
fi

if command -v tailscale >/dev/null 2>&1; then
  echo "✅ tailscale CLI is available"
else
  echo "⚠️  tailscale CLI is still not on PATH. Open a new shell or confirm the system package installed correctly."
fi

print_next_steps
