{ config, pkgs, lib, ... }:

let
  cfg = config.repoFeatures.tailscale;
  yqBin = "${pkgs.yq-go}/bin/yq";
  sudoBin = "/usr/bin/sudo";
  systemctlBin = "/usr/bin/systemctl";
  tailscaleSecretFile = ../secrets/tailscale.yaml;
  hasTailscaleSecretFile = builtins.pathExists tailscaleSecretFile;
  runtimeConfigPath = "%r/tailscale/config.yaml";
in {
  options.repoFeatures.tailscale = {
    enableSystray =
      lib.mkEnableOption "Tailscale systray package and autostart integration";
  };

  config = {
    home.packages = with pkgs;
      [ yq-go ] ++ lib.optionals cfg.enableSystray [ tailscale-systray ];

    sops.secrets = lib.mkIf hasTailscaleSecretFile {
      tailscale-config = {
        sopsFile = tailscaleSecretFile;
        format = "yaml";
        key = "";
        path = runtimeConfigPath;
      };
    };

    home.activation.checkTailscaleSetup =
      lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        echo "Checking Tailscale setup..."
        if ! command -v tailscale >/dev/null 2>&1; then
          echo "⚠️  tailscale CLI is not installed system-wide yet."
          echo "    Run: ~/.nix-config/extras/setup-tailscale.sh"
        fi

        if ! ${systemctlBin} cat tailscaled.service >/dev/null 2>&1; then
          echo "⚠️  tailscaled system service is not installed."
          echo "    Run: ~/.nix-config/extras/setup-tailscale.sh"
        elif ! ${systemctlBin} is-active --quiet tailscaled 2>/dev/null; then
          echo "⚠️  tailscaled is installed but not running."
          echo "    Run: sudo systemctl enable --now tailscaled"
        else
          echo "✅ tailscaled service is active"
          if command -v tailscale >/dev/null 2>&1 && (tailscale ip -4 >/dev/null 2>&1 || tailscale status >/dev/null 2>&1); then
            echo "✅ Tailscale CLI can talk to the daemon"
          else
            echo "⚠️  Tailscale daemon is running, but login status could not be confirmed."
            echo "    Run: tailscale-connect"
          fi
        fi

        if [ -f "${config.home.homeDirectory}/.config/sops/age/keys.txt" ] && [ ! -f "${config.home.homeDirectory}/.nix-config/secrets/tailscale.yaml" ]; then
          echo "ℹ️  No encrypted tailscale.yaml found yet. Interactive login remains the default."
        fi

        if ${lib.boolToString cfg.enableSystray}; then
          echo "ℹ️  Tailscale systray integration is enabled."
        fi
      '';

    home.file.".local/bin/tailscale-status" = {
      executable = true;
      text = ''
        #!/usr/bin/env bash
        set -euo pipefail

        TAILSCALE_BIN="$(command -v tailscale || true)"

        if [[ -z "$TAILSCALE_BIN" ]]; then
          echo "tailscale CLI is not installed system-wide."
          echo "Run: ~/.nix-config/extras/setup-tailscale.sh"
          exit 1
        fi

        echo "== tailscaled service =="
        if ${systemctlBin} cat tailscaled.service >/dev/null 2>&1; then
          ${systemctlBin} --no-pager --full status tailscaled || true
        else
          echo "tailscaled.service is not installed"
        fi

        echo
        echo "== tailscale status =="
        if "$TAILSCALE_BIN" status "$@"; then
          exit 0
        fi

        echo
        echo "Retrying with sudo..."
        exec ${sudoBin} "$TAILSCALE_BIN" status "$@"
      '';
    };

    home.file.".local/bin/tailscale-connect" = {
      executable = true;
      text = ''
        #!/usr/bin/env bash
        set -euo pipefail

        TAILSCALE_BIN="$(command -v tailscale || true)"
        RUNTIME_CONFIG="''${TAILSCALE_CONFIG_FILE:-''${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/tailscale/config.yaml}"
        AUTH_KEY_FILE="''${TAILSCALE_AUTHKEY_FILE:-''${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/tailscale/authkey}"
        declare -a args

        if [[ -z "$TAILSCALE_BIN" ]]; then
          echo "tailscale CLI is not installed system-wide."
          echo "Run: ~/.nix-config/extras/setup-tailscale.sh"
          exit 1
        fi

        add_arg_if_value() {
          local flag="$1"
          local value="$2"
          if [[ -n "$value" && "$value" != "null" ]]; then
            args+=("$flag" "$value")
          fi
        }

        if [[ -f "$RUNTIME_CONFIG" ]]; then
          echo "Loading optional Tailscale defaults from $RUNTIME_CONFIG"

          config_auth_key="$(${yqBin} -r '.authKey // ""' "$RUNTIME_CONFIG")"
          config_hostname="$(${yqBin} -r '.hostname // ""' "$RUNTIME_CONFIG")"
          config_control_url="$(${yqBin} -r '.controlUrl // ""' "$RUNTIME_CONFIG")"
          config_advertise_tags="$(${yqBin} -r '.advertiseTags // ""' "$RUNTIME_CONFIG")"
          config_exit_node="$(${yqBin} -r '.exitNode // ""' "$RUNTIME_CONFIG")"
          config_accept_routes="$(${yqBin} -r '.acceptRoutes // ""' "$RUNTIME_CONFIG")"
          config_extra_up_flags="$(${yqBin} -r '.extraUpFlags // ""' "$RUNTIME_CONFIG")"

          if [[ -n "$config_auth_key" ]]; then
            export TAILSCALE_AUTHKEY="$config_auth_key"
          fi

          add_arg_if_value --hostname "$config_hostname"
          add_arg_if_value --login-server "$config_control_url"
          add_arg_if_value --advertise-tags "$config_advertise_tags"
          add_arg_if_value --exit-node "$config_exit_node"

          if [[ "$config_accept_routes" == "true" ]]; then
            args+=(--accept-routes)
          elif [[ "$config_accept_routes" == "false" ]]; then
            args+=(--accept-routes=false)
          fi

          if [[ -n "$config_extra_up_flags" ]]; then
            # Intentionally split on shell words for advanced opt-in usage.
            # shellcheck disable=SC2206
            extra_flags=( $config_extra_up_flags )
            args+=("''${extra_flags[@]}")
          fi
        fi

        if [[ -n "''${TAILSCALE_AUTHKEY:-}" ]]; then
          echo "Using auth key from TAILSCALE_AUTHKEY"
          args+=(--auth-key "$TAILSCALE_AUTHKEY")
        elif [[ -f "$AUTH_KEY_FILE" ]]; then
          auth_key="$(tr -d '\n' < "$AUTH_KEY_FILE")"
          if [[ -n "$auth_key" ]]; then
            echo "Using auth key from $AUTH_KEY_FILE"
            args+=(--auth-key "$auth_key")
          fi
        else
          echo "No auth key provided; starting interactive login flow"
        fi

        exec ${sudoBin} --preserve-env=TAILSCALE_AUTHKEY,TAILSCALE_AUTHKEY_FILE,XDG_RUNTIME_DIR \
          "$TAILSCALE_BIN" up "''${args[@]}" "$@"
      '';
    };

    home.file.".local/bin/tailscale-disconnect" = {
      executable = true;
      text = ''
        #!/usr/bin/env bash
        set -euo pipefail

        TAILSCALE_BIN="$(command -v tailscale || true)"

        if [[ -z "$TAILSCALE_BIN" ]]; then
          echo "tailscale CLI is not installed system-wide."
          echo "Run: ~/.nix-config/extras/setup-tailscale.sh"
          exit 1
        fi

        exec ${sudoBin} "$TAILSCALE_BIN" down "$@"
      '';
    };

    home.file.".local/bin/tailscale-reauth" = {
      executable = true;
      text = ''
        #!/usr/bin/env bash
        set -euo pipefail

        TAILSCALE_BIN="$(command -v tailscale || true)"

        if [[ -z "$TAILSCALE_BIN" ]]; then
          echo "tailscale CLI is not installed system-wide."
          echo "Run: ~/.nix-config/extras/setup-tailscale.sh"
          exit 1
        fi

        exec ${sudoBin} "$TAILSCALE_BIN" up --force-reauth "$@"
      '';
    };

    home.file.".local/bin/tailscale-ui" = lib.mkIf cfg.enableSystray {
      executable = true;
      text = ''
        #!/usr/bin/env bash
        set -euo pipefail
        exec ${pkgs.tailscale-systray}/bin/tailscale-systray "$@"
      '';
    };

    xdg.desktopEntries.tailscale-systray = lib.mkIf cfg.enableSystray {
      name = "Tailscale Systray";
      exec = "tailscale-ui";
      icon = "tailscale";
      comment = "Start the Tailscale systray client";
      categories = [ "Network" "Utility" ];
      terminal = false;
      startupNotify = false;
    };

    xdg.configFile."autostart/tailscale-systray.desktop" =
      lib.mkIf cfg.enableSystray {
        text = ''
          [Desktop Entry]
          Name=Tailscale Systray
          Exec=tailscale-ui
          Icon=tailscale
          Comment=Start the Tailscale systray client
          Categories=Network;Utility;
          Terminal=false
          StartupNotify=false
          Type=Application
        '';
      };

    home.file.".local/bin/setup-tailscale" = {
      executable = true;
      source = ../extras/setup-tailscale.sh;
    };
  };
}
