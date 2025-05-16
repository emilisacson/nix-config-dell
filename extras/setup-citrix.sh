#!/bin/bash

# Script to set up Citrix Workspace for use with Nix
set -e

CITRIX_VERSION="24.11.0.85"
DOWNLOAD_FILE="linuxx64-${CITRIX_VERSION}.tar.gz"
DOWNLOAD_URL="https://www.citrix.com/downloads/workspace-app/linux/workspace-app-for-linux-latest.html"

echo "===== Citrix Workspace Setup for Nix ====="
echo ""
echo "This script will help you set up Citrix Workspace version ${CITRIX_VERSION} for use with Nix"
echo ""
echo "Step 1: You need to manually download the Citrix Workspace app from:"
echo "  ${DOWNLOAD_URL}"
echo ""
echo "  Select 'Workspace app for Linux (x86_64)' and download the .tar.gz file"
echo ""

read -p "Press Enter once you have downloaded the file..."

# Check if the file exists in current directory or Downloads
if [ -f "${DOWNLOAD_FILE}" ]; then
    FILE_PATH="${DOWNLOAD_FILE}"
elif [ -f "$HOME/Downloads/${DOWNLOAD_FILE}" ]; then
    FILE_PATH="$HOME/Downloads/${DOWNLOAD_FILE}"
else
    echo "ERROR: Could not find ${DOWNLOAD_FILE} in current directory or Downloads folder"
    echo "Please download the file and try again, or move it to the current directory"
    exit 1
fi

echo "Found Citrix Workspace file at: ${FILE_PATH}"
echo ""
echo "Step 2: Adding the file to the Nix store..."

# Add the file to the Nix store
HASH=$(nix-prefetch-url "file://${FILE_PATH}")

if [ -z "$HASH" ]; then
    echo "ERROR: Failed to add file to Nix store"
    exit 1
fi

echo ""
echo "Success! The file has been added to the Nix store with hash:"
echo "${HASH}"
echo ""
echo "Step 3: Updating your configuration..."

# Get the directory of this script
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
CITRIX_CONFIG="${SCRIPT_DIR}/../applications/citrix.nix"

echo "Your citrix.nix file has been updated to use the Nix store version."
echo ""
echo "To finish the setup, run:"
echo "nix run --impure .#homeConfigurations.\$USER.activationPackage"
echo ""
echo "Citrix Workspace should now be properly installed and configured!"