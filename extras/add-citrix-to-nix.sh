#!/bin/bash
# Fully automated script for adding Citrix Workspace to Nix
# This script handles the entire process of downloading and integrating Citrix Workspace

set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOWNLOAD_DIR="${HOME}/Downloads"
CONFIG_DIR="/home/emil/nix-config"
CONFIG_FILE="${CONFIG_DIR}/applications/citrix.nix"
CACHE_DIR="${HOME}/.cache"
OUTPUT_FILE="${CACHE_DIR}/citrix-workspace-latest.json"
TEMP_DIR="${CACHE_DIR}/citrix-temp"

# Make sure we have required directories
mkdir -p "${DOWNLOAD_DIR}"
mkdir -p "${CACHE_DIR}"
mkdir -p "${TEMP_DIR}"

echo "===================================================="
echo "Citrix Workspace - Fully Automated Setup for Nix"
echo "===================================================="

# Check if Nix is available
if ! command -v nix-shell >/dev/null 2>&1; then
  echo "Error: Nix is not installed or not in PATH. This script requires Nix."
  exit 1
fi

# Function to check if a command exists
command_exists() {
  command -v "$1" >/dev/null 2>&1
}

# Function to detect operating system
detect_os() {
  if [ -f /etc/fedora-release ]; then
    echo "fedora"
  elif [ -f /etc/redhat-release ]; then
    echo "redhat"
  elif [ -f /etc/os-release ]; then
    . /etc/os-release
    echo "$ID"
  else
    echo "unknown"
  fi
}

# Create a temporary environment for Node.js and dependencies
setup_temp_environment() {
  echo "Setting up temporary environment with required dependencies..."
  
  # Create a package.json if it doesn't exist in the temp directory
  if [[ ! -f "${TEMP_DIR}/package.json" ]]; then
    echo '{
  "name": "citrix-download-automation",
  "version": "1.0.0",
  "description": "Automates downloading Citrix Workspace",
  "dependencies": {
    "puppeteer-core": "^20.0.0",
    "minimist": "^1.2.8"
  }
}' > "${TEMP_DIR}/package.json"
  fi
  
  # Copy the auto-download script to temp directory
  cp "${SCRIPT_DIR}/auto-download-citrix.js" "${TEMP_DIR}/"
  
  # Enter temporary Nix shell and install Node dependencies
  echo "Installing Node.js dependencies in temporary directory..."
  cd "${TEMP_DIR}"
  nix-shell "${SCRIPT_DIR}/citrix-shell.nix" --run "npm install --no-fund --no-audit --loglevel=error"
  
  if [[ $? -ne 0 ]]; then
    echo "Failed to install Node.js dependencies. Please check errors above."
    exit 1
  fi
  
  echo "Temporary environment set up successfully."
}

# Run the automated downloader in the temporary Nix shell
run_automated_downloader() {
  echo "Starting automated Citrix download..."
  
  # Determine preferred browser based on OS
  OS_TYPE=$(detect_os)
  BROWSER_ARGS=""
  
  if [[ "$OS_TYPE" == "fedora" ]]; then
    echo "Fedora detected - preferring Firefox for download"
    BROWSER_ARGS="--browser=firefox"
  else
    # Default to Firefox since we provide it in the Nix shell
    BROWSER_ARGS="--browser=firefox"
  fi
  
  # Run the script in the Nix shell
  cd "${TEMP_DIR}"
  nix-shell "${SCRIPT_DIR}/citrix-shell.nix" --run "node auto-download-citrix.js --download-dir=\"${DOWNLOAD_DIR}\" ${BROWSER_ARGS} $@"
  
  # Check if the download was successful
  if [[ $? -ne 0 ]]; then
    echo "Automated download failed. Falling back to manual download instructions."
    return 1
  fi
  
  return 0
}

# Function to check for existing RPM
find_rpm_file() {
  # First check if the automated downloader wrote a metadata file
  if [[ -f "$OUTPUT_FILE" ]]; then
    local metadata_file=$(cat "$OUTPUT_FILE")
    local rpm_path=$(echo "$metadata_file" | grep -o '"path":"[^"]*' | cut -d'"' -f4)
    
    if [[ -f "$rpm_path" ]]; then
      echo "$rpm_path"
      return 0
    fi
  fi
  
  # Look for standard location
  if [[ -f "${DOWNLOAD_DIR}/citrix-workspace.rpm" ]]; then
    echo "${DOWNLOAD_DIR}/citrix-workspace.rpm"
    return 0
  fi
  
  # Look for any Citrix RPM in the downloads directory
  local files=$(find "$DOWNLOAD_DIR" -maxdepth 1 -name "*citrix*.rpm" -o -name "*workspace*.rpm" -o -name "*ica*.rpm" 2>/dev/null | sort -r)
  
  if [[ -n "$files" ]]; then
    # Return the first (newest) match
    echo "$(echo "$files" | head -n1)"
    return 0
  fi
  
  # Special case for Firefox downloads that might go to default download location
  if command_exists firefox; then
    # Try to find Firefox's default download dir
    local firefox_download_dir="${HOME}/Downloads"
    if [ -f "${HOME}/.mozilla/firefox/profiles.ini" ]; then
      # Try to parse Firefox profiles.ini to find download directory
      local profile_path=$(grep -A2 "Default=1" "${HOME}/.mozilla/firefox/profiles.ini" | grep "Path=" | cut -d= -f2)
      if [ -n "$profile_path" ]; then
        local prefs_file="${HOME}/.mozilla/firefox/${profile_path}/prefs.js"
        if [ -f "$prefs_file" ]; then
          local custom_download_dir=$(grep "browser.download.dir" "$prefs_file" | grep -o '"[^"]*"' | tr -d '"')
          if [ -n "$custom_download_dir" ]; then
            firefox_download_dir="$custom_download_dir"
          fi
        fi
      fi
    fi
    
    # Look in Firefox download dir if it differs from our download dir
    if [ "$firefox_download_dir" != "$DOWNLOAD_DIR" ]; then
      echo "Looking for downloads in Firefox's default location: $firefox_download_dir"
      local firefox_files=$(find "$firefox_download_dir" -maxdepth 1 -name "*citrix*.rpm" -o -name "*workspace*.rpm" -o -name "*ica*.rpm" 2>/dev/null | sort -r)
      if [[ -n "$firefox_files" ]]; then
        # Return the first (newest) match
        echo "$(echo "$firefox_files" | head -n1)"
        return 0
      fi
    fi
  fi
  
  return 1
}

# Function to handle manual download
handle_manual_download() {
  echo ""
  echo "==================================================================="
  echo "MANUAL DOWNLOAD REQUIRED"
  echo "==================================================================="
  echo "Citrix requires authentication to download their software."
  echo ""
  echo "Please follow these steps:"
  echo "1. Visit: https://www.citrix.com/downloads/workspace-app/linux/workspace-app-for-linux-latest.html"
  echo "2. Click 'Download Citrix Workspace app for Linux'"
  echo "3. For installation with Nix, select 'RPM Packages'"
  echo "4. Download 'Red Hat Enterprise Linux/CentOS Full Package (Self-Service Support)'"
  echo "5. You will need to accept the EULA by clicking 'Yes, I accept'"
  echo "6. Save the file to: $DOWNLOAD_DIR"
  echo ""
  
  read -p "Press Enter when download is complete, or specify path to existing RPM: " MANUAL_PATH
  
  if [[ -n "$MANUAL_PATH" && -f "$MANUAL_PATH" ]]; then
    echo "$MANUAL_PATH"
    return 0
  fi
  
  # Check if the file now exists
  local rpm_path=$(find_rpm_file)
  if [[ -n "$rpm_path" ]]; then
    echo "$rpm_path"
    return 0
  fi
  
  echo "Error: No Citrix RPM file found. Please download it and try again."
  return 1
}

# Function to extract version info from filename
extract_version() {
  local rpm_path="$1"
  local rpm_filename=$(basename "$rpm_path")
  
  # Try to extract version number using regex pattern
  if [[ "$rpm_filename" =~ ([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+) ]]; then
    VERSION="${BASH_REMATCH[1]}"
    echo "Detected Citrix Workspace version: $VERSION"
  elif [[ "$rpm_filename" =~ ([0-9]+\.[0-9]+\.[0-9]+) ]]; then
    VERSION="${BASH_REMATCH[1]}.0"
    echo "Detected partial version number: $VERSION"
  else
    # If we can't extract from filename, try using rpm command if available
    if command_exists rpm; then
      VERSION=$(rpm -qp --queryformat '%{VERSION}' "$rpm_path" 2>/dev/null)
      if [[ $? -eq 0 && -n "$VERSION" ]]; then
        echo "Extracted version from RPM metadata: $VERSION"
      else
        VERSION="unknown"
        echo "Could not determine version. Using 'unknown'."
      fi
    else
      VERSION="unknown"
      echo "Could not determine version. Using 'unknown'."
    fi
  fi
  
  echo "$VERSION"
}

# Function to add RPM to Nix store
add_to_nix_store() {
  local RPM_FILE="$1"
  echo "Adding Citrix Workspace RPM to Nix store..."
  HASH=$(nix-prefetch-url "file://$RPM_FILE" 2>/dev/null)
  
  if [ -z "$HASH" ]; then
    echo "Error: Failed to add RPM to Nix store."
    return 1
  fi
  
  echo "Successfully added to Nix store with hash: $HASH"
  echo "$HASH"
}

# Function to update the Nix configuration
update_nix_config() {
  local VERSION="$1"
  local HASH="$2"
  local RPM_FILE="$3"
  local FILENAME=$(basename "$RPM_FILE")
  
  echo "Updating Nix configuration for Citrix Workspace..."
  
  # Save the version and hash information to a JSON file
  echo "{\"version\": \"$VERSION\", \"sha256\": \"$HASH\", \"filename\": \"$FILENAME\"}" > "$OUTPUT_FILE"
  
  # Create a new version of citrix.nix
  cat > "$CONFIG_FILE" << EOF
{ pkgs, config, lib, ... }:

let
  # Define the version and package info
  citrixVersion = "$VERSION";
  citrixHash = "sha256-$HASH";
  citrixFilename = "$FILENAME";
  
  # Create a Citrix package from the official RPM
  citrixWorkspace = pkgs.stdenv.mkDerivation {
    name = "citrix-workspace-\${citrixVersion}";
    
    # Use the RPM that we've already prefetched
    src = pkgs.fetchurl {
      name = citrixFilename;
      url = "file://\${config.home.homeDirectory}/Downloads/\${citrixFilename}";
      hash = citrixHash;
    };
    
    # Tools needed to extract and process the RPM
    nativeBuildInputs = with pkgs; [ 
      rpm
      autoPatchelfHook
      makeWrapper
      cpio
    ];
    
    # Runtime dependencies
    buildInputs = with pkgs; [
      gtk3
      glib
      gdk-pixbuf
      webkitgtk_4_1
      nss
      nspr
      xorg.libxkbfile
      libsecret
      libidn
      openssl
      xorg.libXmu
      xorg.libXtst
      xorg.libXaw
      xorg.libXinerama
      xorg.libX11
      xorg.libXext
      xorg.libXrender
      xorg.libXfixes
      gst_all_1.gstreamer
      gst_all_1.gst-plugins-base
    ];
    
    # Extract files from the RPM
    unpackPhase = ''
      # Extract .rpm content (creates cpio archive)
      rpm2cpio \$src > citrix.cpio
      
      # Extract the cpio archive
      mkdir -p extracted
      cd extracted
      cpio -idm < ../citrix.cpio
      
      # Now we're in the directory with the extracted content
      cd ..
    '';
    
    installPhase = ''
      # Create target directory structure
      mkdir -p \$out/opt/Citrix/ICAClient
      mkdir -p \$out/bin
      mkdir -p \$out/share/applications
      
      # Copy all extracted files
      cp -r extracted/opt/Citrix/ICAClient/* \$out/opt/Citrix/ICAClient/
      
      # Ensure executables have proper permissions
      find \$out/opt/Citrix/ICAClient -type f -name "*.so*" -exec chmod +x {} \\;
      find \$out/opt/Citrix/ICAClient -type f -executable -exec chmod +x {} \\;
      
      # Create desktop file
      cat > \$out/share/applications/citrix-workspace.desktop << INNEREOF
[Desktop Entry]
Type=Application
Name=Citrix Workspace
Comment=Access virtual desktops and applications
Exec=\$out/bin/citrix-workspace %U
Icon=\$out/opt/Citrix/ICAClient/icons/receiver.png
Terminal=false
Categories=Network;RemoteAccess;
MimeType=application/x-ica;
INNEREOF
      
      # Create wrapper script
      makeWrapper \$out/opt/Citrix/ICAClient/selfservice \$out/bin/citrix-workspace \\
        --prefix PATH : "\${lib.makeBinPath [ pkgs.xdg-utils ]}" \\
        --set ICAROOT "\$out/opt/Citrix/ICAClient" \\
        --set GTK_PATH "\${pkgs.gtk3}/lib/gtk-3.0" \\
        --set SSL_CERT_FILE "\${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt" \\
        --set GIO_MODULE_DIR "\${pkgs.glib-networking}/lib/gio/modules" \\
        --set LIBCITRIX_DISABLE_CTX_MITM_CHECK "1" \\
        --set LIBCITRIX_CTX_SSL_FORCE_ACCEPT "1" \\
        --set LIBCITRIX_CTX_SSL_VERIFY_MODE "0" \\
        --set ICA_SSL_VERIFY_MODE "0" \\
        --prefix LD_LIBRARY_PATH : "\${pkgs.lib.makeLibraryPath [
          pkgs.webkitgtk_4_1
          pkgs.gtk3
          pkgs.glib
          pkgs.nss
          pkgs.openssl
          pkgs.libidn
          pkgs.gst_all_1.gstreamer
          pkgs.gst_all_1.gst-plugins-base
        ]}"
      
      # Create symlinks for main executables
      ln -sf \$out/opt/Citrix/ICAClient/wfica \$out/bin/wfica
      
      # Also create a debug launcher
      cat > \$out/bin/citrix-workspace-debug << INNEREOF
#!/bin/sh
echo "Starting Citrix Workspace in debug mode..."
export CITRIX_DEBUG=1
export ICAROOT=\$out/opt/Citrix/ICAClient
export GTK_PATH=\${pkgs.gtk3}/lib/gtk-3.0
export SSL_CERT_FILE=\${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt
export GIO_MODULE_DIR=\${pkgs.glib-networking}/lib/gio/modules

# Set up library paths
export LD_LIBRARY_PATH=\${pkgs.lib.makeLibraryPath [
  pkgs.webkitgtk_4_1
  pkgs.gtk3
  pkgs.glib
  pkgs.nss
  pkgs.openssl
  pkgs.libidn
  pkgs.gst_all_1.gstreamer
  pkgs.gst_all_1.gst-plugins-base
]}:\$ICAROOT

echo "ICAROOT=\$ICAROOT"
echo "LD_LIBRARY_PATH=\$LD_LIBRARY_PATH"
exec \$out/opt/Citrix/ICAClient/selfservice "\\\$@"
INNEREOF
      chmod +x \$out/bin/citrix-workspace-debug
    '';
    
    # Let autoPatchelfHook do its job
    dontStrip = true;
    dontPatchELF = false;
  };

in {
  # Add citrixWorkspace to the user's packages
  home.packages = [ citrixWorkspace ];
  
  # Create file handlers for .ica files
  xdg.mimeApps = {
    enable = true;
    defaultApplications = {
      "application/x-ica" = "citrix-workspace.desktop";
    };
  };
  
  # Add an activation script to set up required files
  home.activation.setupCitrix = lib.hm.dag.entryAfter ["writeBoundary"] ''
    # Create required directories
    mkdir -p \$HOME/.ICAClient/cache
    
    # Accept EULA automatically
    echo "1" > \$HOME/.ICAClient/.eula_accepted
    
    # Create symlink for certificates if needed
    mkdir -p \$HOME/.pki/nssdb || true
  '';
}
EOF

  echo "Nix configuration updated at $CONFIG_FILE"
}

# Function to rebuild the home configuration
rebuild_home_configuration() {
  echo "Rebuilding your home configuration with Nix..."
  nix run --impure .#homeConfigurations.$USER.activationPackage
  
  if [ $? -eq 0 ]; then
    echo "Citrix Workspace has been successfully installed with Nix!"
    echo ""
    echo "You can now launch it by running 'citrix-workspace' or from your application menu"
  else
    echo "Error: The build failed. Please check the error messages above."
    return 1
  fi
}

# Function to cleanup temporary files
cleanup_temp_files() {
  echo "Cleaning up temporary files..."
  if [[ -d "${TEMP_DIR}" ]]; then
    rm -rf "${TEMP_DIR}"
  fi
}

# Main program flow
main() {
  # Setup temporary environment with dependencies
  setup_temp_environment
  
  # Try to find an existing RPM file
  RPM_PATH=$(find_rpm_file)
  
  # If no RPM found, try automated download
  if [ -z "$RPM_PATH" ]; then
    echo "No existing Citrix RPM found. Attempting automated download..."
    
    # Try automated download
    if run_automated_downloader "$@"; then
      # Check if the download was successful
      RPM_PATH=$(find_rpm_file)
      if [ -z "$RPM_PATH" ]; then
        echo "Automated download appeared to succeed but no RPM was found."
        RPM_PATH=$(handle_manual_download)
      fi
    else
      # Fall back to manual download
      RPM_PATH=$(handle_manual_download)
    fi
  else
    echo "Found existing Citrix RPM: $RPM_PATH"
  fi
  
  # Final check - if we still don't have an RPM file, exit
  if [ -z "$RPM_PATH" ] || [ ! -f "$RPM_PATH" ]; then
    echo "Error: Could not find or download Citrix RPM. Please try again."
    exit 1
  fi
  
  # Extract version info
  VERSION=$(extract_version "$RPM_PATH")
  
  # Add the RPM to the Nix store
  HASH=$(add_to_nix_store "$RPM_PATH")
  if [ -z "$HASH" ]; then
    exit 1
  fi
  
  # Update the Nix configuration
  update_nix_config "$VERSION" "$HASH" "$RPM_PATH"
  
  # Offer to rebuild the home configuration
  echo ""
  echo "========================================================================"
  echo "Ready to rebuild your Nix configuration with Citrix Workspace $VERSION"
  echo "========================================================================"
  echo ""
  read -p "Would you like to rebuild now? (y/n): " REBUILD_NOW
  
  if [[ "$REBUILD_NOW" =~ ^[Yy]$ ]]; then
    rebuild_home_configuration
  else
    echo ""
    echo "To complete the installation, run:"
    echo "nix run --impure .#homeConfigurations.\$USER.activationPackage"
  fi
  
  # Clean up temporary files
  cleanup_temp_files
}

# Run the main program with all provided arguments
main "$@"