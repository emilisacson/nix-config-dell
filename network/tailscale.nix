{
  config,
  pkgs,
  lib,
  ...
}:

let
  cfg = config.repoFeatures.tailscale;
  yqBin = "${pkgs.yq-go}/bin/yq";
  sudoBin = "/usr/bin/sudo";
  systemctlBin = "/usr/bin/systemctl";
  pythonBin = "/usr/bin/python3";
  nmcliBin = "/usr/bin/nmcli";
  tailscaleBin = "${pkgs.tailscale}/bin/tailscale";
  tailscaleSecretFile = ../secrets/tailscale.yaml;
  hasTailscaleSecretFile = builtins.pathExists tailscaleSecretFile;
  runtimeConfigPath = "%r/tailscale/config.yaml";
  shellArray = values: lib.concatMapStringsSep " " lib.escapeShellArg values;
in
{
  options.repoFeatures.tailscale = {
    enableSystray = lib.mkEnableOption "Tailscale systray package and autostart integration";
    autoToggle = {
      enable = lib.mkEnableOption "automatic Tailscale down on home networks and up elsewhere via NetworkManager events";
      homeConnectionNames = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        example = [ "Crynet_5G" ];
        description = "Active NetworkManager connection names that should be treated as home/trusted networks.";
      };
      homeSsids = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        example = [ "Crynet_5G" ];
        description = "Wi-Fi SSIDs that should cause automatic Tailscale disconnect.";
      };
      homeGateways = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        example = [ "192.168.2.1" ];
        description = "Default gateway IPv4 addresses that should be treated as home/trusted networks.";
      };
    };
  };

  config = {
    home.packages =
      with pkgs;
      [
        tailscale
        yq-go
      ]
      ++ lib.optionals cfg.enableSystray [ tailscale-systray ];

    sops.secrets = lib.mkIf hasTailscaleSecretFile {
      tailscale-config = {
        sopsFile = tailscaleSecretFile;
        format = "yaml";
        key = "";
        path = runtimeConfigPath;
      };
    };

    home.activation.checkTailscaleSetup = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      echo "Checking Tailscale setup..."
      if [ -x "${tailscaleBin}" ]; then
        echo "✅ Nix-managed tailscale package is configured"
      else
        echo "⚠️  Nix-managed tailscale package could not be found in the store."
      fi

      if ! ${systemctlBin} cat tailscaled.service >/dev/null 2>&1; then
        echo "⚠️  tailscaled system service is not installed."
        echo "    Run: ~/.nix-config/extras/setup-tailscale.sh"
      elif ! ${systemctlBin} is-active --quiet tailscaled 2>/dev/null; then
        echo "⚠️  tailscaled is installed but not running."
        echo "    Run: sudo systemctl enable --now tailscaled"
      else
        tailnet_status_output="$(${tailscaleBin} status 2>&1 || true)"
        echo "✅ tailscaled service is active"
        if ${tailscaleBin} ip -4 >/dev/null 2>&1 || ${tailscaleBin} ip -6 >/dev/null 2>&1; then
          echo "✅ Tailscale CLI can talk to the daemon"
        elif printf '%s\n' "$tailnet_status_output" | grep -q "Tailscale is stopped"; then
          if ${lib.boolToString cfg.autoToggle.enable}; then
            echo "ℹ️  Tailscale is currently stopped. That is expected while automatic home-network switching keeps it down on trusted networks."
          else
            echo "ℹ️  Tailscale is currently stopped. Run: tailscale-connect"
          fi
        elif printf '%s\n' "$tailnet_status_output" | grep -Eqi "(needs login|logged out|run 'tailscale up' to log in|machine is unauthorized)"; then
          echo "ℹ️  Tailscale daemon is running but this machine is not logged in yet."
          echo "    Run: tailscale-connect"
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
        echo "ℹ️  If you just enabled it, log out and back in once so GNOME reloads the AppIndicator extension and autostart entry."
      fi

      if ${lib.boolToString cfg.autoToggle.enable}; then
        if [ -x "/etc/NetworkManager/dispatcher.d/90-tailscale-auto-toggle" ]; then
          echo "ℹ️  Automatic Tailscale home-network switching is enabled."
        else
          echo "⚠️  Automatic Tailscale home-network switching is configured but not installed yet."
          echo "    Run: ~/.nix-config/extras/setup-tailscale.sh"
        fi

        if [ ${toString (builtins.length cfg.autoToggle.homeConnectionNames)} -eq 0 ] \
          && [ ${toString (builtins.length cfg.autoToggle.homeSsids)} -eq 0 ] \
          && [ ${toString (builtins.length cfg.autoToggle.homeGateways)} -eq 0 ]; then
          echo "⚠️  Automatic Tailscale switching is enabled, but no home-network match rules are configured."
        fi
      fi
    '';

    home.file.".local/bin/tailscale-status" = {
      executable = true;
      text = ''
        #!/usr/bin/env bash
        set -euo pipefail

        TAILSCALE_BIN="$(command -v tailscale || true)"

        if [[ -z "$TAILSCALE_BIN" ]]; then
          echo "tailscale is not installed in your Home Manager profile."
          echo "Rebuild Home Manager first."
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
          echo "tailscale is not installed in your Home Manager profile."
          echo "Rebuild Home Manager first."
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
          echo "tailscale is not installed in your Home Manager profile."
          echo "Rebuild Home Manager first."
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
          echo "tailscale is not installed in your Home Manager profile."
          echo "Rebuild Home Manager first."
          exit 1
        fi

        exec ${sudoBin} "$TAILSCALE_BIN" up --force-reauth "$@"
      '';
    };

    home.file.".local/bin/tailscale-auto-toggle" = lib.mkIf cfg.autoToggle.enable {
      executable = true;
      text = ''
        #!/usr/bin/env bash
        set -euo pipefail
        PATH=/usr/sbin:/usr/bin:/sbin:/bin

        readonly TAILSCALE_BIN="${tailscaleBin}"
        readonly SYSTEMCTL_BIN="${systemctlBin}"
        readonly NMCLI_BIN="${nmcliBin}"
        readonly PYTHON_BIN="${pythonBin}"
        HOME_CONNECTIONS=(${shellArray cfg.autoToggle.homeConnectionNames})
        HOME_SSIDS=(${shellArray cfg.autoToggle.homeSsids})
        HOME_GATEWAYS=(${shellArray cfg.autoToggle.homeGateways})

        log() {
          local message="$1"
          if command -v logger >/dev/null 2>&1; then
            logger -t tailscale-auto-toggle -- "$message"
          fi
          echo "$message"
        }

        contains() {
          local needle="$1"
          shift || true
          local item
          for item in "$@"; do
            if [[ "$item" == "$needle" ]]; then
              return 0
            fi
          done
          return 1
        }

        primary_device() {
          ip route show default 2>/dev/null | awk '/^default/ { print $5; exit }'
        }

        default_gateway() {
          ip route show default 2>/dev/null | awk '/^default/ { print $3; exit }'
        }

        connection_name() {
          local device="$1"
          if [[ -z "$device" ]]; then
            return 0
          fi

          "$NMCLI_BIN" -t -f DEVICE,CONNECTION device status 2>/dev/null \
            | awk -F: -v dev="$device" '$1 == dev { print $2; exit }'
        }

        active_ssid() {
          "$NMCLI_BIN" -t -f ACTIVE,SSID dev wifi 2>/dev/null \
            | awk -F: '$1 == "yes" { print substr($0, 5); exit }'
        }

        backend_state() {
          if [[ ! -x "$PYTHON_BIN" ]]; then
            return 0
          fi

          "$TAILSCALE_BIN" status --json 2>/dev/null | "$PYTHON_BIN" -c 'import json,sys; data=sys.stdin.read().strip(); print(json.loads(data).get("BackendState", "") if data else "")' 2>/dev/null || true
        }

        action="''${2:-}"
        case "$action" in
          ""|up|down|dhcp4-change|dhcp6-change|connectivity-change|reapply|vpn-up|vpn-down)
            ;;
          *)
            exit 0
            ;;
        esac

        if [[ ! -x "$TAILSCALE_BIN" ]]; then
          log "Automatic toggle skipped: tailscale binary not available at $TAILSCALE_BIN"
          exit 0
        fi

        if [[ ! -x "$NMCLI_BIN" ]]; then
          log "Automatic toggle skipped: nmcli not available at $NMCLI_BIN"
          exit 0
        fi

        if ! "$SYSTEMCTL_BIN" is-active --quiet tailscaled 2>/dev/null; then
          log "Automatic toggle skipped: tailscaled is not active"
          exit 0
        fi

        if [[ "''${#HOME_CONNECTIONS[@]}" -eq 0 && "''${#HOME_SSIDS[@]}" -eq 0 && "''${#HOME_GATEWAYS[@]}" -eq 0 ]]; then
          log "Automatic toggle skipped: no home-network match rules configured"
          exit 0
        fi

        device="$(primary_device)"
        gateway="$(default_gateway)"
        connection="$(connection_name "$device")"
        ssid="$(active_ssid)"
        match=""

        if [[ -n "$connection" ]] && contains "$connection" "''${HOME_CONNECTIONS[@]}"; then
          match="connection:$connection"
        elif [[ -n "$ssid" ]] && contains "$ssid" "''${HOME_SSIDS[@]}"; then
          match="ssid:$ssid"
        elif [[ -n "$gateway" ]] && contains "$gateway" "''${HOME_GATEWAYS[@]}"; then
          match="gateway:$gateway"
        fi

        connected=0
        if "$TAILSCALE_BIN" ip -4 >/dev/null 2>&1 || "$TAILSCALE_BIN" ip -6 >/dev/null 2>&1; then
          connected=1
        fi

        if [[ -n "$match" ]]; then
          if [[ "$connected" -eq 1 ]]; then
            log "Home network detected via $match on ''${device:-unknown}; bringing Tailscale down"
            if ! "$TAILSCALE_BIN" down >/dev/null 2>&1; then
              log "Automatic tailscale down failed; check tailscale-status"
            fi
          fi
          exit 0
        fi

        if [[ "$connected" -eq 1 ]]; then
          exit 0
        fi

        state="$(backend_state)"
        case "$state" in
          NeedsLogin|NoState)
            log "Away network detected, but Tailscale needs login first; skipping automatic up"
            exit 0
            ;;
        esac

        log "Away network detected on ''${device:-unknown} (connection=''${connection:-none}, gateway=''${gateway:-none}); bringing Tailscale up"
        if ! "$TAILSCALE_BIN" up >/dev/null 2>&1; then
          log "Automatic tailscale up failed; run tailscale-connect if reauthentication is needed"
        fi
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
      exec = "${pkgs.tailscale-systray}/bin/tailscale-systray";
      icon = "tailscale";
      comment = "Start the Tailscale systray client";
      categories = [
        "Network"
        "Utility"
      ];
      terminal = false;
      startupNotify = false;
    };

    xdg.configFile."autostart/tailscale-systray.desktop" = lib.mkIf cfg.enableSystray {
      text = ''
        [Desktop Entry]
        Name=Tailscale Systray
        Exec=${pkgs.tailscale-systray}/bin/tailscale-systray
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
