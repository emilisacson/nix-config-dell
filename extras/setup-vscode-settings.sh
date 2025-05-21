#!/usr/bin/env bash

# This script sets up VS Code settings the first time, but allows VS Code to manage them afterwards
# Run this after a fresh installation or if you want to reset your VS Code settings

# Make sure the VS Code settings directory exists
mkdir -p ~/.config/Code/User/

# Only create settings.json if it doesn't exist or if --force is passed
if [ ! -f ~/.config/Code/User/settings.json ] || [ "$1" == "--force" ]; then
    cat > ~/.config/Code/User/settings.json << EOF
{
    "editor.formatOnSave": true,
    "nix.enableLanguageServer": false,
    "github.copilot.enable": true,
    "nix.formatterPath": "$HOME/.nix-profile/bin/nixfmt",
    "nix.serverPath": "nil",
    "nix.serverSettings": {
        "nil": {
            "formatting": {
                "command": ["$HOME/.nix-profile/bin/nixfmt"]
            }
        }
    },
    
    // Python settings
    "python.defaultInterpreterPath": "/run/current-system/sw/bin/python3",
    "python.formatting.provider": "black",
    "python.formatting.blackPath": "/run/current-system/sw/bin/black",
    "python.linting.enabled": true,
    "python.linting.flake8Enabled": true,
    "python.linting.flake8Path": "/run/current-system/sw/bin/flake8",
    "python.linting.mypyEnabled": true,
    "python.linting.mypyPath": "/run/current-system/sw/bin/mypy",
    "python.analysis.extraPaths": [
        "/run/current-system/sw/lib/python3.12/site-packages"
    ],
    "[python]": {
        "editor.formatOnSave": true,
        "editor.codeActionsOnSave": {
            "source.organizeImports": true
        }
    }
}
EOF
    echo "VS Code settings.json created/updated successfully!"
else
    echo "VS Code settings.json already exists. Use --force to override."
fi

# Make sure VS Code has permissions to modify the settings file
chmod 644 ~/.config/Code/User/settings.json

# Create a directory for user-local binaries if it doesn't exist
mkdir -p ~/.local/bin

# Create symlinks for nixfmt in standard system paths
if [ -f ~/.nix-profile/bin/nixfmt ]; then
    # Create symlink in ~/.local/bin
    mkdir -p ~/.local/bin
    ln -sf ~/.nix-profile/bin/nixfmt ~/.local/bin/nixfmt
    echo "Created symlink for nixfmt in ~/.local/bin"
    
    # Try to create symlink in the expected system path
    # Only attempt if sudo is available
    if command -v sudo &> /dev/null; then
        sudo mkdir -p /run/current-system/sw/bin
        sudo ln -sf ~/.nix-profile/bin/nixfmt /run/current-system/sw/bin/nixfmt
        echo "Created symlink for nixfmt in system path"
    else
        echo "Warning: 'sudo' command not available. Could not create system symlink."
        echo "VS Code will only look for nixfmt in ~/.local/bin and ~/.nix-profile/bin"
    fi
fi

echo "Done! VS Code should now be able to save settings properly."
