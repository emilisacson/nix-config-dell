# Windows VM Setup (Pure QEMU + Nix)

Clean Windows VM setup using pure QEMU approach - no libvirt services needed!

## 🎯 What You Get

- **Real Windows 11 VM** - Full Windows environment for Windows-only apps
- **Pure Nix approach** - No system services, works with Home Manager
- **Hardware accelerated** - Uses KVM for performance
- **UEFI + TPM 2.0** - Meets Windows 11 requirements
- **SPICE display** - Good graphics and clipboard sharing

## ⚠️ Windows 11 Hardware Requirements Bypass

If Windows 11 installer says **"This PC doesn't meet requirements"**:

1. **Press Shift+F10** to open Command Prompt during installation
2. **Type `regedit`** and press Enter
3. **Navigate to**: `HKEY_LOCAL_MACHINE\SYSTEM\Setup`
4. **Create new key**: Right-click → New → Key → Name it `LabConfig`
5. **Inside LabConfig, create these DWORD values**:
   - `BypassTPMCheck` = `1`
   - `BypassSecureBootCheck` = `1`
   - `BypassRAMCheck` = `1`
   - `BypassCPUCheck` = `1`
6. **Close regedit** and **restart the installer**

## 📦 Configuration

Your VM is automatically configured based on your system:
- **Memory**: 8GB RAM  
- **CPU**: 4 cores
- **Disk**: 60GB
- **Graphics**: QXL with SPICE
- **Audio**: Intel HDA
- **Network**: NAT (VM can access internet)

## 🚀 Quick Start

1. **Your Windows ISO is already in place** ✅
   - Located at: `~/.local/share/qemu-vms/isos/Win11_24H2_EnglishInternational_x64.iso`

2. **Create VM environment**:
   ```bash
   create-windows-vm
   ```

3. **Start Windows VM**:
   ```bash
   start-windows-vm
   ```

4. **Check VM status**:
   ```bash
   status-windows-vm
   ```

5. **Stop VM**:
   ```bash
   stop-windows-vm
   ```

6. **Download clipboard tools** (after Windows installation):
   ```bash
   download-spice-tools
   ```

## 🖥️ VM Access

- **SPICE viewer** opens automatically
- **Manual connection**: `spice://localhost:5900`
- **Console access**: Ctrl+Alt+2 in QEMU, type `quit` to exit

## 🎮 First Time Setup

1. Run `create-windows-vm` to set up the VM environment
2. Run `start-windows-vm` - it will boot from your Windows ISO
3. Install Windows 11 normally
4. After installation, the VM will boot from disk automatically

## 📋 Enable Clipboard Sharing

After installing Windows, enable clipboard sharing between Linux host and Windows VM:

### Method 1: From VirtIO ISO (Recommended)
The VirtIO drivers ISO is automatically mounted in your Windows VM:

1. **In Windows File Explorer**, open the VirtIO CD drive
2. **Install QEMU Guest Agent**: 
   - Go to `guest-agent/` folder
   - Run `qemu-ga-x86_64.msi` as Administrator
3. **Install SPICE Guest Tools**: 
   - Go to `spice-guest-tools/` folder  
   - Run the `.exe` file as Administrator
4. **Reboot Windows**
5. **Test clipboard**: Copy text on Linux host, paste in Windows VM (and vice versa)

### Method 2: Download Latest Tools
```bash
download-spice-tools  # Downloads latest SPICE guest tools to VM directory
```
Then in Windows, navigate to the downloaded file and install it.

### 🔧 Troubleshooting Clipboard
If clipboard doesn't work after installation:
1. **Check SPICE Agent service** (Win+R → `services.msc`)
2. **Restart the SPICE Agent service** if it's not running
3. **Enable Windows clipboard history** (Settings → System → Clipboard)

After setup, you'll have seamless clipboard sharing!

## 🔧 Why This Approach?

- ✅ **Pure Nix**: Everything declared in your configuration
- ✅ **No system services**: Works with Home Manager on any Linux
- ✅ **Reproducible**: Same VM configuration every time
- ✅ **Lightweight**: No libvirt overhead
- ✅ **Maintainable**: Single configuration file

## 📁 File Locations

- **VM files**: `~/.local/share/qemu-vms/`
- **VM disk**: `~/.local/share/qemu-vms/windows-vm.qcow2`
- **Windows ISO**: `~/.local/share/qemu-vms/isos/Win11_24H2_EnglishInternational_x64.iso`
- **UEFI firmware**: `~/.local/share/qemu-vms/OVMF_VARS.fd`

## 🎯 Perfect For

- OneNote desktop app
- Windows-only corporate software  
- Microsoft Office (full desktop version)
- Development and testing
- Any Windows application that doesn't work with Wine

Enjoy your clean, Nix-managed Windows VM! 🖥️✨
