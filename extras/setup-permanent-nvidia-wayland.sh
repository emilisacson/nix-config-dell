#!/usr/bin/env bash

# Script to set up permanent NVIDIA Wayland environment variables
# This creates environment.d configuration for systemd user sessions

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="$SCRIPT_DIR/nvidia-wayland.conf"
TARGET_DIR="$HOME/.config/environment.d"

echo "Setting up permanent NVIDIA Wayland environment variables..."

# Create environment.d directory if it doesn't exist
mkdir -p "$TARGET_DIR"

# Copy the environment file
cp "$ENV_FILE" "$TARGET_DIR/nvidia-wayland.conf"

# Set up GDM configuration if needed and if user has sudo access
if command -v sudo &> /dev/null; then
    echo "Checking if GDM Wayland configuration needs to be updated..."
    
    if [ -f /etc/gdm/custom.conf ]; then
        if sudo grep -q "^WaylandEnable=false" /etc/gdm/custom.conf; then
            echo "GDM currently has Wayland disabled. Do you want to enable it? (y/n)"
            read -r response
            if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
                echo "Enabling Wayland in GDM..."
                sudo sed -i 's/^WaylandEnable=false/WaylandEnable=true/' /etc/gdm/custom.conf
                echo "GDM configured to use Wayland."
            fi
        else
            echo "GDM already has Wayland enabled."
        fi
    else
        echo "GDM custom.conf not found. No changes needed."
    fi
else
    echo "Note: Cannot check GDM configuration (sudo not available)."
fi

echo "Environment variables installed to $TARGET_DIR/nvidia-wayland.conf"
echo "These will be loaded automatically for all future Wayland sessions."
echo "You may need to log out and log back in for the changes to take effect."
