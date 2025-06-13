# OneNote Wine Setup Guide

## Overview

I've successfully created a comprehensive Wine-based OneNote configuration that provides maximum compatibility with corporate O365 accounts. This setup includes:

1. **OneNote via Wine** - Full Windows OneNote running in Wine with nixGL graphics support
2. **Automated Wine prefix management** - Handles Wine environment setup automatically
3. **Office Setup integration** - Installs OneNote via the current Microsoft Office installer
4. **Legacy OneNote 2016 support** - Fallback option for standalone OneNote 2016
5. **Multiple installation options** - Various ways to get OneNote working

## Available Commands

### Primary Commands
- `onenote-wine` - Launch OneNote via Wine (once installed)
- `onenote-wine-config` - Configure and manage Wine OneNote environment
- `onenote-2016-installer` - Download and install OneNote 2016 (legacy option)

### Configuration Commands
- `onenote-wine-config winecfg` - Open Wine configuration GUI
- `onenote-wine-config winetricks` - Install Windows components
- `onenote-wine-config install-onenote` - Show Office Setup installation guide
- `onenote-wine-config install-downloaded` - Install Office/OneNote from Downloads
- `onenote-wine-config reset` - Reset Wine prefix to clean state

## Installation Options

### Option 1: Office Setup (Current Method)
OneNote is now bundled with Microsoft Office. You need to download the Office Setup:

```bash
# Get the installation guide
onenote-wine-config install-onenote

# Download Office Setup from:
# https://go.microsoft.com/fwlink/?linkid=2110341

# Install after downloading
onenote-wine-config install-downloaded
```

### Option 2: OneNote 2016 (Legacy)
If you prefer the older standalone version, you can try the OneNote 2016 installer:

```bash
# This will attempt to download and install OneNote 2016
onenote-2016-installer
```

### Option 3: Manual Installation
1. Download Office Setup from Microsoft: https://go.microsoft.com/fwlink/?linkid=2110341
2. Save as `OfficeSetup.exe` to `~/Downloads/`
3. Install: `onenote-wine-config install-downloaded`
4. During Office installation, you can choose to install only OneNote

## Features

### Graphics Support
- **nixGL Integration**: Automatic detection and use of appropriate nixGL variant
- **Hardware Acceleration**: Works with NVIDIA and Intel graphics
- **Fallback Support**: Software rendering when needed

### Wine Environment
- **Dedicated Prefix**: OneNote runs in isolated Wine environment at `~/.wine-onenote`
- **Pre-configured**: Includes necessary Windows components (vcrun2019, dotnet48, etc.)
- **Easy Management**: Simple commands to configure, reset, or uninstall

### Corporate Compatibility
- **MFA Support**: Wine-based OneNote avoids the MFA authentication loops of p3x-onenote
- **Full Feature Support**: Access to all OneNote features including corporate notebooks
- **Offline Capability**: Works offline once notebooks are synced

## Troubleshooting

### First Run
When you first run `onenote-wine`, it will:
1. Create the Wine prefix at `~/.wine-onenote`
2. Install necessary Windows components via winetricks
3. Guide you through OneNote installation

### Common Issues
- **OneNote not found**: Download Office Setup from https://go.microsoft.com/fwlink/?linkid=2110341
- **Installation guide**: Run `onenote-wine-config install-onenote` for detailed instructions
- **Graphics issues**: The nixGL wrapper should handle most graphics problems
- **Wine configuration**: Use `onenote-wine-config winecfg` to adjust Wine settings
- **Office Setup vs OneNote**: Modern OneNote is bundled with Office - use Office Setup installer

### Reset/Uninstall
- **Reset Wine prefix**: `onenote-wine-config reset`
- **Complete removal**: `onenote-wine-config uninstall`

## Desktop Integration

The setup creates desktop entries for:
- **OneNote (Wine)** - Main launcher
- **OneNote Wine Config** - Configuration tool
- **Install OneNote 2016** - Quick installer

## File Locations
- **Wine Prefix**: `~/.wine-onenote/`
- **OneNote Install**: `~/.wine-onenote/drive_c/Program Files/Microsoft Office/`
- **User Data**: `~/.wine-onenote/drive_c/users/$USER/`

## Next Steps

1. **Download Office Setup**: Get the installer from https://go.microsoft.com/fwlink/?linkid=2110341
2. **Run the installation**: Use `onenote-wine-config install-downloaded` after downloading
3. **Choose OneNote only**: During Office installation, you can select to install only OneNote
4. **Configure Wine**: Use `onenote-wine-config winecfg` to optimize settings if needed
5. **Test with corporate account**: OneNote via Wine should handle corporate MFA properly

This Wine-based approach provides the most comprehensive solution for corporate OneNote usage on Linux!
