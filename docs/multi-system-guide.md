# Multi-System Nix Configuration

This guide explains how to manage your Nix configuration across multiple systems with different hardware configurations.

## System Types

Your configuration supports multiple system types:

### Generic System Types
- **nvidia-intel** - For systems with both NVIDIA dedicated GPU and Intel integrated GPU
- **intel-only** - For systems with only Intel integrated GPU

### Vendor-Specific System Types
- **lenovo-MODEL-nvidia-intel** - For Lenovo laptops with a specific model and NVIDIA GPU
- **dell-MODEL-intel-only** - For Dell laptops with a specific model and Intel only GPU

## Automatic Detection

By default, your Nix configuration will automatically detect your system type based on:
1. Laptop vendor (Dell, Lenovo, etc.) from DMI information
2. Laptop model from DMI information  
3. GPU configuration (NVIDIA or Intel-only) using multiple detection methods

The system uses multiple GPU detection methods:
- **lspci** - Primary method for detecting NVIDIA GPUs
- **NVIDIA driver files** - Checks for `/proc/driver/nvidia`, `/dev/nvidia0`, `/dev/nvidiactl`
- **dmesg logs** - Searches kernel messages for NVIDIA references
- **PCI vendor IDs** - Checks `/sys/bus/pci/devices/*/vendor` for NVIDIA vendor ID (0x10de)
- **DRM devices** - Fallback method using `/sys/class/drm` for Intel/NVIDIA detection

## Manual Override System

You can manually override the detected system using the comprehensive `system-override.sh` script:

```bash
# Show current system status and override state
~/.nix-config/extras/system-override.sh show

# List all available system types
~/.nix-config/extras/system-override.sh list

# Set to specific system type
~/.nix-config/extras/system-override.sh set dell-Latitude_7410-intel-only
~/.nix-config/extras/system-override.sh set lenovo-ThinkPad_T14-nvidia-intel

# Quick test shortcuts
~/.nix-config/extras/system-override.sh test-nvidia    # Simulate NVIDIA system
~/.nix-config/extras/system-override.sh test-intel     # Simulate Intel-only system
~/.nix-config/extras/system-override.sh test-error     # Test error handling

# Clear override and return to automatic detection
~/.nix-config/extras/system-override.sh clear

# Rebuild configuration after changes
~/.nix-config/extras/system-override.sh rebuild
```

## Testing Detection

You can test the detection logic independently without affecting your configuration:

```bash
# Test current detection logic
~/.nix-config/extras/test-detection.sh

# Test detection with different override scenarios
~/.nix-config/extras/system-override.sh test
```

## How It Works

1. The system detection is performed in `lib/system-detection-fixed.nix`
2. It first checks for manual overrides in `$HOME/.nix-system-override`
3. It then detects system vendor and model using DMI information
4. GPU detection uses multiple methods (lspci, driver files, DRM devices, PCI vendor IDs)
5. System information is displayed during rebuilds by `lib/system-info.nix`
6. Each application module can use `systemConfig.hasNvidia`, `systemConfig.hasIntel`, `systemConfig.isLenovo`, `systemConfig.isDell`, and `systemConfig.laptopModel` to adjust its behavior
7. **No fallback behavior** - returns "unable-to-detect-*" when detection fails rather than guessing

## System Information Display

When you rebuild your configuration, you'll see detailed output like this:

```
╔═══════════════════════════════════════════════════╗
║ 🖥️  System Detection Report
╠═══════════════════════════════════════════════════╣
║ ✅ Successfully detected: dell Latitude_7410 (intel-only)
║ • Build-time system: dell-Latitude_7410-intel-only
║ • Configuration: System with only Intel integrated GPU
╠═══════════════════════════════════════════════════╣
║ 🔍 Runtime Detection:
║ • Vendor: Dell Inc.
║ • Model: Latitude 7410
║ • Laptop: Dell Latitude 7410
║ • GPU: Intel only [detected via DRM]
╚═══════════════════════════════════════════════════╝
```

This information shows both build-time detection (what Nix used during configuration) and runtime validation (what's actually detected on the current hardware).

## Error Handling

The system includes robust error handling:
- **No fallback behavior** - When detection fails, it clearly states "unable to detect" rather than guessing
- **Safe configurations** - Applications fall back to safe, compatible settings when system type is unknown
- **Clear error messages** - Both build-time and runtime errors are clearly displayed
- **Override capability** - Manual overrides allow testing and edge case handling

## Using Vendor and Model Information

You can use the system detection information in your configuration to apply laptop-specific settings:

```nix
{ pkgs, systemConfig, ... }:

{
  # Laptop-specific configuration
  home.packages = with pkgs; ([
    # Common packages for all systems
    base-packages  
  ] ++ lib.optionals (systemConfig.isLenovo) [
    # Lenovo-specific packages
    lenovo-specific-packages
  ] ++ lib.optionals (systemConfig.isDell) [
    # Dell-specific packages
    dell-specific-packages
  ]));
  
  # You can also check for specific laptop models
  programs.some-program.enable = 
    systemConfig.laptopModel == "XPS 13 9310";
    
  # Or combine GPU and laptop model checks
  home.file.".config/special-gpu-config" = {
    text = if (systemConfig.hasNvidia && systemConfig.isLenovo) then
      # Config for Lenovo with NVIDIA
      ''special config for Lenovo with NVIDIA''
    else if (systemConfig.isDell) then
      # Config for Dell laptops
      ''special config for Dell''
    else
      # Default config
      ''default config'';
  };
}
```

## Supported Applications

The following applications are configured to work correctly on both system types:

- OBS Studio - Uses different nixGL wrappers based on available GPU
- Other GPU-dependent applications (will be configured as needed)

## Troubleshooting

If you encounter issues with the system detection:

1. **Check what your system reports:**
   ```bash
   cat /sys/class/dmi/id/sys_vendor      # Should show laptop vendor (Dell Inc., LENOVO, etc.)
   cat /sys/class/dmi/id/product_name    # Should show laptop model (Latitude 7410, ThinkPad T14, etc.)
   lspci | grep -i nvidia                # Should show any NVIDIA GPU
   ls /sys/class/drm/                    # Check DRM devices for GPU detection
   ```

2. **Test detection independently:**
   ```bash
   ~/.nix-config/extras/test-detection.sh
   ```

3. **Check current override status:**
   ```bash
   ~/.nix-config/extras/system-override.sh show
   ```

4. **Use manual override for testing or edge cases:**
   ```bash
   ~/.nix-config/extras/system-override.sh set <system-type>
   ~/.nix-config/extras/system-override.sh rebuild
   ```

5. **Clear overrides to return to automatic detection:**
   ```bash
   ~/.nix-config/extras/system-override.sh clear
   ~/.nix-config/extras/system-override.sh rebuild
   ```

6. **Look at the detailed output during rebuild** to see both build-time and runtime detection results

## File Locations

- **Detection logic**: `lib/system-detection-fixed.nix`
- **Display system**: `lib/system-info.nix`  
- **Override file**: `$HOME/.nix-system-override`
- **Management script**: `extras/system-override.sh`
- **Testing script**: `extras/test-detection.sh`
