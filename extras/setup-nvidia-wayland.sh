#!/usr/bin/env bash

# Script to set up NVIDIA Wayland environment
# Run this script with source to apply the environment variables to your current session
# Example: source ~/.local/bin/setup-nvidia-wayland.sh

# Enable Wayland support for NVIDIA
export LIBVA_DRIVER_NAME=nvidia
export MOZ_ENABLE_WAYLAND=1
export GBM_BACKEND=nvidia-drm
export __GLX_VENDOR_LIBRARY_NAME=nvidia
export WLR_NO_HARDWARE_CURSORS=1
export KWIN_DRM_DEVICES=/dev/dri/card0:/dev/dri/card1  # Adjust if necessary

# EGL support
export EGL_PLATFORM=wayland

# Electron apps
export ELECTRON_OZONE_PLATFORM=wayland

# For some Qt applications
export QT_QPA_PLATFORM=wayland-egl
export QT_WAYLAND_DISABLE_WINDOWDECORATION=1

# GTK applications
export GDK_BACKEND=wayland

# Firefox - additional tweaks for better performance
export MOZ_WEBRENDER=1
export MOZ_ACCELERATED=1

# Chromium/Brave browser
export CHROME_EXTRA_FLAGS="--enable-features=UseOzonePlatform --ozone-platform=wayland"

# Vulkan support
export VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/nvidia_icd.json

# Additional performance tweaks
export VDPAU_DRIVER=nvidia
export LIBGL_DRI3_DISABLE=0

echo "NVIDIA Wayland environment variables have been set for this session."
echo "You can add these to your .bashrc or .profile for persistence."
echo "To make these settings permanent for Cosmic/GNOME, add them to ~/.config/environment.d/nvidia-wayland.conf"
