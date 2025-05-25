# Keyboard Layout Configuration Guide for Linux/Fedora/GNOME

## Overview
This comprehensive guide helps you configure and troubleshoot keyboard layouts on Fedora Linux with GNOME desktop environment. It covers both traditional package management and Nix/Home Manager approaches, with specific focus on Wayland compatibility and common configuration issues.

## Table of Contents
1. [Key Concepts](#key-concepts)
2. [Configuration Methods](#configuration-methods)
3. [Quick Setup Examples](#quick-setup-examples)
4. [Troubleshooting Guide](#troubleshooting-guide)
5. [Advanced Topics](#advanced-topics)
6. [Common Issues and Solutions](#common-issues-and-solutions)
7. [Reference Tables](#reference-tables)
   - [Keyboard Layout Paths](#keyboard-layout-paths)
   - [Keyboard Layout Commands](#keyboard-layout-commands)

## Quick Start Examples

### Basic Dual Layout Setup
Most users want their native layout plus English as backup:

**For Swedish users:**
```bash
# Using GNOME Settings (GUI)
gnome-control-center region

# Using command line - basic setup
gsettings set org.gnome.desktop.input-sources sources "[('xkb', 'se'), ('xkb', 'us')]"

# Using command line - with Swedish Dvorak variant
gsettings set org.gnome.desktop.input-sources sources "[('xkb', 'se+svdvorak'), ('xkb', 'se'), ('xkb', 'us')]"
```

**For other layouts (examples):**
```bash
# German
gsettings set org.gnome.desktop.input-sources sources "[('xkb', 'de'), ('xkb', 'us')]"

# French
gsettings set org.gnome.desktop.input-sources sources "[('xkb', 'fr'), ('xkb', 'us')]"
```

## Key Concepts

### Layout vs. Variant
- **Layout**: The base country layout (e.g., `se` for Sweden)
- **Variant**: A modification of the base layout (e.g., `svdvorak` for Swedish Dvorak)
- **Full specification**: `se+svdvorak` means Swedish layout with Dvorak variant

### Display Servers
- **Wayland**: Modern display server (default in Fedora 42/GNOME)
- **XWayland**: Compatibility layer for X11 applications running under Wayland
- **Different handling**: Keyboard configuration may differ between pure Wayland and XWayland apps

### Configuration Layers
1. **System-wide**: `/etc/X11/xorg.conf.d/`, `localectl`, `/etc/environment`
2. **Display Manager**: GDM configuration for login screen
3. **Desktop Environment**: GNOME's gsettings, dconf
4. **Application Level**: XKB compilation, custom layouts

## Configuration Methods

### Method 1: Using GNOME Settings (GUI) - Recommended for Most Users

The easiest way to configure keyboard layouts:

1. **Open Settings**: `gnome-control-center region` or Settings → Region & Language
2. **Add Input Sources**: Click the "+" button to add your desired layouts
3. **Reorder**: Drag layouts to set preference order
4. **Set Options**: Click the gear icon for advanced options (AltGr, Caps Lock behavior, etc.)

### Method 2: Using Command Line (gsettings)

For quick configuration or scripting:

```bash
# Set dual layout (Swedish + English as example)
gsettings set org.gnome.desktop.input-sources sources "[('xkb', 'se'), ('xkb', 'us')]"

# Set keyboard options
gsettings set org.gnome.desktop.input-sources xkb-options "['terminate:ctrl_alt_bksp', 'lv3:ralt_switch']"

# Check current settings
gsettings get org.gnome.desktop.input-sources sources
```

### Method 3: Using Nix/Home Manager (Advanced)

For users managing their system with Nix:

```nix
{ config, pkgs, lib, ... }:

{
  # Install required packages for keyboard customization
  home.packages = with pkgs; [
    xorg.xkbcomp # For custom keyboard layouts
    libnotify    # For notification support
  ];

  # Configure dual keyboard layout
  dconf.settings = {
    "org/gnome/desktop/input-sources" = {
      sources = [
        (lib.hm.gvariant.mkTuple [ "xkb" "se+svdvorak" ])  # Swedish Dvorak
        (lib.hm.gvariant.mkTuple [ "xkb" "se" ])           # Swedish QWERTY
        (lib.hm.gvariant.mkTuple [ "xkb" "us" ])           # US English
        # Add more layouts as needed:
        # (lib.hm.gvariant.mkTuple [ "xkb" "de" ])         # German
        # (lib.hm.gvariant.mkTuple [ "xkb" "fr" ])         # French
      ];
      xkb-options = [
        "terminate:ctrl_alt_bksp"  # Ctrl+Alt+Backspace to restart X
        "lv3:ralt_switch"          # Right Alt as AltGr
        # Add more options as needed:
        # "caps:escape"            # Caps Lock as Escape
        # "compose:ralt"           # Right Alt as Compose key
      ];
      current = 0; # Default to first layout
    };
  };

  # Activation script for immediate application
  home.activation.setKeyboardLayout =
    lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      if command -v gsettings &> /dev/null; then
        $DRY_RUN_CMD gsettings set org.gnome.desktop.input-sources sources "[('xkb', 'se+svdvorak'), ('xkb', 'se'), ('xkb', 'us')]"
        $DRY_RUN_CMD gsettings set org.gnome.desktop.input-sources xkb-options "['terminate:ctrl_alt_bksp', 'lv3:ralt_switch']"
      fi
    '';
}
```

### Method 4: System-wide Configuration (Traditional)

For system-wide keyboard configuration:

```bash
# Set system locale and keyboard (Swedish example)
sudo localectl set-keymap se
sudo localectl set-x11-keymap se

# Create X11 configuration file
sudo tee /etc/X11/xorg.conf.d/00-keyboard.conf << EOF
Section "InputClass"
    Identifier "system-keyboard"
    MatchIsKeyboard "on"
    Option "XkbLayout" "se,us"
    Option "XkbOptions" "grp:alt_shift_toggle,terminate:ctrl_alt_bksp"
EndSection
EOF
```

### Method 5: Custom XKB Layouts (Expert Level)

For advanced users who need completely custom keyboard behavior, you can create custom XKB layouts. Here's an example structure:

```xkb
// Example: Custom XKB configuration with special key behavior
xkb_keymap {
    xkb_keycodes  { include "evdev" };
    xkb_types     { include "complete" };
    xkb_compat    { include "complete" };
    xkb_symbols   {
        // Include your base layouts (Swedish example)
        include "pc+se+us:2+inet(evdev)"
        
        // Example: Add custom key behavior
        // This is where you would define special key mappings
        // Refer to /usr/share/X11/xkb/symbols/ for examples
    };
    xkb_geometry  { include "pc(pc105)" };
};
```

To use a custom XKB layout:

1. **Create your layout file**: `/path/to/your-layout.xkb`
2. **Test compilation**: `xkbcomp -v your-layout.xkb $DISPLAY`
3. **Create a setup script**:

```bash
#!/usr/bin/env bash
# Load custom XKB configuration

# Wait for desktop environment to load
sleep 5

# Compile and load the custom XKB configuration
echo "Loading custom keyboard layout..."
xkbcomp -v -w0 /path/to/your-layout.xkb $DISPLAY 2> /tmp/xkb_error.log

# Check for errors
if [ $? -ne 0 ]; then
    echo "Failed to load custom keyboard layout. See /tmp/xkb_error.log"
    notify-send "Keyboard Layout" "Failed to load custom layout"
    exit 1
fi

echo "Custom keyboard layout loaded successfully."
notify-send "Keyboard Layout" "Custom layout loaded"
```

4. **Make it run on startup**: Add to GNOME autostart or your init system

## Troubleshooting Guide

## Troubleshooting Guide

### Step 1: Verify Current Status

```bash
# Check current keyboard settings
setxkbmap -query
localectl status
gsettings get org.gnome.desktop.input-sources sources
gsettings get org.gnome.desktop.input-sources xkb-options
```

**Understanding the Output:**
- `setxkbmap -query`: Shows the active layout for X11/XWayland applications
- `localectl status`: Shows system-wide keyboard configuration
- `gsettings`: Shows GNOME's keyboard configuration

### Step 2: Common Problems and Solutions

#### Problem: Wrong Layout Active

**Symptoms**: Typing produces unexpected characters, layout appears to be US instead of your desired layout.

**Solutions**:
```bash
# Method 1: Use GNOME Settings
gnome-control-center region

# Method 2: Command line fix
gsettings set org.gnome.desktop.input-sources sources "[('xkb', 'se'), ('xkb', 'us')]"

# Method 3: Reset and reconfigure
gsettings reset org.gnome.desktop.input-sources sources
# Then reconfigure through GUI or command line
```

#### Problem: Corrupted XKB symbol files causing partial keyboard layout failures

**Symptoms:** 
- `setxkbmap -layout se` returns "Error loading new keyboard description"
- `setxkbmap -query` shows `X11 Layout: (unset)` 
- Mixed behavior: some applications (Terminal, login screen, GNOME launcher) use US layout while others (VS Code, Brave, Teams) correctly use Swedish/svdvorak
- Applications started as root/sudo only use US layout

**Root Cause:** The `/usr/share/X11/xkb/symbols/se` file is corrupted or malformed, causing XKB to fail loading the Swedish layout. Different applications handle this failure differently:
- **System applications** (Terminal, GDM, GNOME Shell) fall back to US layout when XKB fails
- **User applications** (VS Code, Brave, Teams) may use cached layouts or alternative input methods
- **Root/sudo applications** bypass user session keyboard settings and rely on system XKB

**Diagnosis:**
```bash
# Test if Swedish layout can be loaded
setxkbmap -layout se -variant svdvorak
# Should show "Error loading new keyboard description" if corrupted

# Check XKB compilation
setxkbmap -layout se -print | xkbcomp - $DISPLAY
# Will show specific parsing errors

# Verify file integrity
ls -la /usr/share/X11/xkb/symbols/se
file /usr/share/X11/xkb/symbols/se

# Check for syntax errors in the symbol file
sudo xkbcomp /usr/share/X11/xkb/symbols/se /tmp/test_se.xkm
```

**Solution:**
```bash
# 1. Backup current file
sudo cp /usr/share/X11/xkb/symbols/se /usr/share/X11/xkb/symbols/se.backup

# 2. Restore from package (Fedora)
sudo dnf reinstall xkeyboard-config

# 3. Alternative: Copy from another system or download fresh
# sudo wget -O /usr/share/X11/xkb/symbols/se \
#   https://raw.githubusercontent.com/xkbcommon/libxkbcommon/master/test/data/symbols/se

# 4. Test the fix
setxkbmap -layout se -variant svdvorak -option terminate:ctrl_alt_bksp -option lv3:ralt_switch

# 5. Restart affected services to apply changes
sudo systemctl restart gdm
pkill -HUP gnome-shell

# 6. Verify the fix worked
setxkbmap -query
# Should now show: layout: se, variant: svdvorak
```

**Prevention:** 
- Avoid manually editing system XKB files in `/usr/share/X11/xkb/symbols/`
- Use custom layouts in `~/.xkb/` directory instead
- Regular system updates to catch XKB package fixes
- Test XKB changes in a separate file before applying system-wide

#### Problem: Layout Switching Not Working

**Symptoms**: Super+Space or configured hotkey doesn't switch between layouts.

**Check**:
```bash
# Verify multiple layouts are configured
gsettings get org.gnome.desktop.input-sources sources
# Should show multiple entries like: [('xkb', 'se'), ('xkb', 'us')]

# Check if shortcut is configured
gsettings get org.gnome.desktop.wm.keybindings switch-input-source
# Should show: ['<Super>space', 'XF86Keyboard']
```

**Solutions**:
```bash
# Ensure multiple layouts are set
gsettings set org.gnome.desktop.input-sources sources "[('xkb', 'se'), ('xkb', 'us')]"

# Reset switching shortcut if needed
gsettings reset org.gnome.desktop.wm.keybindings switch-input-source
```

#### Problem: Layout Not Available at Login Screen

**Symptoms**: Can only use US layout at GDM login screen.

**Solution**: Configure GDM system-wide:
```bash
# Create GDM keyboard configuration
sudo mkdir -p /etc/dconf/db/gdm.d
sudo tee /etc/dconf/db/gdm.d/00-keyboard-layout << EOF
[org/gnome/desktop/input-sources]
sources=[('xkb', 'se'), ('xkb', 'us')]
xkb-options=['terminate:ctrl_alt_bksp', 'lv3:ralt_switch']
EOF

# Update dconf database
sudo dconf update
```

#### Problem: Special Characters Don't Work (AltGr)

**Symptoms**: Cannot type characters like €, @, or accented letters using AltGr.

**Solutions**:
```bash
# Set Right Alt as AltGr key
gsettings set org.gnome.desktop.input-sources xkb-options "['lv3:ralt_switch']"

# Alternative: Use Right Alt as compose key
gsettings set org.gnome.desktop.input-sources xkb-options "['compose:ralt']"

# For some layouts, Left Alt might work better
gsettings set org.gnome.desktop.input-sources xkb-options "['lv3:lalt_switch']"
```

#### Problem: Inconsistent Behavior Between Applications

**Symptoms**: Some applications use different layouts than others.

**Root Cause**: Wayland vs XWayland applications handle keyboard input differently.

**Solutions**:
```bash
# Check if you're using Wayland
echo $XDG_SESSION_TYPE
# Should show "wayland"

# Clear conflicting X11 configurations
sudo rm -f /etc/X11/xorg.conf.d/*keyboard*

# Ensure system-wide consistency
sudo localectl set-keymap se
sudo localectl set-x11-keymap se
```

#### Problem: Changes Don't Persist After Reboot

**Symptoms**: Keyboard layout resets to US after restart.

**Solutions**:
```bash
# Check if settings are being saved
dconf dump /org/gnome/desktop/input-sources/

# If using Nix/Home Manager, rebuild configuration
cd ~/.nix-config && nix run .#homeConfigurations.$USER.activationPackage

# For traditional systems, verify localectl
sudo localectl set-keymap se
```

### Step 3: Complete Reset Procedure

If keyboard configuration is completely broken:

```bash
# 1. Clean up all previous configuration attempts
rm -f ~/.config/autostart/*keyboard*
sudo rm -f /etc/X11/xorg.conf.d/*keyboard*

# 2. Reset GNOME keyboard settings to defaults
gsettings reset org.gnome.desktop.input-sources sources
gsettings reset org.gnome.desktop.input-sources xkb-options
gsettings reset org.gnome.desktop.input-sources current

# 3. Set basic layout (Swedish example)
gsettings set org.gnome.desktop.input-sources sources "[('xkb', 'se')]"

# 4. If using Nix/Home Manager, rebuild configuration
# cd ~/.nix-config && nix run .#homeConfigurations.$USER.activationPackage

# 5. Otherwise, set system-wide keyboard
sudo localectl set-keymap se

# 6. Reboot to ensure all changes take effect
sudo systemctl reboot
```

## Advanced Topics

### Popular Keyboard Layout Examples

#### Common International Layouts
```bash
# Swedish (base example)
gsettings set org.gnome.desktop.input-sources sources "[('xkb', 'se'), ('xkb', 'us')]"

# German
gsettings set org.gnome.desktop.input-sources sources "[('xkb', 'de'), ('xkb', 'us')]"

# French
gsettings set org.gnome.desktop.input-sources sources "[('xkb', 'fr'), ('xkb', 'us')]"

# Spanish
gsettings set org.gnome.desktop.input-sources sources "[('xkb', 'es'), ('xkb', 'us')]"

# Russian
gsettings set org.gnome.desktop.input-sources sources "[('xkb', 'ru'), ('xkb', 'us')]"

# Japanese
gsettings set org.gnome.desktop.input-sources sources "[('ibus', 'mozc-jp'), ('xkb', 'us')]"
```

#### Layout Variants
```bash
# Swedish Dvorak (svdvorak)
gsettings set org.gnome.desktop.input-sources sources "[('xkb', 'se+svdvorak'), ('xkb', 'se')]"

# US Dvorak
gsettings set org.gnome.desktop.input-sources sources "[('xkb', 'us+dvorak'), ('xkb', 'us')]"

# Colemak
gsettings set org.gnome.desktop.input-sources sources "[('xkb', 'us+colemak'), ('xkb', 'us')]"

# UK English
gsettings set org.gnome.desktop.input-sources sources "[('xkb', 'gb'), ('xkb', 'us')]"
```

### Common XKB Options

#### Caps Lock Modifications
```bash
# Caps Lock as Escape (popular with Vim users)
gsettings set org.gnome.desktop.input-sources xkb-options "['caps:escape']"

# Caps Lock as additional Ctrl
gsettings set org.gnome.desktop.input-sources xkb-options "['caps:ctrl_modifier']"

# Swap Caps Lock and Escape
gsettings set org.gnome.desktop.input-sources xkb-options "['caps:swapescape']"
```

#### Alt Key Behavior
```bash
# Right Alt as AltGr (for special characters)
gsettings set org.gnome.desktop.input-sources xkb-options "['lv3:ralt_switch']"

# Right Alt as Compose key (for accented characters)
gsettings set org.gnome.desktop.input-sources xkb-options "['compose:ralt']"

# Both Alt keys as Meta
gsettings set org.gnome.desktop.input-sources xkb-options "['altwin:meta_alt']"
```

#### Multiple Options
```bash
# Combine multiple options
gsettings set org.gnome.desktop.input-sources xkb-options "['caps:escape', 'lv3:ralt_switch', 'terminate:ctrl_alt_bksp']"
```

### Creating Custom Layouts

To create a completely custom layout:

1. **Study existing layouts**: Look in `/usr/share/X11/xkb/symbols/`
2. **Create your layout file**: Based on existing examples
3. **Test with xkbcomp**: Compile and test your layout
4. **Install system-wide**: Copy to `/usr/share/X11/xkb/symbols/` (requires sudo)
5. **Register the layout**: Add entry to `/usr/share/X11/xkb/rules/evdev.xml`

Example custom layout structure:
```xkb
// Custom layout in /usr/share/X11/xkb/symbols/custom

default partial alphanumeric_keys
xkb_symbols "basic" {
    name[Group1]= "My Custom Layout";
    
    // Define your key mappings here
    key <TLDE> { [grave, asciitilde] };
    key <AE01> { [1, exclam] };
    // ... more key definitions
    
    include "level3(ralt_switch)"
};
```

## Common Issues and Solutions

### Issue: Layout Changes Don't Persist After Reboot

**Symptoms**: Keyboard reverts to US layout after restart.

**Solutions**:
1. **Check system settings**: Ensure `localectl` is configured:
   ```bash
   sudo localectl set-keymap se
   sudo localectl set-x11-keymap se
   ```

2. **Verify GNOME settings persistence**: 
   ```bash
   dconf dump /org/gnome/desktop/input-sources/
   ```

3. **For Nix users**: Ensure configuration rebuilds on boot
4. **For traditional users**: Check that the settings service is enabled:
   ```bash
   systemctl --user status gnome-session-manager
   ```

### Issue: Different Layouts in Different Applications

**Root Cause**: Wayland vs XWayland applications handle input differently.

**Solutions**:
1. **Clean X11 configs**: Remove conflicting configurations:
   ```bash
   sudo rm -f /etc/X11/xorg.conf.d/*keyboard*
   ```

2. **Verify session type**:
   ```bash
   echo $XDG_SESSION_TYPE  # Should be "wayland"
   ```

3. **Use GNOME's settings exclusively**: Don't mix `setxkbmap` commands with GNOME settings

### Issue: Cannot Switch Between Layouts

**Symptoms**: Super+Space doesn't work, or only one layout appears available.

**Check and Fix**:
```bash
# Verify multiple layouts configured
gsettings get org.gnome.desktop.input-sources sources
# Should show multiple entries

# Check switching shortcut
gsettings get org.gnome.desktop.wm.keybindings switch-input-source

# Reset if needed
gsettings reset org.gnome.desktop.wm.keybindings switch-input-source
```

### Issue: Special Characters Don't Work

**Symptoms**: Cannot type €, @, accented letters with AltGr.

**Solutions**:
```bash
# Set Right Alt as AltGr
gsettings set org.gnome.desktop.input-sources xkb-options "['lv3:ralt_switch']"

# Test AltGr functionality
# Try: AltGr+4 for € (on many European layouts)
# Try: AltGr+2 for @ (on many layouts)
```

### Issue: Keyboard Layout Appears Correct But Types Wrong Characters

**Possible Causes**:
1. **Wrong variant selected**: Check if you need a specific variant (e.g., `se+svdvorak` vs just `se`)
2. **Conflicting keyboard software**: Other input method software interfering
3. **Application-specific issues**: Some applications override system settings

**Solutions**:
```bash
# Check exact layout and variant
setxkbmap -query

# Example: If you want Swedish Dvorak but only have basic Swedish
gsettings set org.gnome.desktop.input-sources sources "[('xkb', 'se+svdvorak'), ('xkb', 'se')]"

# Test in different applications (terminal, text editor, browser)
# If behavior differs, you may have application-specific overrides

# Reset to basic layout first
gsettings set org.gnome.desktop.input-sources sources "[('xkb', 'se')]"
```

### Issue: Home Manager/Nix Rebuild Fails

**Common Causes and Solutions**:

1. **Syntax errors in .nix files**:
   ```bash
   nix flake check ~/.nix-config
   ```

2. **Missing dependencies**:
   ```bash
   nix develop ~/.nix-config
   ```

3. **Permission issues**:
   ```bash
   # Check ownership of .nix-config
   ls -la ~/.nix-config
   ```

4. **Cache issues**:
   ```bash
   # Clear nix cache if needed
   sudo nix-collect-garbage -d
   ```

## Reference Tables

### Keyboard Layout File Paths

| Path | Description | Scope | Priority |
|------|-------------|-------|----------|
| `/usr/share/X11/xkb/symbols/` | Standard XKB keyboard layout definitions | System-wide | Low |
| `/usr/share/X11/xkb/rules/evdev.xml` | XKB layout registry and metadata | System-wide | Low |
| `/etc/X11/xorg.conf.d/00-keyboard.conf` | X11 keyboard configuration | System-wide | Medium |
| `/etc/vconsole.conf` | Virtual console keyboard layout | System-wide | Medium |
| `/etc/locale.conf` | System locale and keyboard settings | System-wide | Medium |
| `/etc/dconf/db/gdm.d/00-keyboard-layout` | GDM login screen keyboard settings | Login screen | High |
| `/etc/environment` | Environment variables including XKB settings | System-wide | Medium |
| `~/.config/dconf/user` | User's GNOME settings database | User session | High |
| `~/.xkb/` | User-specific custom XKB layouts | User session | High |
| `~/.Xmodmap` | Legacy X11 key remapping (discouraged) | User session | Low |
| `~/.profile` | User environment variables | User session | Medium |
| `~/.nix-config/desktop/keyboard.nix` | Nix/Home Manager keyboard config | User session | High |
| `/tmp/xkb_*.xkm` | Compiled XKB keymaps | Runtime | Temporary |

### XKB Component Paths

| Path | Description | Contains |
|------|-------------|----------|
| `/usr/share/X11/xkb/keycodes/` | Key code definitions | Physical key mappings |
| `/usr/share/X11/xkb/geometry/` | Keyboard physical layout | Visual representations |
| `/usr/share/X11/xkb/types/` | Key type definitions | Modifier behavior |
| `/usr/share/X11/xkb/compat/` | Compatibility mappings | Legacy support |
| `/usr/share/X11/xkb/rules/` | Layout rules and configurations | Layout combinations |

### Keyboard Layout Commands

| Command | Description | Example Usage | Persistence |
|---------|-------------|---------------|-------------|
| `setxkbmap -layout se` | Set keyboard layout for current X session | `setxkbmap -layout se,us -option grp:alt_shift_toggle` | Session only |
| `setxkbmap -query` | Display current keyboard configuration | `setxkbmap -query` | Read-only |
| `localectl set-keymap se` | Set system-wide console keyboard layout | `sudo localectl set-keymap se` | Permanent |
| `localectl set-x11-keymap se` | Set system-wide X11 keyboard layout | `sudo localectl set-x11-keymap se pc105 '' terminate:ctrl_alt_bksp` | Permanent |
| `localectl list-keymaps` | List available keyboard layouts | `localectl list-keymaps \| grep se` | Read-only |
| `gsettings set org.gnome.desktop.input-sources sources` | Configure GNOME keyboard layouts | `gsettings set ... sources "[('xkb', 'se'), ('xkb', 'us')]"` | Permanent |
| `gsettings get org.gnome.desktop.input-sources sources` | Show current GNOME keyboard layouts | `gsettings get org.gnome.desktop.input-sources sources` | Read-only |
| `dconf dump /org/gnome/desktop/input-sources/` | Export GNOME keyboard settings | `dconf dump /org/gnome/desktop/input-sources/` | Read-only |
| `dconf reset -f /org/gnome/desktop/input-sources/` | Reset GNOME keyboard settings | `dconf reset -f /org/gnome/desktop/input-sources/` | Destructive |
| `xkbcomp layout.xkb $DISPLAY` | Compile and load custom XKB layout | `xkbcomp -v my-layout.xkb $DISPLAY` | Session only |
| `gnome-control-center region` | Open GNOME keyboard settings GUI | `gnome-control-center region` | GUI tool |

### Debugging and Analysis Commands

| Command | Description | Use Case |
|---------|-------------|----------|
| `showkey -s` | Show keyboard scan codes | Debug hardware key detection |
| `xev` | Monitor X11 keyboard events | Test key mappings and events |
| `evtest` | Monitor input device events | Low-level input debugging |
| `xinput list` | List input devices | Identify keyboard devices |
| `lsusb` | List USB devices including keyboards | Hardware troubleshooting |
| `dmesg \| grep -i keyboard` | Show kernel keyboard messages | Hardware/driver issues |
| `journalctl -f \| grep -i keyboard` | Monitor real-time keyboard logs | Runtime troubleshooting |
| `cat /proc/bus/input/devices` | Show input device information | Device identification |

### XKB Inspection Commands

| Command | Description | Output |
|---------|-------------|--------|
| `xkbcomp $DISPLAY output.xkb` | Export current XKB configuration | Complete keymap definition |
| `setxkbmap -print` | Show XKB components for current layout | Component names and rules |
| `xkbcomp -xkb $DISPLAY` | Display XKB configuration in readable format | Human-readable keymap |
| `localectl list-x11-keymap-layouts` | List available X11 layouts | Layout names |
| `localectl list-x11-keymap-variants se` | List variants for specific layout | Variant names for layout |
| `localectl list-x11-keymap-options` | List available XKB options | All option categories |

### GNOME-Specific Commands

| Command | Description | Schema |
|---------|-------------|--------|
| `gsettings list-schemas \| grep input` | Find input-related settings schemas | Available configuration areas |
| `gsettings list-keys org.gnome.desktop.input-sources` | List all input source settings | All configurable options |
| `gsettings range org.gnome.desktop.input-sources sources` | Show valid values for sources setting | Allowed input types |
| `dconf watch /org/gnome/desktop/input-sources/` | Monitor changes to input sources | Real-time change monitoring |

### Emergency and Recovery Commands

| Command | Description | When to Use |
|---------|-------------|-------------|
| `loadkeys us` | Set console keyboard to US layout | When GUI is inaccessible |
| `gsettings set org.gnome.desktop.a11y.applications screen-keyboard-enabled true` | Enable on-screen keyboard | When physical keyboard doesn't work |
| `gsettings reset-recursively org.gnome.desktop.input-sources` | Reset all keyboard settings | When configuration is completely broken |
| `sudo systemctl restart gdm` | Restart display manager | When login screen keyboard is wrong |
| `pkill -HUP gnome-shell` | Restart GNOME Shell | When keyboard settings don't apply |

## Reference Commands

### Status Checking
```bash
# Current keyboard state
setxkbmap -query                # X11/XWayland layout info
localectl status               # System-wide settings
gsettings get org.gnome.desktop.input-sources sources  # GNOME layouts
gsettings get org.gnome.desktop.input-sources xkb-options  # GNOME options

# Display server info
echo $XDG_SESSION_TYPE         # Should be "wayland" for modern GNOME
echo $WAYLAND_DISPLAY          # Wayland display socket

# Available layouts
localectl list-keymaps         # System keymaps
ls /usr/share/X11/xkb/symbols/ # Available XKB layouts
```

### Quick Configuration Commands
```bash
# Set dual layout (Swedish example)
gsettings set org.gnome.desktop.input-sources sources "[('xkb', 'se'), ('xkb', 'us')]"

# Common XKB options
gsettings set org.gnome.desktop.input-sources xkb-options "['terminate:ctrl_alt_bksp', 'lv3:ralt_switch']"

# Reset to defaults
gsettings reset org.gnome.desktop.input-sources sources
gsettings reset org.gnome.desktop.input-sources xkb-options

# Force layout switch (GNOME)
gsettings set org.gnome.desktop.input-sources current 0  # First layout
gsettings set org.gnome.desktop.input-sources current 1  # Second layout

# System-wide configuration
sudo localectl set-keymap se
sudo localectl set-x11-keymap se
```

### Emergency Recovery
```bash
# If keyboard is completely broken:

# 1. Enable on-screen keyboard
gsettings set org.gnome.desktop.a11y.applications screen-keyboard-enabled true

# 2. Or open GNOME Settings → Accessibility → Screen Keyboard

# 3. Reset all keyboard settings
gsettings reset-recursively org.gnome.desktop.input-sources

# 4. Set basic US layout to regain functionality
gsettings set org.gnome.desktop.input-sources sources "[('xkb', 'us')]"
```

### Debugging Commands
```bash
# Check for conflicting configurations
ls -la /etc/X11/xorg.conf.d/*keyboard* 2>/dev/null
cat /etc/environment | grep -i xkb

# Test XKB compilation (for custom layouts)
xkbcomp -v /path/to/layout.xkb $DISPLAY

# Monitor GNOME settings changes
dconf watch /org/gnome/desktop/input-sources/

# Check running keyboard-related processes
ps aux | grep -E "(ibus|fcitx|input|keyboard)" | grep -v grep
```

## Reference Tables

### Keyboard Layout Paths

| Path | Description | Type | Purpose |
|------|-------------|------|---------|
| `/usr/share/X11/xkb/symbols/` | System XKB layout definitions | Directory | Contains all available keyboard layout files (se, us, de, etc.) |
| `/usr/share/X11/xkb/rules/evdev.xml` | XKB layout registry | File | Defines which layouts and variants are available to the system |
| `/usr/share/X11/xkb/rules/evdev.lst` | XKB layout list | File | Human-readable list of all layouts, variants, and options |
| `/etc/X11/xorg.conf.d/00-keyboard.conf` | X11 keyboard configuration | File | System-wide X11 keyboard settings (can conflict with Wayland) |
| `/etc/environment` | System environment variables | File | Can contain XKB_DEFAULT_* variables for system-wide defaults |
| `/etc/locale.conf` | System locale settings | File | Contains LANG and keyboard-related locale settings |
| `/etc/vconsole.conf` | Virtual console configuration | File | Keyboard layout for text-mode consoles (TTY) |
| `/etc/dconf/db/gdm.d/` | GDM configuration directory | Directory | GNOME Display Manager keyboard settings for login screen |
| `/etc/dconf/db/gdm.d/00-keyboard-layout` | GDM keyboard config | File | Specific keyboard layout configuration for login screen |
| `~/.config/dconf/user` | User GNOME settings database | File | Binary database containing all GNOME settings including keyboard |
| `~/.config/autostart/` | User autostart applications | Directory | Contains .desktop files for applications that start with session |
| `~/.xkb/` | User custom XKB directory | Directory | Location for user-specific custom XKB layouts and compilations |
| `~/.nix-config/desktop/keyboard.nix` | Nix keyboard configuration | File | Home Manager keyboard layout configuration (Nix-specific) |
| `~/.nix-config/extras/custom-keyboard-layout.xkb` | Custom XKB layout | File | User-defined custom keyboard layout with special behaviors |
| `/tmp/xkb_error.log` | XKB compilation errors | File | Error log from failed XKB layout compilation attempts |
| `/var/lib/gdm/.config/dconf/user` | GDM user settings | File | GDM's own dconf database for display manager settings |

### Keyboard Layout Commands

| Command | Description | Usage Example | Purpose |
|---------|-------------|---------------|---------|
| `gsettings get org.gnome.desktop.input-sources sources` | Get current GNOME keyboard layouts | `gsettings get org.gnome.desktop.input-sources sources` | Check which layouts are configured in GNOME |
| `gsettings set org.gnome.desktop.input-sources sources` | Set GNOME keyboard layouts | `gsettings set org.gnome.desktop.input-sources sources "[('xkb', 'se'), ('xkb', 'us')]"` | Configure multiple keyboard layouts |
| `gsettings get org.gnome.desktop.input-sources xkb-options` | Get XKB options | `gsettings get org.gnome.desktop.input-sources xkb-options` | Check current keyboard behavior options |
| `gsettings set org.gnome.desktop.input-sources xkb-options` | Set XKB options | `gsettings set org.gnome.desktop.input-sources xkb-options "['caps:escape']"` | Configure special key behaviors |
| `gsettings reset org.gnome.desktop.input-sources sources` | Reset layouts to default | `gsettings reset org.gnome.desktop.input-sources sources` | Clear all keyboard layout configuration |
| `gsettings reset-recursively org.gnome.desktop.input-sources` | Reset all keyboard settings | `gsettings reset-recursively org.gnome.desktop.input-sources` | Complete reset of keyboard configuration |
| `setxkbmap -query` | Query current X11 layout | `setxkbmap -query` | Show active layout for X11/XWayland applications |
| `setxkbmap se` | Set X11 layout | `setxkbmap se` | Temporarily change X11 keyboard layout |
| `setxkbmap -print` | Print current XKB configuration | `setxkbmap -print` | Show detailed XKB keymap information |
| `localectl status` | Show system locale/keyboard | `localectl status` | Display system-wide keyboard and locale settings |
| `localectl list-keymaps` | List available keymaps | `localectl list-keymaps` | Show all system keyboard layouts |
| `localectl set-keymap` | Set system keymap | `sudo localectl set-keymap se` | Configure system-wide keyboard layout |
| `localectl set-x11-keymap` | Set X11 keymap | `sudo localectl set-x11-keymap se` | Configure X11-specific keyboard layout |
| `xkbcomp -v layout.xkb $DISPLAY` | Compile XKB layout | `xkbcomp -v ~/.config/my-layout.xkb $DISPLAY` | Load custom keyboard layout |
| `xkbcomp $DISPLAY output.xkb` | Export current layout | `xkbcomp $DISPLAY current-layout.xkb` | Save current keyboard configuration to file |
| `dconf dump /org/gnome/desktop/input-sources/` | Dump keyboard settings | `dconf dump /org/gnome/desktop/input-sources/` | Export all GNOME keyboard configuration |
| `dconf load /org/gnome/desktop/input-sources/` | Load keyboard settings | `dconf load /org/gnome/desktop/input-sources/ < backup.conf` | Import keyboard configuration from file |
| `dconf watch /org/gnome/desktop/input-sources/` | Monitor setting changes | `dconf watch /org/gnome/desktop/input-sources/` | Watch for real-time keyboard setting changes |
| `dconf reset -f /org/gnome/desktop/input-sources/` | Reset dconf keyboard settings | `dconf reset -f /org/gnome/desktop/input-sources/` | Force reset all keyboard-related dconf settings |
| `gnome-control-center region` | Open GNOME keyboard settings | `gnome-control-center region` | Launch GUI for keyboard layout configuration |
| `sudo dconf update` | Update system dconf database | `sudo dconf update` | Apply changes to system-wide dconf settings (GDM) |
| `loadkeys se` | Load console keymap | `sudo loadkeys se` | Set keyboard layout for text console (TTY) |
| `showkey` | Display key codes | `showkey` | Show scancodes and keycodes for pressed keys |
| `showkey -a` | Display ASCII codes | `showkey -a` | Show ASCII values for pressed keys |
| `xev` | X11 event viewer | `xev` | Monitor keyboard events in X11 (useful for debugging) |
| `evtest` | Input event tester | `sudo evtest` | Low-level keyboard event monitoring |
| `xinput list` | List input devices | `xinput list` | Show all input devices including keyboards |
| `xinput test` | Test input device | `xinput test <device-id>` | Monitor events from specific input device |
| `lsinput` | List input devices | `lsinput` | Display detailed information about input devices |
| `systemctl --user restart gnome-session-manager` | Restart GNOME session | `systemctl --user restart gnome-session-manager` | Reload GNOME settings without full logout |
| `killall gnome-shell` | Restart GNOME Shell | `killall gnome-shell` | Force restart of GNOME Shell (Alt+F2, r, Enter is safer) |
| `nix run .#homeConfigurations.$USER.activationPackage` | Rebuild Home Manager | `cd ~/.nix-config && nix run .#homeConfigurations.$USER.activationPackage` | Apply Nix/Home Manager configuration changes |

## Conclusion

Keyboard layout configuration on Linux/Fedora/GNOME involves multiple layers that need to work together:

1. **System layer**: `localectl` and `/etc/` configurations
2. **Display server layer**: X11/Wayland input handling  
3. **Desktop environment layer**: GNOME's input source management
4. **Application layer**: Individual app keyboard handling

### Best Practices

1. **Use GNOME Settings first**: For most users, the GUI settings are sufficient and most reliable
2. **Avoid mixing tools**: Don't combine `setxkbmap`, `localectl`, and `gsettings` - pick one approach
3. **Test thoroughly**: Check behavior in multiple applications (terminal, browser, text editor)
4. **Document your setup**: Keep notes on what works for your specific use case
5. **Start simple**: Begin with standard layouts before attempting custom configurations

### For Different User Types

- **Casual users**: Use GNOME Settings GUI → Region & Language
- **Power users**: Use `gsettings` commands for scripting and automation  
- **System administrators**: Use `localectl` for system-wide configuration
- **Advanced users**: Create custom XKB layouts for specialized needs
- **Nix users**: Use Home Manager for declarative configuration management

### When Things Go Wrong

1. **Start with status commands** to understand current state
2. **Reset to a known good state** (usually US layout)
3. **Make changes incrementally** and test each step
4. **Check logs** (`journalctl`) for error messages
5. **Consider environment differences** (Wayland vs X11, different applications)

This guide covers the most common scenarios for keyboard layout configuration on modern Linux systems. While specific examples focus on Swedish layouts (including the svdvorak variant) and Nix configurations, the principles and troubleshooting steps apply universally to any layout and any Fedora/GNOME system.

Remember that keyboard layout configuration can be complex due to the interaction between multiple system layers. When troubleshooting, patience and systematic testing are key to finding solutions that work reliably across your entire system.
