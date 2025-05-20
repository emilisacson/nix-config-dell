#!/bin/bash

# OneDrive Setup Guide
# This script will guide you through the initial OneDrive setup process

echo "OneDrive Setup Guide"
echo "===================="
echo ""

# Check if onedrive is installed
if ! command -v onedrive &> /dev/null; then
    echo "The OneDrive client isn't installed yet."
    echo "Please rebuild your home-manager configuration first:"
    echo "  cd ~/nix-config && NIXPKGS_ALLOW_UNFREE=1 nix run --impure .#homeConfigurations.\$USER.activationPackage"
    echo ""
    exit 1
fi

echo "This guide will help you set up the OneDrive client."
echo ""
echo "Step 1: Initialize OneDrive with your Microsoft account"
echo "-----------------------------------------------------"
echo "You'll need to authenticate with your Microsoft account."
echo "The client will open a browser window for you to log in."
echo ""
read -p "Press Enter to continue with authentication..."

# Run the initial authentication
onedrive --synchronize --verbose

echo ""
echo "Step 2: Start the OneDrive service"
echo "--------------------------------"
echo "Now that you've authenticated, let's start the OneDrive service."
echo ""
read -p "Press Enter to start the OneDrive service..."

# Start the service
systemctl --user enable onedrive
systemctl --user start onedrive

echo ""
echo "OneDrive Setup Complete"
echo "======================"
echo ""
echo "Your OneDrive is now configured and running."
echo ""
echo "Useful commands:"
echo "  - Check status: systemctl --user status onedrive"
echo "  - Stop syncing: systemctl --user stop onedrive"
echo "  - Start syncing: systemctl --user start onedrive"
echo "  - View sync progress: onedrive --monitor"
echo ""
echo "Your OneDrive files will be synced to: ~/OneDrive"
echo ""
echo "For more options, run: onedrive --help"

exit 0
