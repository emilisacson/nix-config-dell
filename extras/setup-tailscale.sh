#!/usr/bin/env bash
set -euo pipefail

TAILSCALE_BIN="$(command -v tailscale || true)"
TAILSCALED_BIN="$(command -v tailscaled || true)"
SYSTEMCTL_BIN="/usr/bin/systemctl"
SYSTEMD_UNIT_PATH="/etc/systemd/system/tailscaled.service"
SYSTEMD_ENV_PATH="/etc/default/tailscaled"

print_next_steps() {
  echo
  echo "Next steps:"
  echo "1. Rebuild Home Manager if you have not already:"
  echo "   cd ~/.nix-config && NIXPKGS_ALLOW_UNFREE=1 nix run --impure \"path:$HOME/.nix-config#homeConfigurations.$USER.activationPackage\""
  echo "2. Run this helper again whenever you want to refresh the systemd service to the latest Nix profile path"
  echo "3. Connect interactively: tailscale-connect"
  echo "4. Check status: tailscale-status"
  echo
  echo "Optional later: provide TAILSCALE_AUTHKEY or TAILSCALE_AUTHKEY_FILE for non-interactive login"
}

write_systemd_env_file() {
  if [[ ! -f "$SYSTEMD_ENV_PATH" ]]; then
    echo "Creating optional tailscaled environment file at $SYSTEMD_ENV_PATH"
    sudo tee "$SYSTEMD_ENV_PATH" >/dev/null <<'EOF'
# Optional tailscaled overrides.
# Examples:
# PORT=41641
# FLAGS=--tun=userspace-networking
PORT=41641
FLAGS=
EOF
  fi
}

write_systemd_unit() {
  local tailscale_path="$1"
  local tailscaled_path="$2"

  echo "Writing $SYSTEMD_UNIT_PATH to use Nix-managed Tailscale binaries..."
  sudo tee "$SYSTEMD_UNIT_PATH" >/dev/null <<EOF
[Unit]
Description=Tailscale node agent
Documentation=https://tailscale.com/kb/
Wants=network-pre.target
After=network-pre.target NetworkManager.service systemd-resolved.service

[Service]
EnvironmentFile=-$SYSTEMD_ENV_PATH
ExecStart=$tailscaled_path --state=/var/lib/tailscale/tailscaled.state --socket=/run/tailscale/tailscaled.sock --port=\${PORT} \$FLAGS
ExecStopPost=$tailscaled_path --cleanup
Restart=on-failure
RuntimeDirectory=tailscale
RuntimeDirectoryMode=0755
StateDirectory=tailscale
StateDirectoryMode=0700
CacheDirectory=tailscale
CacheDirectoryMode=0750
Type=notify

[Install]
WantedBy=multi-user.target
EOF

  echo "Installed service will use:"
  echo "  tailscale:  $tailscale_path"
  echo "  tailscaled: $tailscaled_path"
}

if [[ ! -x "$SYSTEMCTL_BIN" ]]; then
  echo "systemctl was not found at $SYSTEMCTL_BIN"
  exit 1
fi

if [[ -z "$TAILSCALE_BIN" || -z "$TAILSCALED_BIN" ]]; then
  echo "tailscale/tailscaled are not currently available in PATH."
  echo "Rebuild Home Manager first so the Nix-managed Tailscale package is installed:"
  echo "  cd ~/.nix-config && NIXPKGS_ALLOW_UNFREE=1 nix run --impure \"path:$HOME/.nix-config#homeConfigurations.$USER.activationPackage\""
  exit 1
fi

write_systemd_env_file
write_systemd_unit "$TAILSCALE_BIN" "$TAILSCALED_BIN"

echo "Enabling and restarting tailscaled..."
sudo "$SYSTEMCTL_BIN" daemon-reload
sudo "$SYSTEMCTL_BIN" enable tailscaled

if "$SYSTEMCTL_BIN" is-active --quiet tailscaled; then
  sudo "$SYSTEMCTL_BIN" restart tailscaled
else
  sudo "$SYSTEMCTL_BIN" start tailscaled
fi

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
  echo "⚠️  tailscale CLI is still not on PATH. Open a new shell or confirm your Home Manager profile is active."
fi

print_next_steps
