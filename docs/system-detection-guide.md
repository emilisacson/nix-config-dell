# System Detection Guide

This guide explains the JSON-based system detection architecture used in this Nix Home Manager configuration to automatically adapt to different hardware setups.

## Overview

The system uses a two-phase detection approach:

1. **Pre-build Detection**: `extras/detect-system-specs.sh` analyzes the current system and generates `system-specs.json`
2. **Build-time Configuration**: `lib/system-specs.nix` reads the JSON file and provides specifications to all modules

This architecture ensures reliable builds while enabling full hardware-specific customization.

## Architecture

### Detection Script (`extras/detect-system-specs.sh`)
The detection script collects comprehensive system information:

- **Hardware**: CPU, memory, storage, GPU details
- **System**: OS, kernel, architecture, hostname
- **Displays**: Monitor count, resolutions, orientations, panel IDs
- **Platform**: Laptop detection, vendor identification

### System Specs Module (`lib/system-specs.nix`)
Reads the JSON file and provides:

- Raw system specifications as `config.systemSpecs.*`
- Computed GPU detection functions: `hasNvidiaGPU`, `hasIntelGPU`, `hasAMDGPU`
- Monitor configuration data for display setup
- Strict validation that fails build if JSON is missing

### System Info Module (`lib/system-info.nix`)
Displays detection results during Home Manager activation with:

- JSON-based system specifications
- Hardware detection status
- Monitor configuration summary
- Clear three-section output format

## Usage

### Initial Setup

1. **Run detection script** to generate system specifications:
   ```bash
   cd ~/.nix-config
   ./extras/detect-system-specs.sh
   ```

2. **Build configuration** using the detected specifications:
   ```bash
   NIXPKGS_ALLOW_UNFREE=1 nix run --impure .#homeConfigurations.$USER.activationPackage
   ```

### Updating Detection

Re-run the detection script when your hardware changes:
```bash
cd ~/.nix-config
./extras/detect-system-specs.sh
NIXPKGS_ALLOW_UNFREE=1 nix run --impure .#homeConfigurations.$USER.activationPackage
```

## System Specifications Structure

The `system-specs.json` file contains:

```json
{
  "hostname": "fedora",
  "os_name": "Fedora Linux", 
  "os_version": "42 (Workstation Edition)",
  "architecture": "x86_64",
  "kernel": "6.14.8-300.fc42.x86_64",
  "cpu_model": "Intel(R) Core(TM) i7-10610U CPU @ 1.80GHz",
  "cpu_cores": 8,
  "cpu_vendor": "GenuineIntel",
  "gpus": [
    {
      "vendor": "intel|nvidia|amd",
      "model": "GPU model name",
      "full_description": "Complete lspci output"
    }
  ],
  "displays": {
    "count": 1,
    "monitors": [
      {
        "name": "eDP-1",
        "width": 1920,
        "height": 1080,
        "orientation": "landscape|portrait",
        "panel_id": "AUO-0x00000000"
      }
    ],
    "primary": "eDP-1"
  },
  "memory_gb": 31,
  "storage": [...],
  "is_laptop": true,
  "system_id": "laptop-Latitude_7410-intel"
}
```

## Available Configuration Options

### In Nix Modules

Access system specifications in your modules:

```nix
{ config, pkgs, lib, ... }:

{
  # Basic system information
  home.sessionVariables = {
    DETECTED_SYSTEM = config.systemSpecs.system_id;
    DETECTED_HOSTNAME = config.systemSpecs.hostname;
  };

  # GPU-specific configuration
  home.packages = with pkgs; []
    ++ lib.optionals config.systemSpecs.hasNvidiaGPU [
      # NVIDIA-specific packages
      cudaPackages.cuda_cudart
      nvidia-settings
    ]
    ++ lib.optionals config.systemSpecs.hasIntelGPU [
      # Intel GPU tools
      intel-gpu-tools
    ];

  # Monitor-specific configuration
  programs.some-app.config = {
    window-position = if (builtins.length config.systemSpecs.displays.monitors) > 1 
      then "multi-monitor" 
      else "single-monitor";
  };

  # Laptop-specific settings
  services.auto-cpufreq.enable = config.systemSpecs.is_laptop;

  # OS-specific configuration
  home.file.".config/app/settings.conf".text = 
    if lib.hasPrefix "Fedora" config.systemSpecs.os_name then
      "fedora-specific-config"
    else
      "default-config";
}
```

### Computed Values

The system provides these computed boolean values:

- `config.systemSpecs.hasNvidiaGPU` - System has NVIDIA GPU
- `config.systemSpecs.hasIntelGPU` - System has Intel GPU  
- `config.systemSpecs.hasAMDGPU` - System has AMD GPU

### Monitor Configuration

Monitor information is available as:

- `config.systemSpecs.displays.count` - Number of monitors
- `config.systemSpecs.displays.primary` - Primary monitor name
- `config.systemSpecs.displays.monitors` - Array of monitor objects

## Automatic Configuration

### Monitor-Aware Applications

Applications can automatically adapt to detected monitor configurations:

- **Single monitor setups**: Optimized window layouts
- **Multi-monitor setups**: Extended workspace configurations
- **Portrait monitors**: Adjusted panel positioning
- **High-resolution displays**: Automatic scaling adjustments

## System Detection Report

During Home Manager activation, you'll see a detailed report:

```
📋 System Detection Report
==========================

Detection Method:
  ✅ JSON-based system detection active

System Specifications:
  • System ID: laptop-Latitude_7410-intel  
  • Hostname: fedora
  • OS: Fedora Linux 42 (Workstation Edition)
  • Architecture: x86_64
  • CPU: Intel(R) Core(TM) i7-10610U CPU @ 1.80GHz (8 cores)
  • Memory: 31 GB
  • Laptop: Yes

GPU Detection:
  ✅ Intel GPU detected

Monitor Configuration:
  • Monitor count: 1
  • Primary monitor: eDP-1 (1920x1080, landscape)
```

This report shows:
- **Detection Method**: Confirms JSON-based system is active
- **System Specifications**: Hardware and OS details detected at build-time  
- **Monitor Configuration**: Display setup used for application configuration

## Hardware Support

### GPU Detection

The system detects GPUs using multiple methods:

1. **lspci** - Primary method for PCI device enumeration
2. **DRM devices** - Hardware-level detection via `/sys/class/drm`
3. **PCI vendor IDs** - Direct vendor ID checks in `/sys/bus/pci/devices`
4. **Driver files** - Checks for installed drivers (NVIDIA)

Supported GPU vendors:
- **Intel** - Integrated graphics (most common)
- **NVIDIA** - Dedicated/hybrid graphics
- **AMD** - Dedicated/integrated graphics

### Monitor Detection

Monitor detection uses multiple fallback methods:

1. **xrandr** - X11 display information (preferred method)
   - Gets resolution, orientation, and connection status
   - Attempts panel ID extraction from EDID data
2. **GNOME Display Config (gdbus)** - Desktop environment method
   - Queries GNOME Mutter display configuration
   - Reliable source for panel manufacturer and product IDs
3. **DRM connector data** - Direct hardware queries
   - Fallback when X11 is not available

**Panel ID Detection Process:**
1. **GNOME gdbus method** - Primary method using `org.gnome.Mutter.DisplayConfig.GetCurrentState`
   - Extracts vendor (e.g., "AUO") and panel ID (e.g., "0x00000000") 
   - Combines them in format: "AUO-0x00000000"
2. **EDID reading** - Fallback methods:
   - DRM EDID files: `/sys/class/drm/card*-{monitor}/edid`
   - i2c direct reading (if available)
3. **Vendor-specific fallbacks** - For known laptop models when EDID fails

Detected monitor properties:
- **Connection name** (eDP-1, HDMI-1, DP-1, etc.)
- **Resolution** (width x height in pixels)
- **Orientation** (landscape/portrait)
- **Panel ID** (vendor-product format like "AUO-0x00000000")
- **Primary status** (which monitor is primary)

### Storage Detection

Storage device detection includes:

1. **lsblk JSON output** - Primary method for device enumeration
2. **Sysfs model files** - Fallback for device model information
   - Reads from `/sys/block/{device}/device/model`
   - Handles cases where lsblk returns null models
3. **Special device handling** - Virtual devices like zram

Detected storage properties:
- **Device name** (nvme0n1, sda, etc.)
- **Size** (in human-readable format)
- **Model** (manufacturer and model name)
  - Example: "Micron 2300 NVMe 1024GB", "Ultra Fit"
  - Virtual devices labeled as "zram (virtual)"

### Platform Detection

System platform detection includes:

- **Laptop identification** - DMI chassis type and battery presence
- **Vendor detection** - Dell, Lenovo, HP, etc.
- **Model identification** - Specific laptop/desktop models
- **Architecture** - x86_64, aarch64, etc.

## Troubleshooting

### Re-running Detection

If hardware changes or detection seems incorrect:

```bash
cd ~/.nix-config
./extras/detect-system-specs.sh
NIXPKGS_ALLOW_UNFREE=1 nix run --impure .#homeConfigurations.$USER.activationPackage
```

### Manual Inspection

Check detection results:

```bash
# View current system specifications
cat ~/.nix-config/system-specs.json | jq .

# Test detection script manually
cd ~/.nix-config
bash -x ./extras/detect-system-specs.sh

# Check hardware directly
lspci | grep -i "vga\|display"        # Graphics cards
xrandr --query                        # Connected monitors
cat /sys/class/dmi/id/sys_vendor      # System vendor
cat /sys/class/dmi/id/product_name    # System model
```

### Common Issues

**Problem**: Build fails with "system-specs.json does not exist" error
**Solution**: Run the detection script to generate the required file:
```bash
cd ~/.nix-config
./extras/detect-system-specs.sh
```

**Problem**: Wrong hardware detected after system changes
**Solution**: Re-run detection to update system specifications:
```bash
cd ~/.nix-config
./extras/detect-system-specs.sh
NIXPKGS_ALLOW_UNFREE=1 nix run --impure .#homeConfigurations.$USER.activationPackage
```

**Problem**: GPU detection mismatch
**Solution**: Check available detection tools and re-run:
```bash
# Install missing tools if needed
sudo dnf install pciutils  # For lspci
sudo dnf install xrandr    # For monitor detection

# Re-run detection
cd ~/.nix-config
./extras/detect-system-specs.sh
```

### Debug Mode

Enable verbose output in detection script:
```bash
cd ~/.nix-config
DEBUG=1 ./extras/detect-system-specs.sh
```

### Recent Fixes Applied

**Panel ID Detection Fix (June 2025):**
- **Issue**: Panel IDs were hardcoded as "eDP-1" instead of extracting real panel information
- **Solution**: Implemented gdbus-based extraction from GNOME display configuration
- **Result**: Panel IDs now correctly show as "AUO-0x00000000" format with real manufacturer data

**Storage Model Detection Fix (June 2025):**
- **Issue**: Storage device models were showing as "null" even when model information was available
- **Solution**: Added fallback to `/sys/block/{device}/device/model` when lsblk returns null
- **Result**: Storage devices now show proper models like "Micron 2300 NVMe 1024GB"

**Network Interface Detection Fix (June 2025):**
- **Issue**: Network interfaces with "lo" in their name (like "wlo1") were incorrectly filtered out
- **Solution**: Changed filter from `grep -v "lo"` to `grep -v "^lo$"` to only exclude exact "lo" interface
- **Result**: Wireless interfaces like "wlo1" are now properly detected

## Integration Examples

### Application Configuration

Example of application adapting to detected hardware:

```nix
# applications/obs-studio.nix
{ config, pkgs, lib, nixgl, ... }:

{
  home.packages = with pkgs; [
    (if config.systemSpecs.hasNvidiaGPU then
      # Use NVIDIA-optimized OBS with hardware encoding
      nixgl.nixGLNvidia obs-studio
    else
      # Use standard OBS with software encoding
      nixgl.nixGLIntel obs-studio
    )
  ];

  # OBS configuration based on detected hardware
  home.file.".config/obs-studio/basic/profiles/main/basic.ini".text = ''
    [Video]
    OutputCX=${toString (builtins.head config.systemSpecs.displays.monitors).width}
    OutputCY=${toString (builtins.head config.systemSpecs.displays.monitors).height}
    
    [AdvOut]
    Encoder=${if config.systemSpecs.hasNvidiaGPU then "ffmpeg_nvenc" else "obs_x264"}
  '';
}
```

### Desktop Environment Setup

```nix
# desktop/gnome.nix 
{ config, pkgs, lib, ... }:

{
  dconf.settings = {
    # Multi-monitor workspaces for systems with multiple displays
    "org/gnome/mutter" = lib.mkIf (config.systemSpecs.displays.count > 1) {
      workspaces-only-on-primary = false;
    };
    
    # Power management for laptops
    "org/gnome/settings-daemon/plugins/power" = lib.mkIf config.systemSpecs.is_laptop {
      sleep-inactive-ac-timeout = 3600;
      sleep-inactive-battery-timeout = 1800;
    };
    
    # Scale factor based on monitor resolution
    "org/gnome/desktop/interface" = {
      scaling-factor = 
        let firstMonitor = builtins.head config.systemSpecs.displays.monitors;
        in if firstMonitor.width >= 3840 then 2 else 1;
    };
  };
}
```

## File Structure

```
~/.nix-config/
├── extras/
│   └── detect-system-specs.sh     # Detection script
├── lib/
│   ├── system-specs.nix           # JSON reader module
│   └── system-info.nix            # Status display module
├── system-specs.json              # Generated specifications
└── docs/
    └── system-detection-guide.md  # This documentation
```

## Migration from Old System

If migrating from the old `systemConfig` parameter approach:

1. **Remove old references**: Update modules to use `config.systemSpecs` instead of `systemConfig` parameters
2. **Run detection**: Generate initial `system-specs.json` file
3. **Clean up**: Remove old override files and detection modules
4. **Test**: Verify all functionality works with new architecture

The new system provides the same functionality with better reliability, maintainability, and clearer error handling when the JSON file is missing.
