#!/usr/bin/env bash

# Script to install NVIDIA drivers on Fedora alongside Nix configuration
# This script complements the Home Manager configuration for NVIDIA drivers

# Exit on error
set -e

echo "=== Setting up NVIDIA drivers for Fedora with Nix integration ==="
echo "This script will install NVIDIA drivers using dnf, which is required"
echo "alongside the Nix configuration to get kernel modules working properly."

# Check if running as root
if [ "$EUID" -ne 0 ]; then
  echo "Please run this script as root (sudo)."
  exit 1
fi

# Function to check if a package is installed
is_installed() {
  rpm -q "$1" &> /dev/null
}

# Install NVIDIA repository and drivers
echo "Installing NVIDIA drivers..."

# Make sure RPM Fusion repositories are installed
if ! is_installed "rpmfusion-free-release" || ! is_installed "rpmfusion-nonfree-release"; then
  echo "Installing RPM Fusion repositories..."
  dnf install -y https://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm
  dnf install -y https://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm
fi

# Update package lists
dnf check-update || true

# Install NVIDIA drivers
echo "Installing NVIDIA kernel modules (akmod-nvidia)..."
dnf install -y akmod-nvidia

# Install CUDA support
echo "Installing NVIDIA CUDA support..."
dnf install -y xorg-x11-drv-nvidia-cuda

# Install Wayland-specific support
echo "Installing NVIDIA Wayland support..."
dnf install -y xorg-x11-drv-nvidia-power

# Install additional NVIDIA packages
echo "Installing additional NVIDIA utilities..."
dnf install -y nvidia-settings

# Install Vulkan support
echo "Installing Vulkan support for NVIDIA..."
dnf install -y vulkan vulkan-tools vulkan-loader vulkan-validation-layers

# Install additional video acceleration packages
echo "Installing video acceleration packages..."
dnf install -y libva libva-utils vdpauinfo

# Wait for kernel modules to build
echo "Waiting for NVIDIA kernel modules to build (this may take a few minutes)..."
sleep 10
echo "Checking if modules are built..."
# Check every 10 seconds for up to 5 minutes
for i in {1..30}; do
  if modinfo -F version nvidia &> /dev/null; then
    echo "NVIDIA modules are ready!"
    break
  fi
  if [ $i -eq 30 ]; then
    echo "Timeout waiting for NVIDIA modules to build."
    echo "They may still be building in the background. Check 'akmods --force' status."
  fi
  echo "Still waiting... ($i/30)"
  sleep 10
done

# Configure blacklisting of nouveau if needed
if grep -q "nouveau" /etc/modprobe.d/blacklist-nouveau.conf 2>/dev/null; then
  echo "Nouveau is already blacklisted."
else
  echo "Blacklisting nouveau driver..."
  cat > /etc/modprobe.d/blacklist-nouveau.conf << EOF
blacklist nouveau
options nouveau modeset=0
EOF
  echo "Nouveau driver blacklisted."
fi

# Update initramfs
echo "Updating initramfs..."
dracut --force

echo ""
echo "=== NVIDIA Setup Complete ==="
echo "You may need to reboot your system for the changes to take effect."
echo "After reboot, you can check your NVIDIA status with the check-nvidia.sh script:"
echo "  ~/.local/bin/check-nvidia.sh"
echo ""
echo "To configure Wayland environment for NVIDIA, you can run:"
echo "  ~/.local/bin/setup-permanent-nvidia-wayland.sh"
echo ""
echo "Note: Be sure to rebuild your Home Manager configuration to install the Nix packages:"
echo "  cd ~/.nix-config && NIXPKGS_ALLOW_UNFREE=1 nix run --impure .#homeConfigurations.$USER.activationPackage"
