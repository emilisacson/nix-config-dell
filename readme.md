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
   NIXPKGS_ALLOW_UNFREE=1 nix run --impure .#homeConfigurations.$USER.activationPackage
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
# Example: OBS Studio with GPU-specific configuration
programs.obs-studio = {
  enable = true;
  package = if config.systemSpecs.hasNvidiaGPU 
    then nixgl.nixGLNvidia pkgs.obs-studio
    else nixgl.nixGLIntel pkgs.obs-studio;
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

</details>