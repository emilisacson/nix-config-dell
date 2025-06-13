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
    },
    
    // Git settings
    "git.autofetch": true,
    
    // File modification warning settings
    "modifyFileWarning.includedFileGlobs": [
        "**/original/**"
    ],
    
    // Nix environment selector
    "nixEnvSelector.useFlakes": true,
    
    // GitHub Copilot settings
    "github.copilot.nextEditSuggestions.enabled": true,
    "github.copilot.nextEditSuggestions.fixes": true,
    "github.copilot.chat.codesearch.enabled": true,
    "github.copilot.chat.agent.thinkingTool": true,
    "github.copilot.chat.editor.temporalContext.enabled": true,
    "github.copilot.chat.edits.temporalContext.enabled": true,
    "github.copilot.chat.generateTests.codeLens": true,
    "github.copilot.chat.languageContext.fix.typescript.enabled": true,
    "github.copilot.chat.languageContext.inline.typescript.enabled": true,
    "github.copilot.chat.languageContext.typescript.enabled": true,
    "github.copilot.chat.search.keywordSuggestions": true,
    
    // MCP (Model Context Protocol) settings
    "mcp": {
        "servers": {
            "context7": {
                "command": "npx",
                "args": [
                    "-y",
                    "@upstash/context7-mcp"
                ],
                "env": {}
            }
        },
        "inputs": []
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
fi

echo "VS Code settings applied successfully!"
