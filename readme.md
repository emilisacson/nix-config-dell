# Multi-System Nix Home Manager Configuration

A comprehensive Nix Home Manager configuration with **automatic hardware detection** that adapts to different laptop models and hardware configurations.

## 🚀 **Quick Start**

1. **Generate system specifications:**
   ```bash
   cd ~/.nix-config
   ./extras/detect-system-specs.sh
   ```

2. **Apply configuration:**
   ```bash
   cd ~/.nix-config
  NIXPKGS_ALLOW_UNFREE=1 nix run --impure "path:$HOME/.nix-config#homeConfigurations.$USER.activationPackage"
   ```

## ✨ **Features**

- **🔍 Automatic Hardware Detection**: Detects laptop model, GPU, displays, storage, and network interfaces
- **📊 Real-time System Info**: Shows comprehensive hardware details during Home Manager activation  
- **🎮 GPU-Aware Applications**: Automatically configures applications based on detected GPU (Intel/NVIDIA/AMD)
- **🖥️ Display Management**: Extracts real panel IDs for GNOME extension configuration
- **💾 Storage Detection**: Identifies storage devices with proper model information
- **🌐 Network Support**: Detects wired and wireless network interfaces
- **🔧 JSON-Based Architecture**: Reliable two-phase detection system

## 📋 **Detected System Example**

After running detection on a Dell Latitude 7410:

```json
{
  "hostname": "fedora",
  "system_id": "laptop-Latitude_7410-intel",
  "cpu_model": "Intel(R) Core(TM) i7-10610U CPU @ 1.80GHz",
  "gpus": [{"vendor": "intel", "model": "CometLake-U GT2"}],
  "displays": {
    "monitors": [{"panel_id": "AUO-0x00000000", "width": 1920, "height": 1080}]
  },
  "storage": [
    {"name": "nvme0n1", "model": "Micron 2300 NVMe 1024GB"},
    {"name": "sda", "model": "Ultra Fit"}
  ],
  "network_interfaces": [{"name": "wlo1", "type": "wifi", "state": "UP"}],
  "memory_gb": 31,
  "is_laptop": true
}
```

## 🛠️ **Hardware-Specific Configuration**

Applications automatically adapt to detected hardware:

```nix
# Example: OBS Studio with GPU-specific nixGL configuration
home.packages = with pkgs; [
  obs-studio
  
  # Include appropriate nixGL packages based on hardware
] ++ lib.optionals (config.systemSpecs.hasNvidiaGPU or false) [
  # Use explicit NVIDIA version to avoid auto-detection issues
  (nixgl.override { nvidiaVersion = "575.57.08"; }).auto.nixGLNvidia
] ++ lib.optionals (config.systemSpecs.hasIntelGPU or false) [
  nixgl.nixGLIntel
];

# Create wrapper script for hardware-accelerated launch
home.file.".local/bin/obs-nixgl" = {
  text = ''
    #!/usr/bin/env bash
    if command -v nixGLNvidia-575.57.08 &> /dev/null; then
        exec nixGLNvidia-575.57.08 obs "$@"
    elif command -v nixGLIntel &> /dev/null; then
        exec nixGLIntel obs "$@"
    else
        exec obs "$@"
    fi
  '';
  executable = true;
};
```

## 📁 **Project Structure**

```
~/.nix-config/
├── extras/detect-system-specs.sh     # Hardware detection script
├── lib/system-specs.nix              # JSON reader for Nix
├── lib/system-info.nix               # System info display
├── applications/                     # Hardware-aware app configs
├── system-specs.json                 # Generated specifications
└── docs/                            # Comprehensive documentation
```

## 📖 **Documentation**

- **[System Detection Guide](docs/system-detection-guide.md)** - Technical details and troubleshooting
- **[Keyboard Layout Guide](docs/keyboard-layout-guide.md)** - Custom keyboard configuration
- **[Tailscale Setup Guide](docs/tailscale-setup.md)** - User-side Tailscale tools, daemon setup, and login workflow
- **[Tailscale & Secrets Spec](docs/tailscale-secrets-spec.md)** - Proposed design for Tailscale integration and reusable secret management

## 🎯 **Supported Hardware**

- **Laptops**: Dell Latitude series, Lenovo ThinkPad, HP, and others
- **GPUs**: Intel integrated, NVIDIA discrete, AMD graphics
- **Displays**: Internal laptop screens with real panel ID detection
- **Storage**: NVMe SSDs, SATA drives, USB devices, virtual memory
- **Network**: Ethernet and wireless interfaces

## 🔧 **Recent Improvements (June 2025)**

- ✅ **Panel ID Fix**: Real manufacturer data extraction (e.g., "AUO-0x00000000")
- ✅ **Storage Models**: Proper device model detection instead of "null" values
- ✅ **Network Detection**: Fixed wireless interface detection (wlo1, etc.)
- ✅ **JSON Architecture**: Migrated to reliable two-phase detection system
- ✅ **nixGL NVIDIA Fix**: Resolved auto-detection issues by using explicit driver versions
- ✅ **Graphics Acceleration**: Fixed laggy animations in Brave, Obsidian, and OBS Studio

### nixGL Graphics Troubleshooting

If you encounter graphics issues with applications:

1. **Check NVIDIA driver version**:
   ```bash
   nvidia-smi --query-gpu=driver_version --format=csv,noheader,nounits
   ```

2. **Update nixGL configuration** with your specific driver version:
   ```nix
   (nixgl.override { nvidiaVersion = "575.57.08"; }).auto.nixGLNvidia
   ```

3. **Use wrapper scripts** for desktop integration:
   - Applications include `app-nixgl` wrapper scripts
   - Desktop entries automatically use hardware acceleration
   - Example: `brave-nixgl`, `obsidian-nixgl`, `obs-nixgl`

## 🚀 **Ready for Multi-System Use**

This configuration is production-ready and can be used across multiple laptops with automatic hardware adaptation. The system will detect your specific hardware configuration and configure applications accordingly.

---

## 🛠️ **Legacy Quick Fixes**

<details>
<summary>Click to expand legacy troubleshooting commands</summary>

### Fix mimeapps.list error when rebuilding with Nix
```bash
mv ~/.config/mimeapps.list ~/.config/mimeapps.list.backup
```

### Update desktop application index and icon cache
```bash
update-desktop-database ~/.local/share/applications/ ~/.nix-profile/share/applications/
gtk-update-icon-cache -f ~/.nix-profile/share/icons/hicolor 2>/dev/null || true
gtk-update-icon-cache -f ~/.local/share/icons/hicolor 2>/dev/null || true
busctl --user call org.gnome.Shell /org/gnome/Shell org.gnome.Shell Eval s 'Meta.restart("Restarting…")'
```

### Clear GNOME's application cache
```bash
rm -rf ~/.cache/gnome-shell/applications
```

### Restart GNOME Shell (on Wayland)
```bash
killall -SIGUSR1 gnome-shell
```

### Check Dash to Panel settings with dconf
```bash
dconf dump /org/gnome/shell/extensions/dash-to-panel/
```

### Flatpak GTK theme override
```bash
flatpak override --user --env=GTK_THEME=Adwaita:dark org.gnome.Evolution
# Reset with: flatpak override --user --reset org.gnome.Evolution
```

### Additional Resources
- [Fedora 42 Post Install Guide](https://github.com/devangshekhawat/Fedora-42-Post-Install-Guide#nvidia-drivers)

## 🔧 Post-Installation Requirements

Some system-level components need to be installed after a fresh OS install or when rebuilding:

### Tailscale

If you want Tailscale on this machine:

```bash
~/.nix-config/extras/setup-tailscale.sh
```

This keeps Tailscale aligned with the rest of the repo:

- Home Manager installs the `tailscale` package, helper scripts, secret wiring, and optional systray integration
- Fedora systemd runs the privileged `tailscaled` daemon using the Nix-managed binaries
- You connect with `tailscale-connect` after the daemon is running

See **[Tailscale Setup Guide](docs/tailscale-setup.md)** for the full flow.

### Keyboard Configuration (keyd for Keychron)

If you use a Keychron Q11 keyboard and want full SVDVORAK layout with QWERTY Ctrl shortcuts:

```bash
~/.nix-config/extras/setup-keyd.sh
```

This installs `keyd` (a system-wide keyboard remapping daemon) and configures it so that:

**Keychron Q11 (when connected):**
- Normal typing: Full SVDVORAK layout (å, ä, ö and all dvorak key positions)
- Ctrl+C/V/X/Z: Work at QWERTY positions (so muscle memory works)
- All other Ctrl combinations use QWERTY positions

**Laptop keyboard (built-in):**
- Always Swedish QWERTY (unaffected by keyd)
- No remapping applied

**Technical details:**
- keyd only applies to Keychron Q11 (device IDs: 3434:01e1:*)
- GNOME layout set to Swedish QWERTY (`se`)
- keyd provides SVDVORAK character mapping for Keychron
- Uses `layer()` to switch to QWERTY when Ctrl is held

**Note:** This is required because Wayland doesn't support XKB group switching that was used previously. The new solution provides full SVDVORAK layout on the external keyboard while keeping the laptop keyboard as standard Swedish QWERTY.

</details>