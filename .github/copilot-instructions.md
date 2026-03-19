# Nix Home Manager Configuration - AI Coding Guide

## 🏗️ Architecture Overview

The intended system use Fedora 42 WE with Gnome and use Nix Flakes and Home Manager to manage the system.

This is a **hardware-adaptive** Nix Home Manager configuration with automatic system detection. The core innovation is a **two-phase detection system**: bash script generates `system-specs.json` → Nix reads JSON at build time.

### Key Components
- `flake.nix` - Entry point with nixGL overlay for non-NixOS graphics support
- `home.nix` - Main config with desktop environment switching (`gnome`/`cosmic`)
- `lib/system-specs.nix` - JSON reader providing `config.systemSpecs.*` to all modules
- `lib/system-info.nix` - Real-time hardware report during Home Manager activation
- `extras/detect-system-specs.sh` - Hardware detection script (835 lines, comprehensive)

## 🔧 Essential Workflows

### Home Manager Rebuild
```bash
cd ~/.nix-config && NIXPKGS_ALLOW_UNFREE=1 nix run --impure "path:$HOME/.nix-config#homeConfigurations.$USER.activationPackage"
```

### System Detection (Required Before Build)
```bash
cd ~/.nix-config && ./extras/detect-system-specs.sh
```
Generates `system-specs.json` with GPU vendors, display panel IDs, system identifiers, etc.

## 📋 Hardware-Aware Patterns

### GPU Detection & nixGL Wrappers
Applications use `config.systemSpecs.hasNvidiaGPU`/`hasIntelGPU`/`hasAMDGPU` flags:

```nix
home.packages = with pkgs; [
  app-package
] ++ lib.optionals config.systemSpecs.hasNvidiaGPU [
  (nixgl.override { nvidiaVersion = "575.57.08"; }).auto.nixGLNvidia
] ++ lib.optionals config.systemSpecs.hasIntelGPU [
  nixgl.nixGLIntel
];
```

### System-Specific Application Lists
`applications/applications.nix` uses system ID mapping:
```nix
systemSpecificApps = {
  "laptop-20Y30016MX-hybrid" = [ pkgs.teams-for-linux ];
  "laptop-Latitude_7410-intel" = [ ];
};
```

### nixGL Wrapper Scripts
Graphics applications get wrapper scripts with fallback chains:
```nix
home.file.".local/bin/app-nixgl" = {
  text = ''#!/usr/bin/env bash
    if command -v nixGLNvidia-575.57.08 &> /dev/null; then
        exec nixGLNvidia-575.57.08 app "$@"
    elif command -v nixGLIntel &> /dev/null; then
        exec nixGLIntel app "$@"
    else
        exec app "$@"
    fi'';
  executable = true;
};
```

## 🎯 System Detection Internals

The detection script creates system IDs like `laptop-Latitude_7410-intel` using:
- Device type (`laptop`/`desktop`)
- Model name (from DMI data)
- GPU configuration (`intel`/`nvidia`/`hybrid`/`amd`)

Display detection extracts real panel IDs from EDID for GNOME extensions requiring specific monitor identification.

## 📁 Module Organization

- `applications/*.nix` - App configs with hardware-aware nixGL integration
- `desktop/*.nix` - DE configs (gnome.nix, cosmic.nix, nvidia.nix, performance.nix)
- `desktop/extensions/` - GNOME extension configurations
- `network/network.nix` - Network interface configuration
- `extras/` - Utility scripts and setup tools
- `lib/` - Core system detection and info display modules

## 🔍 Development Patterns

### Adding Hardware-Aware Applications
1. Add to `applications/applications.nix` imports
2. Create `applications/app-name.nix` with GPU detection
3. Include nixGL packages with version pinning for NVIDIA
4. Create wrapper scripts with fallback detection

### Desktop Environment Switching
Change `desktopEnvironment` variable in `home.nix` between `"gnome"` and `"cosmic"`.

### System-Specific Configurations
Use `config.systemSpecs.system_id` for exact system matching or individual flags like `config.systemSpecs.hasNvidiaGPU` for capability-based configuration.

When adding new modules, always consider hardware detection patterns and include appropriate nixGL support for graphics applications.
