{ config, pkgs, lib, ... }:

# Minimal WinApps (KVM) style integration for the pure QEMU Windows VM used in this config.
# This module does NOT attempt full automatic app discovery. It provides:
#  - RDP client dependencies (FreeRDP)
#  - A generic wrapper script `winapp-run` to launch a RemoteApp in the Windows VM
#  - A helper `winapps-notepad-register` showing how to create a desktop entry
#  - A desktop entry example for Windows Notepad (can be duplicated for more apps)
#
# Prerequisites inside the Windows guest:
#  1. Enable RDP (System Properties -> Remote -> Allow connections...) or via PowerShell:
#       Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server' -Name 'fDenyTSConnections' -Value 0
#       Enable-NetFirewallRule -DisplayGroup "Remote Desktop"
#  2. (Optional) Set a static password for the user you'll authenticate as.
#  3. (Optional) For better performance enable H.264 / AVC444 in group policy.
#
# Host usage:
#  1. Start VM with RDP forwarding (default now): start-windows-vm
#     - Host port defaults to 33890 (set WIN_RDP_PORT to change)
#  2. Run: winapp-run "||notepad" (RemoteApp ID examples often start with ||)
#  3. Create additional desktop entries by copying the notepad example.

let
  cfg = config.programs.winapps;
  rdpPortStr = toString cfg.rdpPort;
  defaultUserStr = if cfg.defaultUser == null then "" else cfg.defaultUser;
  defaultDomainStr = if cfg.domain == null then "" else cfg.domain;

  # Provide a derivation for documentation (optional) or future expansion.
  # Provide a text file that we install via home.file rather than home.packages
  winappsDocs = pkgs.writeText "winapps-host-readme.txt" ''
    WinApps (minimal) integration
    =============================
    RemoteApp launch syntax example:
      winapp-run "||notepad"
      winapp-run "||calc"

    To create a desktop entry, either configure programs.winapps.apps in Nix or copy an existing one.

    Environment variables affecting winapp-run:
      WIN_RDP_PORT        Host port forwarded to guest 3389 (default 33890 or config.programs.winapps.rdpPort)
      WIN_RDP_HOST        Host (default 127.0.0.1)
      WIN_RDP_USER        Username (overrides configured defaultUser)
      WIN_RDP_DOMAIN      Domain prefix (overrides configured domain)
      WIN_RDP_PASSWORD    Password (UNSAFE to export; prefer interactive prompt)
      WIN_RDP_GEOMETRY    e.g. 1920x1080 (forces size, else dynamic-resolution)
  '';

  winappRun = pkgs.writeShellScriptBin "winapp-run" (let
    rdp = rdpPortStr;
    du = defaultUserStr;
    dd = defaultDomainStr;
  in ''
      #!/usr/bin/env bash
      set -euo pipefail
      APP_ID=""
      EXTRA_ARGS=()
      while [ $# -gt 0 ]; do
        case "$1" in
          --remote-app)
            APP_ID="$2"; shift 2 ;;
          --remote-app=*)
            APP_ID="''${1#*=}"; shift ;;
          --)
            shift
            while [ $# -gt 0 ]; do EXTRA_ARGS+=("$1"); shift; done
            break ;;
          *)
            APP_ID="$1"; shift
            while [ $# -gt 0 ]; do EXTRA_ARGS+=("$1"); shift; done
            break ;;
        esac
      done
      if [ -z "$APP_ID" ]; then
        echo "Usage: winapp-run [--remote-app <id>|<id>] [-- <extra FreeRDP args>]" >&2
        echo "Examples: winapp-run notepad   |   winapp-run --remote-app calc" >&2
        exit 1
      fi
      # Determine if argument represents an alias (||alias) or a program path/name.
      # Heuristic:
      #  - If starts with || => alias (leave as-is)
      #  - Else if no slash and no dot extension and no spaces -> treat as short alias and prefix ||
      #  - Else treat as program path (no modification)
      if [[ "$APP_ID" == \|\|* ]]; then
        : # already alias
      elif [[ "$APP_ID" != */* && "$APP_ID" != *.* && "$APP_ID" != *' '* ]]; then
        APP_ID="||$APP_ID"
      fi

      if [[ "$APP_ID" == \|\|* ]]; then
        APP_FLAG="/app:''${APP_ID}"
      else
        APP_FLAG="/app:program:''${APP_ID}"
      fi

      # Defaults from Nix config
      DEFAULT_RDP_PORT='${rdp}'
      DEFAULT_USER='${du}'
      DEFAULT_DOMAIN='${dd}'

      # Environment overrides
      HOST="''${WIN_RDP_HOST:-127.0.0.1}"
      PORT="''${WIN_RDP_PORT:-$DEFAULT_RDP_PORT}"
      USER="''${WIN_RDP_USER:-$DEFAULT_USER}"      # If empty we'll prompt
      DOMAIN="''${WIN_RDP_DOMAIN:-$DEFAULT_DOMAIN}"
      PASS="''${WIN_RDP_PASSWORD:-}"               # Prompt if empty
      GEOM="''${WIN_RDP_GEOMETRY:-}"               # Optional forced geometry

      if ! command -v ${pkgs.freerdp}/bin/xfreerdp >/dev/null 2>&1; then
        echo "xfreerdp not in PATH" >&2
        exit 1
      fi

      if ! ss -ltn 2>/dev/null | grep -q ":$PORT "; then
        echo "⚠️  Host port $PORT not currently listening. Ensure 'start-windows-vm' is running with RDP forwarding." >&2
      fi

      if [ -z "''${USER}" ]; then
        read -rp "Windows Username: " USER
      fi
      if [ -z "''${PASS}" ]; then
        read -rs -p "Password for ''${USER}: " PASS; echo
      fi

      UPARAM="''${USER}"
      if [ -n "''${DOMAIN}" ]; then
        UPARAM="''${DOMAIN}\\''${USER}"
      fi

      # Source legacy winapps.conf if present for compatibility (RDP_USER, RDP_PASS, RDP_DOMAIN, RDP_SCALE, RDP_FLAGS)
      CONF_FILE="$HOME/.config/winapps/winapps.conf"
      if [ -f "$CONF_FILE" ]; then
        # shellcheck disable=SC1090
        source "$CONF_FILE" || true
  if [ -n "''${RDP_USER:-}" ] && [ -z "''${WIN_RDP_USER}" ]; then USER="''${RDP_USER}"; fi
  if [ -n "''${RDP_PASS:-}" ] && [ -z "''${PASS}" ]; then PASS="''${RDP_PASS}"; fi
  if [ -n "''${RDP_DOMAIN:-}" ] && [ -z "''${DOMAIN}" ]; then DOMAIN="''${RDP_DOMAIN}"; fi
  if [ -n "''${RDP_SCALE:-}" ] && [ -z "''${GEOM}" ]; then SCALE="''${RDP_SCALE}"; fi
  if [ -n "''${RDP_FLAGS:-}" ]; then LEGACY_EXTRA="''${RDP_FLAGS}"; fi
      fi

      # Apply scale if provided via Nix option or config; prefer explicit geometry if set.
      SCALE_OPTION='${toString cfg.scale}'
      if [ -z "''${GEOM}" ] && [ "${toString cfg.scale}" != "null" ]; then
        FREERDP_SCALE="/scale:${toString cfg.scale}"
      elif [ -z "''${GEOM}" ] && [ -n "''${RDP_SCALE:-}" ]; then
        FREERDP_SCALE="/scale:''${RDP_SCALE}"
      else
        FREERDP_SCALE=""
      fi

      # Build graphics capability flags based on FreeRDP version support.
      # We parse --help output once (fast) and decide which /gfx modifiers to use.
      GFX_BASE="/gfx"
      GFX_OPT="" # e.g. "/gfx:AVC444" or just "/gfx"
      if ${pkgs.freerdp}/bin/xfreerdp --help 2>&1 | grep -q 'AVC444'; then
        # Prefer AVC444 (best quality) if advertised.
        GFX_OPT="/gfx:AVC444"
      elif ${pkgs.freerdp}/bin/xfreerdp --help 2>&1 | grep -q 'AVC420'; then
        GFX_OPT="/gfx:AVC420"
      else
        GFX_OPT="/gfx" # Basic RDP8 pipeline
      fi

      FREERDP_ARGS=(
        "/v:''${HOST}:''${PORT}"
        "/u:''${UPARAM}"
        "/p:''${PASS}"
  "''${APP_FLAG}"
        "/floatbar:sticky:off,show:always"
        "/dynamic-resolution"
    "''${GFX_OPT}"
        "+clipboard"
        "/cert:ignore"
        "+compression"
        "/log-level:INFO"
      )

      if [ -n "''${FREERDP_SCALE}" ]; then
        FREERDP_ARGS+=("''${FREERDP_SCALE}")
      fi

      if [ -n "''${GEOM}" ]; then
        FREERDP_ARGS+=("/size:''${GEOM}")
      fi

      if [ ''${#EXTRA_ARGS[@]} -gt 0 ]; then
        # Append any remaining extra args passed after --
        FREERDP_ARGS+=("''${EXTRA_ARGS[@]}")
      fi

      # Append Nix configured extraFlags
      # shellcheck disable=SC2086
      FREERDP_ARGS+=( ${lib.concatStringsSep " " (map (f: lib.escapeShellArg f) cfg.extraFlags)} )
      # Append legacy extra flags string if any
  if [ -n "''${LEGACY_EXTRA:-}" ]; then
        # naive split: rely on word splitting intentionally for legacy style
        # shellcheck disable=SC2206
  LEGACY_ARR=( ''${LEGACY_EXTRA} )
  FREERDP_ARGS+=("''${LEGACY_ARR[@]}")
      fi
  TMP_LOG=$(mktemp -t winapp-run.XXXXXX.log)
  set +e
  ${pkgs.freerdp}/bin/xfreerdp "''${FREERDP_ARGS[@]}" > >(tee "$TMP_LOG") 2>&1
  STATUS=$?
  set -e
      if [ $STATUS -ne 0 ] && [ $STATUS -ne 131 ]; then
        if grep -qi 'RAIL exec error' "$TMP_LOG"; then
          if [ "${toString cfg.fallbackDesktop}" = "true" ]; then
            echo "RemoteApp failed (RAIL exec error), retrying full desktop (fallbackDesktop enabled)..." >&2
            CLEAN_ARGS=()
            for a in "''${FREERDP_ARGS[@]}"; do
              case "$a" in /app:*) ;; *) CLEAN_ARGS+=("$a") ;; esac
            done
            exec ${pkgs.freerdp}/bin/xfreerdp "''${CLEAN_ARGS[@]}"
          fi
        fi
      fi
      rm -f "$TMP_LOG"
      exit $STATUS
  '');

  # Example desktop entry generation script (Notepad)
  registerNotepad = pkgs.writeShellScriptBin "winapps-notepad-register" ''
      #!/usr/bin/env bash
      set -euo pipefail
      DIR="$HOME/.local/share/applications"
      mkdir -p "$DIR"
      cat > "$DIR/winapps-notepad.desktop" <<'EOF'
      [Desktop Entry]
      Name=Windows Notepad (RemoteApp)
      Comment=Launch Windows Notepad via WinApps/QEMU RemoteApp
    Exec=winapp-run --remote-app notepad
      Type=Application
      Categories=Utility;TextEditor;
      Icon=accessories-text-editor
      StartupNotify=false
      Terminal=false
      EOF
      update-desktop-database "$DIR" 2>/dev/null || true
      echo "Created: $DIR/winapps-notepad.desktop"
  '';

  # Build desktop entries from config.programs.winapps.apps list
  generatedEntries = lib.listToAttrs (map (app: {
    name = app.desktopId;
    value = {
      name = app.name or app.desktopId;
      comment = app.comment or "WinApps RemoteApp";
      exec = "winapp-run --remote-app ${app.remoteAppId}";
      icon = app.icon or "application-x-ms-dos-executable";
      categories = app.categories or [ "Utility" ];
      terminal = false;
    };
  }) cfg.apps);

in {
  options.programs.winapps = {
    enable = lib.mkEnableOption
      "Enable minimal WinApps integration (RemoteApp via FreeRDP)" // {
        default = true;
      };
    fallbackDesktop = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "If RemoteApp launch fails (RAIL exec error), reconnect without /app for full desktop.";
    };
    scale = lib.mkOption {
      type = lib.types.nullOr lib.types.int;
      default = null;
      description = "Optional RDP scale percentage (100|140|180). If null, dynamic-resolution only.";
    };
    extraFlags = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Additional raw FreeRDP flags appended after computed defaults (e.g. '/microphone', '/audio-mode:1').";
    };
    rdpPort = lib.mkOption {
      type = lib.types.port;
      default = 33890;
      description = "Host port forwarded to guest 3389 for RDP RemoteApps.";
    };
    defaultUser = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description =
        "Default Windows username (prompted if null or empty at runtime).";
    };
    domain = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Optional Windows domain for authentication.";
    };
    examples = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description =
        "Include example Notepad registration script and desktop entry if no custom apps provided.";
    };
    apps = lib.mkOption {
      type = lib.types.listOf (lib.types.attrsOf lib.types.anything);
      default = [ ];
      example = [{
        desktopId = "winapps-notepad"; # desktop filename stem
        name = "Windows Notepad (RemoteApp)";
        remoteAppId = "||notepad"; # The RemoteApp / AppUserModelID
        icon = "accessories-text-editor"; # system icon or absolute path
        categories = [ "Utility" "TextEditor" ];
      }];
      description = ''
        List of RemoteApp definitions to create desktop entries for.
        Each entry attr set supports:
          desktopId    (required) – used for desktop filename and attribute key
          remoteAppId  (required) – value passed to /app: in FreeRDP
          name         (optional) – human readable name (default desktopId)
          comment      (optional)
          icon         (optional) – icon name or absolute path
          categories   (optional) – list of desktop categories
      '';
    };

    upstream = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable integration with upstream WinApps git repository (clone via fetchFromGitHub and optional installer helper).";
      };
      owner = lib.mkOption {
        type = lib.types.str;
        default = "Fmstrat";
        description = "GitHub owner for upstream WinApps repository.";
      };
      repo = lib.mkOption {
        type = lib.types.str;
        default = "winapps";
        description = "GitHub repository name for upstream WinApps.";
      };
      rev = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Git revision (commit hash or tag). REQUIRED when upstream.enable = true (pinned for reproducibility).";
      };
      sha256 = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Hash of fetched repository (nix-prefetch-github). REQUIRED when upstream.enable = true.";
      };
      autoInstall = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Automatically run upstream installer (user mode) during Home Manager activation (impure; generates desktop entries outside of Nix).";
      };
      installMode = lib.mkOption {
        type = lib.types.enum [ "user" "system" ];
        default = "user";
        description = "Installer mode passed to upstream ./installer.sh (--user or --system). 'system' may require elevated privileges.";
      };
    };
  };

  config = lib.mkIf cfg.enable (
    let
      upstreamSrc = if cfg.upstream.enable then pkgs.fetchFromGitHub {
        owner = cfg.upstream.owner;
        repo = cfg.upstream.repo;
        rev = cfg.upstream.rev;
        hash = cfg.upstream.sha256;
      } else null;

      winappsUpstreamInstall = if cfg.upstream.enable then pkgs.writeShellScriptBin "winapps-upstream-install" ''
        #!/usr/bin/env bash
        set -euo pipefail
        if ! command -v xfreerdp >/dev/null 2>&1; then
          echo "xfreerdp not found in PATH; ensure programs.winapps.enable" >&2
          exit 1
        fi
        SRC="${upstreamSrc}"
        DEST="${"${XDG_DATA_HOME:-$HOME/.local/share}"}/winapps-upstream"
        mkdir -p "$DEST"
        # Copy (rsync-like) but preserve local config/winapps.conf if present
        echo "Synchronizing upstream WinApps sources to $DEST ..."
        rsync -a --delete --exclude winapps.conf "$SRC/" "$DEST/"
        cd "$DEST"
        INSTALL_ARGS="--${cfg.upstream.installMode}"
        echo "Running upstream installer: ./installer.sh $INSTALL_ARGS" >&2
        if [ ! -f "$HOME/.config/winapps/winapps.conf" ]; then
          echo "NOTE: Create $HOME/.config/winapps/winapps.conf with RDP_USER / RDP_PASS etc before installing for full functionality." >&2
        fi
        bash ./installer.sh $INSTALL_ARGS || {
          echo "Upstream installer failed" >&2; exit 1; }
        echo "WinApps upstream install complete." >&2
      '' else null;
    in
  {
    assertions = [
      { assertion = !(cfg.upstream.enable && (cfg.upstream.rev == null || cfg.upstream.sha256 == null));
        message = "programs.winapps.upstream.enable is true, but rev and sha256 are not both set."; }
    ];

    home.packages = with pkgs;
      [ freerdp winappRun ]
      ++ lib.optionals cfg.examples (!cfg.upstream.enable) [ registerNotepad ]
      ++ lib.optionals cfg.upstream.enable [ winappsUpstreamInstall rsync imagemagick icoutils unzip ];

    # Install documentation file into the user's config directory
    home.file.".config/winapps/README.txt" = {
      text = builtins.readFile winappsDocs;
    };

    # If user specified custom apps, generate those desktop entries. If none and examples enabled, provide notepad.
    xdg.desktopEntries = lib.mkIf (!cfg.upstream.enable) (
      (lib.optionalAttrs (cfg.examples && (cfg.apps == [ ])) {
        winapps-notepad = {
          name = "Windows Notepad (RemoteApp)";
          comment = "Launch Windows Notepad through WinApps/QEMU";
          exec = "winapp-run --remote-app notepad";
          icon = "accessories-text-editor";
          categories = [ "Utility" "TextEditor" ];
          terminal = false;
        };
      }) // generatedEntries
    );

    # Optional automatic installer run (impure side-effect):
    home.activation.winappsUpstreamAutoInstall = lib.mkIf (cfg.upstream.enable && cfg.upstream.autoInstall) (lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      echo "[winapps] autoInstall enabled; invoking winapps-upstream-install" >&2
      winapps-upstream-install || true
    '');
  };
  );
}
