#!/usr/bin/env bash
# Update the VS Code (stable or insiders) sha256 hash in applications/vscode.nix
# and record the change in docs/vscode_hash_log.md
#
# Usage:
#   extras/update-vscode-hash.sh [stable|insiders|auto]
#   (If no argument given, defaults to auto)
#
# auto: Reads the useInsiders variable inside applications/vscode.nix and
#       updates the corresponding channel.
#
# On successful update (hash changed) a line is prepended to the log file:
#   YYYY-MM-DDThh:mm:ss+TZ channel sha256:hash
# Timestamp uses Europe/Stockholm timezone.
#
# If the hash is already current, no code or log changes are made.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VSCODE_FILE="$REPO_ROOT/applications/vscode.nix"
LOG_FILE="$REPO_ROOT/docs/vscode_hash_log.md"

usage() {
  cat <<EOF
Update VS Code hash in $VSCODE_FILE

Usage: $(basename "$0") [OPTIONS] [stable|insiders|auto]
  stable     Force update of stable channel
  insiders   Force update of insiders channel
  auto       Detect from useInsiders variable (default when omitted)

Options:
  --rebuild  Run nix-home-rebuild after successful hash update
  --force    Force hash update even if it appears current
  -h, --help Show this help message
EOF
}

# Parse options
REBUILD_AFTER=false
FORCE_UPDATE=false
ARG_MODE="auto"

while [[ $# -gt 0 ]]; do
  case $1 in
    -h|--help)
      usage
      exit 0
      ;;
    --rebuild)
      REBUILD_AFTER=true
      shift
      ;;
    --force)
      FORCE_UPDATE=true
      shift
      ;;
    stable|insiders|insider|auto)
      ARG_MODE="$1"
      shift
      ;;
    *)
      echo "[ERROR] Unknown option: $1" >&2
      usage
      exit 1
      ;;
  esac
done

case "$ARG_MODE" in
  stable|insider|insiders|auto) ;;
  *) echo "[ERROR] Invalid mode: $ARG_MODE" >&2; usage; exit 1;;
esac

if ! command -v nix-prefetch-url >/dev/null 2>&1; then
  echo "[ERROR] nix-prefetch-url not found in PATH" >&2
  exit 2
fi

if [[ ! -f "$VSCODE_FILE" ]]; then
  echo "[ERROR] VS Code nix file not found at $VSCODE_FILE" >&2
  exit 3
fi

# Determine mode if auto
MODE=""
if [[ $ARG_MODE == auto ]]; then
  # Extract useInsiders = true/false;
  if grep -E 'useInsiders\s*=\s*true' "$VSCODE_FILE" >/dev/null; then
    MODE="insiders"
  elif grep -E 'useInsiders\s*=\s*false' "$VSCODE_FILE" >/dev/null; then
    MODE="stable"
  else
    echo "[ERROR] Could not determine useInsiders value in $VSCODE_FILE" >&2
    exit 4
  fi
else
  # Normalize
  if [[ $ARG_MODE == insider || $ARG_MODE == insiders ]]; then
    MODE="insiders"
  else
    MODE="stable"
  fi
fi

echo "[INFO] Selected channel: $MODE"

if [[ $MODE == insiders ]]; then
  URL="https://update.code.visualstudio.com/latest/linux-x64/insider"
else
  URL="https://update.code.visualstudio.com/latest/linux-x64/stable"
fi

echo "[INFO] Prefetching latest VS Code tarball for $MODE..."
# Note: nix-prefetch-url may return cached results
# The dry-run verification step will catch any mismatches

for attempt in 1 2 3; do
  echo "[INFO] Attempt $attempt: Fetching hash..."
  if NEW_HASH_BASE32=$(nix-prefetch-url --unpack "$URL" 2>/dev/null); then
    NEW_HASH="sha256:$NEW_HASH_BASE32"
    break
  else
    if [[ $attempt -eq 3 ]]; then
      echo "[ERROR] nix-prefetch-url failed after 3 attempts" >&2
      exit 5
    fi
    echo "[WARN] Attempt $attempt failed, retrying..."
    sleep 2
  fi
done

echo "[INFO] New hash fetched: $NEW_HASH"
echo "[WARN] Note: This may be a cached result. Dry-run verification will detect mismatches."

# Extract current hash from the relevant block
CURRENT_HASH=$(awk -v mode="$MODE" '
/https:\/\/update.code.visualstudio.com\/latest\/linux-x64\/insider/ { if(mode=="insiders") target=1 }
/https:\/\/update.code.visualstudio.com\/latest\/linux-x64\/stable/ { if(mode=="stable") target=1 }
# Capture first occurrence of sha256 = "..." after target flagged
(target && /sha256[[:space:]]*=[[:space:]]*"/) {
  if (match($0, /"[^"]+"/, a)) { 
    gsub(/"/,"",a[0]); 
    # Only print if it looks like a valid hash (starts with sha256: or is empty or looks hash-like)
    if (a[0] ~ /^sha256:/ || a[0] ~ /^[a-z0-9]{52}$/ || a[0] == "" || a[0] ~ /^got:/) { 
      # Normalize to sha256: format
      if (a[0] !~ /^sha256:/ && a[0] != "" && a[0] !~ /^got:/) {
        print "sha256:" a[0]
      } else if (a[0] ~ /^got:/) {
        print "sha256:0000000000000000000000000000000000000000000000000000"
      } else {
        print a[0]
      }
      exit 
    }
  }
}
' "$VSCODE_FILE")

if [[ -z ${CURRENT_HASH:-} ]]; then
  echo "[ERROR] Could not locate existing sha256 in $VSCODE_FILE for $MODE channel" >&2
  exit 6
fi

echo "[INFO] Current hash in file: $CURRENT_HASH"

if [[ "$CURRENT_HASH" == "$NEW_HASH" && "$FORCE_UPDATE" != "true" ]]; then
  echo "[INFO] Hash already up to date. No changes made."
  echo "[INFO] Use --force to update anyway or if you suspect cache issues."
  exit 0
fi

if [[ "$CURRENT_HASH" == "$NEW_HASH" && "$FORCE_UPDATE" == "true" ]]; then
  echo "[INFO] Hash appears current but --force specified, updating anyway..."
fi

echo "[INFO] Updating $VSCODE_FILE ..."
TMP_FILE="$(mktemp)"
awk -v mode="$MODE" -v newhash="$NEW_HASH" '
/https:\/\/update.code.visualstudio.com\/latest\/linux-x64\/insider/ { if(mode=="insiders") inblock=1 }
/https:\/\/update.code.visualstudio.com\/latest\/linux-x64\/stable/ { if(mode=="stable") inblock=1 }
{
  if (inblock && !done && /sha256[[:space:]]*=[[:space:]]*"/) {
    # Replace the hash value between quotes
    sub(/sha256[[:space:]]*=[[:space:]]*"[^"]*"/, "sha256 = \"" newhash "\"")
    done=1
    inblock=0
  }
  print
}
' "$VSCODE_FILE" > "$TMP_FILE"

# Basic validation: ensure new hash present
if ! grep -q "$NEW_HASH" "$TMP_FILE"; then
  echo "[ERROR] Updated file does not contain new hash. Aborting." >&2
  rm -f "$TMP_FILE"
  exit 7
fi

mv "$TMP_FILE" "$VSCODE_FILE"

echo "[INFO] Updated hash written. Cleaning potential trailing whitespace..."
sed -i 's/[[:space:]]*$//' "$VSCODE_FILE"

# Prepare log entry (only on successful update)
TIMESTAMP=$(TZ="Europe/Stockholm" date +%Y-%m-%dT%H:%M:%S%z)
LOG_ENTRY="$TIMESTAMP $MODE $NEW_HASH"

echo "[INFO] Logging update to $LOG_FILE"
if [[ ! -f "$LOG_FILE" ]]; then
  printf '# VS Code Hash Update Log\n' > "$LOG_FILE"
  printf '# Newest entries first. Timestamp Europe/Stockholm.\n\n' >> "$LOG_FILE"
  printf '%s\n' "$LOG_ENTRY" >> "$LOG_FILE"
else
  # Preserve header (first line starts with # VS Code Hash Update Log)
  FIRST_LINE=$(head -n1 "$LOG_FILE")
  if [[ "$FIRST_LINE" == "# VS Code Hash Update Log" ]]; then
    { printf '# VS Code Hash Update Log\n'; \
      sed -n '2p' "$LOG_FILE" | grep -q '^# Newest entries first' && sed -n '2p' "$LOG_FILE"; \
      printf '\n%s\n' "$LOG_ENTRY"; \
      # Print rest starting after header + optional second comment line and blank line(s)
      tail -n +3 "$LOG_FILE"; } > "$LOG_FILE.tmp"
  else
    { printf '# VS Code Hash Update Log\n# Newest entries first. Timestamp Europe/Stockholm.\n\n'; printf '%s\n' "$LOG_ENTRY"; cat "$LOG_FILE"; } > "$LOG_FILE.tmp"
  fi
  mv "$LOG_FILE.tmp" "$LOG_FILE"
fi

echo "[SUCCESS] VS Code $MODE hash updated: $CURRENT_HASH -> $NEW_HASH"

if [[ "$REBUILD_AFTER" == "true" ]]; then
  echo "[INFO] Running nix-home-rebuild..."
  cd "$REPO_ROOT"
  
  # First, do a quick verification build to catch hash mismatches early
  echo "[INFO] Verifying configuration (dry-run)..."
  if ! NIXPKGS_ALLOW_UNFREE=1 nix build --dry-run --impure .#homeConfigurations.$USER.activationPackage 2>&1 | tee /tmp/nix-build-verify.log; then
    echo "[ERROR] Configuration verification failed. Checking for hash mismatch..." >&2
    
    if grep -q "hash mismatch" /tmp/nix-build-verify.log; then
      echo "[ERROR] Hash mismatch detected during verification!" >&2
      echo "[INFO] This suggests VS Code was updated between our check and build." >&2
      echo "[INFO] Re-running hash update with --force..." >&2
      
      # Try to get the actual hash from the error
      # The format is typically "got:       sha256:xxxxx"
      ACTUAL_HASH=$(grep "got:" /tmp/nix-build-verify.log | grep -oE "sha256:[a-z0-9]+" | head -1)
      if [[ -n "$ACTUAL_HASH" ]]; then
        echo "[INFO] Found actual hash in error: $ACTUAL_HASH"
        echo "[INFO] Updating to correct hash..."
        
        # Update with the correct hash
        TMP_FILE="$(mktemp)"
        awk -v mode="$MODE" -v newhash="$ACTUAL_HASH" '
        /https:\/\/update.code.visualstudio.com\/latest\/linux-x64\/insider/ { if(mode=="insiders") inblock=1 }
        /https:\/\/update.code.visualstudio.com\/latest\/linux-x64\/stable/ { if(mode=="stable") inblock=1 }
        {
          if (inblock && !done && /"sha256:[a-z0-9]+"/) {
            sub(/"sha256:[a-z0-9]+".*/, "\"" newhash "\";")
            done=1
            inblock=0
          }
          print
        }
        ' "$VSCODE_FILE" > "$TMP_FILE"
        
        mv "$TMP_FILE" "$VSCODE_FILE"
        sed -i 's/[[:space:]]*$//' "$VSCODE_FILE"
        
        echo "[INFO] Hash corrected to: $ACTUAL_HASH"
        echo "[INFO] Retrying verification..."
        
        if ! NIXPKGS_ALLOW_UNFREE=1 nix build --dry-run --impure .#homeConfigurations.$USER.activationPackage; then
          echo "[ERROR] Verification still failed after hash correction" >&2
          exit 8
        fi
      else
        echo "[ERROR] Could not extract correct hash from error message" >&2
        exit 8
      fi
    else
      echo "[ERROR] Configuration verification failed for unknown reason" >&2
      exit 8
    fi
  fi
  
  echo "[INFO] Configuration verified successfully. Proceeding with full rebuild..."
  
  if NIXPKGS_ALLOW_UNFREE=1 nix run --impure "path:$HOME/.nix-config#homeConfigurations.$USER.activationPackage"; then
    echo "[SUCCESS] Home Manager rebuild completed successfully"
  else
    echo "[ERROR] Home Manager rebuild failed" >&2
    exit 8
  fi
else
  echo "[NEXT] Run: nix-home-rebuild  (to apply the new version)"
fi
