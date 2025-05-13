#!/bin/bash

# This script helps prepare the latest Citrix Workspace for Linux for use with Nix
# Due to Citrix's download protection, manual download is required

# Set up variables
DOWNLOAD_DIR="${HOME}/Downloads"
CITRIX_DOWNLOAD_PAGE="https://www.citrix.com/downloads/workspace-app/linux/workspace-app-for-linux-latest.html"
VERSION_PATTERN="linuxx64-([0-9\.]+)\.tar\.gz"
OUTPUT_FILE="${HOME}/.cache/citrix-workspace-latest.json"

mkdir -p "${HOME}/.cache"

echo "Fetching Citrix download page to determine latest version..."
DOWNLOAD_PAGE=$(curl -s "$CITRIX_DOWNLOAD_PAGE")

# Extract the latest version number
if [[ $DOWNLOAD_PAGE =~ $VERSION_PATTERN ]]; then
  VERSION="${BASH_REMATCH[1]}"
  echo "Latest version found: $VERSION"
else
  echo "Error: Could not determine latest version."
  echo "Please visit $CITRIX_DOWNLOAD_PAGE"
  echo "Look for the Linux version number in the filename (e.g., linuxx64-XX.XX.X.XX.tar.gz)"
  read -p "Enter the version number manually: " VERSION
  if [ -z "$VERSION" ]; then
    echo "No version provided. Exiting."
    exit 1
  fi
fi

# Construct filename
INSTALLER_NAME="linuxx64-${VERSION}.tar.gz"
EXPECTED_PATH="$DOWNLOAD_DIR/$INSTALLER_NAME"

echo "==================================================================="
echo "MANUAL DOWNLOAD REQUIRED"
echo "==================================================================="
echo "Citrix requires authentication to download their software."
echo ""
echo "Please follow these steps:"
echo "1. Visit: $CITRIX_DOWNLOAD_PAGE"
echo "2. Click 'Download Citrix Workspace app for Linux'"
echo "3. You may need to log in or fill out a form"
echo "4. Save the file as: $EXPECTED_PATH"
echo ""
echo "Once downloaded, press Enter to continue, or Ctrl+C to cancel."
read -p "Press Enter when download is complete..."

# Check if the file exists and has a reasonable size (at least 10MB)
if [ ! -f "$EXPECTED_PATH" ]; then
  echo "Error: File not found at $EXPECTED_PATH"
  exit 1
fi

FILE_SIZE=$(stat -c%s "$EXPECTED_PATH")
MIN_SIZE=$((10*1024*1024)) # 10MB minimum

if [ "$FILE_SIZE" -lt "$MIN_SIZE" ]; then
  echo "Warning: The downloaded file is suspiciously small ($(($FILE_SIZE/1024/1024))MB)."
  echo "A complete Citrix Workspace installer should be over 400MB."
  echo "The file you downloaded may not be the actual installer."
  read -p "Continue anyway? (y/n): " CONTINUE
  if [[ ! "$CONTINUE" =~ ^[Yy]$ ]]; then
    echo "Aborted. Please try downloading again."
    exit 1
  fi
fi

echo "Adding Citrix Workspace to Nix store..."
HASH=$(nix-prefetch-url "file://$EXPECTED_PATH")

# Save the version and hash information to a JSON file
echo "{\"version\": \"$VERSION\", \"sha256\": \"$HASH\", \"filename\": \"$INSTALLER_NAME\"}" > "$OUTPUT_FILE"

echo "Successfully prepared Citrix Workspace $VERSION for Nix!"
echo "Version information saved to: $OUTPUT_FILE"
echo "You can now run: nix run .#homeConfigurations.\$USER.activationPackage"