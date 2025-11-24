# VS Code Hash Troubleshooting Guide

## The Problem
VS Code Insiders updates frequently (sometimes multiple times per day), causing hash mismatches during Home Manager rebuilds.

## Quick Fix Commands

### If you get a hash mismatch error:

1. **Use the improved update script:**
   ```bash
   cd ~/.nix-config
   ./extras/update-vscode-hash.sh --force --rebuild
   ```

2. **Manual hash fix (if script fails):**
   ```bash
   # Get the correct hash from the error message and update manually
   # Look for lines like: "got: sha256:1rc9cqqri6gn37p2..."
   # Then edit applications/vscode.nix with the correct hash
   ```

3. **Nuclear option - Use empty hash:**
   ```bash
   # Edit applications/vscode.nix and set hash to empty string:
   # sha256 = "";
   # Then rebuild - Nix will tell you the correct hash
   ```

## Prevention Strategies

### Option 1: Use Stable VS Code (Recommended)
Edit `applications/vscode.nix` and change:
```nix
useInsiders = false; # Changed from true
```

Stable VS Code updates much less frequently, reducing hash mismatch issues.

### Option 2: Keep Using Insiders with Improved Script
The updated script now:
- Clears Nix cache before fetching
- Retries on failures
- Verifies the build before full rebuild
- Auto-corrects hash mismatches when possible
- Has a `--force` option for cache issues

### Option 3: Use Nixpkgs VS Code (Most Stable)
Replace the custom VS Code configuration with the nixpkgs version:
```nix
programs.vscode = {
  enable = true;
  package = pkgs.vscode; # or pkgs.vscode-insiders
};
```

## When Hash Mismatches Happen

1. **Don't panic** - This is a known issue with frequently updating software
2. **Use the updated script** - It now handles most cases automatically
3. **Check the error message** - It usually contains the correct hash
4. **Consider switching to stable** - Much more reliable for daily use

## Script Options

```bash
# Basic update (detects channel automatically)
./extras/update-vscode-hash.sh

# Force update even if hash seems current
./extras/update-vscode-hash.sh --force

# Update and rebuild automatically
./extras/update-vscode-hash.sh --rebuild

# Force update specific channel and rebuild
./extras/update-vscode-hash.sh --force --rebuild insiders
```

## Emergency Commands

If everything breaks:
```bash
# Quick rebuild without VS Code
cd ~/.nix-config
# Temporarily disable VS Code in applications/applications.nix
# Then rebuild
NIXPKGS_ALLOW_UNFREE=1 nix run --impure .#homeConfigurations.$USER.activationPackage
```