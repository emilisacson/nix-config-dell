#!/bin/bash

# Cleanup script for non-Nix Citrix installations
# This script will identify and remove Citrix files outside of the Nix store

echo "========================================================"
echo "Citrix Workspace Cleanup Script"
echo "========================================================"
echo "This script will clean up non-Nix Citrix installations from your system."
echo "It won't affect your Nix-managed Citrix installation."
echo

# Function to check if we have sudo access
check_sudo() {
    if sudo -n true 2>/dev/null; then
        return 0
    else
        echo "Requesting sudo access for system-wide cleanup operations..."
        if sudo true; then
            return 0
        else
            return 1
        fi
    fi
}

# Function to safely remove files with permission elevation when needed
safe_remove() {
    local path="$1"
    
    if [[ "$path" == "/nix/store/"* ]]; then
        echo "Skipping Nix store path: $path"
        return 0
    fi
    
    if [ -e "$path" ]; then
        # Check if we need sudo to remove this
        if [ -w "$(dirname "$path")" ] && ([ -w "$path" ] || [ ! -e "$path" ]); then
            echo "Removing: $path"
            rm -rf "$path"
        else
            echo "Removing (with sudo): $path"
            sudo rm -rf "$path"
        fi
    fi
}

# Ask for confirmation
read -p "Do you want to proceed with Citrix cleanup? (y/n): " confirm
if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
    echo "Cleanup canceled."
    exit 0
fi

# Check if we can get sudo access for system operations
if ! check_sudo; then
    echo "Warning: Could not get sudo access. Some system-wide files might not be removed."
    # We'll still try to proceed with what we can remove
fi

echo "Starting cleanup..."

# 1. Identify locations where Citrix might be installed outside of Nix
CITRIX_LOCATIONS=(
    "/opt/Citrix"
    "/usr/share/Citrix"
    "/usr/lib/ICAClient"
    "/usr/lib64/ICAClient"
    "/usr/lib/citrix"
    "/usr/lib64/citrix"
    "$HOME/.ICAClient"
    "$HOME/ICAClient"
    "$HOME/.cache/citrix"
    "$HOME/.local/share/Citrix"
    "$HOME/.Citrix"
)

# 2. Check and handle system-wide installations
echo
echo "Checking for system-wide Citrix installations..."
SYSTEM_ITEMS_FOUND=0
for location in "${CITRIX_LOCATIONS[@]}"; do
    # Skip home directory locations for this section
    if [[ "$location" == "$HOME"* ]]; then
        continue
    fi
    
    if [ -e "$location" ]; then
        SYSTEM_ITEMS_FOUND=1
        echo "Found Citrix installation at: $location"
    fi
done

if [ $SYSTEM_ITEMS_FOUND -eq 1 ]; then
    echo
    echo "System-wide Citrix installations found."
    read -p "Do you want to remove these system-wide installations? (y/n): " sudo_confirm
    
    if [[ "$sudo_confirm" == "y" || "$sudo_confirm" == "Y" ]]; then
        for location in "${CITRIX_LOCATIONS[@]}"; do
            # Skip home directory locations for this section
            if [[ "$location" == "$HOME"* ]]; then
                continue
            fi
            
            if [ -e "$location" ]; then
                safe_remove "$location"
            fi
        done
        echo "System-wide Citrix installations removed."
    else
        echo "Skipping removal of system-wide installations."
    fi
fi

# 3. Clean up user-specific Citrix files
echo
echo "Checking for user-specific Citrix installations..."
USER_ITEMS_FOUND=0
for location in "${CITRIX_LOCATIONS[@]}"; do
    # Only process home directory locations for this section
    if [[ "$location" == "$HOME"* ]]; then
        if [ -e "$location" ]; then
            USER_ITEMS_FOUND=1
            echo "Found Citrix user data at: $location"
        fi
    fi
done

if [ $USER_ITEMS_FOUND -eq 1 ]; then
    echo
    echo "User-specific Citrix data found."
    read -p "Do you want to remove user-specific Citrix data? (y/n): " user_confirm
    
    if [[ "$user_confirm" == "y" || "$user_confirm" == "Y" ]]; then
        # Save ICAClient configuration if requested
        read -p "Do you want to backup your Citrix ICAClient configuration before removing? (y/n): " backup_confirm
        if [[ "$backup_confirm" == "y" || "$backup_confirm" == "Y" ]]; then
            BACKUP_DIR="$HOME/citrix_backup_$(date +%Y%m%d_%H%M%S)"
            mkdir -p "$BACKUP_DIR"
            
            if [ -d "$HOME/.ICAClient" ]; then
                echo "Backing up $HOME/.ICAClient to $BACKUP_DIR"
                cp -r "$HOME/.ICAClient" "$BACKUP_DIR/"
            fi
            
            echo "Configuration backed up to $BACKUP_DIR"
        fi
        
        # Now remove user-specific Citrix files
        for location in "${CITRIX_LOCATIONS[@]}"; do
            if [[ "$location" == "$HOME"* ]]; then
                if [ -e "$location" ]; then
                    safe_remove "$location"
                fi
            fi
        done
        echo "User-specific Citrix data removed."
    else
        echo "Skipping removal of user-specific Citrix data."
    fi
fi

# 4. Clean up desktop files and application shortcuts - With more precise filtering
echo
echo "Checking for Citrix desktop shortcuts and application entries..."
DESKTOP_DIRS=(
    "$HOME/.local/share/applications"
    "/usr/share/applications"
)

# More precise patterns for Citrix desktop files
# This improves matching to avoid false positives
find_citrix_desktop_files() {
    local dir=$1
    find "$dir" -type f -name "*.desktop" 2>/dev/null | xargs grep -l -E "Citrix|ICAClient|wfica|selfservice|receiver\.png" 2>/dev/null || true
}

DESKTOP_ITEMS_FOUND=0
for dir in "${DESKTOP_DIRS[@]}"; do
    if [ -d "$dir" ]; then
        CITRIX_DESKTOPS=$(find_citrix_desktop_files "$dir")
        if [ -n "$CITRIX_DESKTOPS" ]; then
            DESKTOP_ITEMS_FOUND=1
            echo "Found Citrix desktop files in: $dir"
            echo "$CITRIX_DESKTOPS"
        fi
    fi
done

if [ $DESKTOP_ITEMS_FOUND -eq 1 ]; then
    echo
    read -p "Do you want to remove Citrix desktop shortcuts and application entries? (y/n): " desktop_confirm
    
    if [[ "$desktop_confirm" == "y" || "$desktop_confirm" == "Y" ]]; then
        # First handle user desktop files
        if [ -d "$HOME/.local/share/applications" ]; then
            CITRIX_USER_DESKTOPS=$(find_citrix_desktop_files "$HOME/.local/share/applications")
            if [ -n "$CITRIX_USER_DESKTOPS" ]; then
                echo "$CITRIX_USER_DESKTOPS" | while read -r file; do
                    safe_remove "$file"
                done
            fi
        fi
        
        # Then handle system desktop files
        if [ -d "/usr/share/applications" ]; then
            CITRIX_SYSTEM_DESKTOPS=$(find_citrix_desktop_files "/usr/share/applications")
            if [ -n "$CITRIX_SYSTEM_DESKTOPS" ]; then
                echo "$CITRIX_SYSTEM_DESKTOPS" | while read -r file; do
                    safe_remove "$file"
                done
            fi
        fi
        echo "Citrix desktop entries removed."
    fi
fi

# 5. Clean up any symbolic links to Citrix binaries in PATH
echo
echo "Checking for Citrix binaries in PATH..."
CITRIX_BINARIES=("selfservice" "wfica" "storebrowse" "configmgr" "citrix-workspace" "citrix-ica" "ctx_rehash" "conncenter")

for binary in "${CITRIX_BINARIES[@]}"; do
    # Skip binaries potentially managed by Nix
    binary_path=$(which "$binary" 2>/dev/null || true)
    if [ -n "$binary_path" ] && [[ "$binary_path" != *"/nix/store/"* ]]; then
        echo "Found non-Nix Citrix binary: $binary_path"
        read -p "Do you want to remove this binary? (y/n): " binary_confirm
        
        if [[ "$binary_confirm" == "y" || "$binary_confirm" == "Y" ]]; then
            safe_remove "$binary_path"
            echo "Removed: $binary_path"
        fi
    fi
done

# 6. Clean up downloaded installation files with more precise patterns
echo
echo "Checking for Citrix installer files..."
INSTALLER_LOCATIONS=(
    "$HOME/Downloads"
    "/tmp"
)

find_citrix_installers() {
    local dir=$1
    find "$dir" -maxdepth 1 -type f \( \
        -name "linuxx64*" -o \
        -name "icaclient*" -o \
        -name "ICAClient*" -o \
        -name "CitrixWorkspace*" -o \
        -name "CitrixReceiver*" \
    \) 2>/dev/null || true
}

INSTALLERS_FOUND=0
for location in "${INSTALLER_LOCATIONS[@]}"; do
    if [ -d "$location" ]; then
        CITRIX_INSTALLERS=$(find_citrix_installers "$location")
        if [ -n "$CITRIX_INSTALLERS" ]; then
            INSTALLERS_FOUND=1
            echo "Found Citrix installer files in: $location"
            echo "$CITRIX_INSTALLERS"
        fi
    fi
done

if [ $INSTALLERS_FOUND -eq 1 ]; then
    echo
    read -p "Do you want to remove Citrix installer files? (y/n): " installer_confirm
    
    if [[ "$installer_confirm" == "y" || "$installer_confirm" == "Y" ]]; then
        for location in "${INSTALLER_LOCATIONS[@]}"; do
            if [ -d "$location" ]; then
                CITRIX_INSTALLERS=$(find_citrix_installers "$location")
                if [ -n "$CITRIX_INSTALLERS" ]; then
                    echo "$CITRIX_INSTALLERS" | while read -r file; do
                        safe_remove "$file"
                    done
                fi
            fi
        done
        echo "Citrix installer files removed."
    fi
fi

# 7. Reset file associations for .ica files
echo
echo "Resetting file associations for .ica files..."
if [ -f "$HOME/.config/mimeapps.list" ]; then
    sed -i '/application\/x-ica=/d' "$HOME/.config/mimeapps.list"
    echo "File associations reset."
fi

# 8. Updating system cache
echo
echo "Updating system cache..."

# Update desktop database
if command -v update-desktop-database &> /dev/null; then
    update-desktop-database "$HOME/.local/share/applications" || true
fi

# Update mime database
if command -v update-mime-database &> /dev/null; then
    update-mime-database "$HOME/.local/share/mime" || true
fi

# 9. Clean up any remaining Citrix-related folders
echo
echo "Checking for other potential Citrix-related directories..."
OTHER_LOCATIONS=(
    "/var/lib/citrix"
    "/var/log/citrix"
    "/etc/citrix"
    "$HOME/.config/citrix"
    "$HOME/.config/autostart/selfservice.desktop"
)

OTHER_ITEMS_FOUND=0
for location in "${OTHER_LOCATIONS[@]}"; do
    if [ -e "$location" ]; then
        OTHER_ITEMS_FOUND=1
        echo "Found potential Citrix file/directory at: $location"
    fi
done

if [ $OTHER_ITEMS_FOUND -eq 1 ]; then
    echo
    read -p "Do you want to remove these additional Citrix-related files/directories? (y/n): " other_confirm
    
    if [[ "$other_confirm" == "y" || "$other_confirm" == "Y" ]]; then
        for location in "${OTHER_LOCATIONS[@]}"; do
            if [ -e "$location" ]; then
                safe_remove "$location"
            fi
        done
        echo "Additional Citrix-related files/directories removed."
    fi
fi

echo "========================================================"
echo "Citrix Workspace cleanup complete!"
echo "========================================================"
echo
echo "Now you can set up your Nix-managed Citrix installation without conflicts."
echo "To do this, run the following commands:"
echo
echo "cd ~/nix-config"
echo "nix run --impure .#homeConfigurations.\$USER.activationPackage"
echo
echo "After running the activation, you should be able to start Citrix Workspace with:"
echo "selfservice"
echo "========================================================"