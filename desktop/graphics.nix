{ config, pkgs, lib, systemConfig ? null, ... }:

{
  # General graphics and GPU utilities for all systems
  home.packages = with pkgs; [
    # Vendor-neutral graphics libraries
    libglvnd # Vendor-neutral OpenGL dispatch library

    # Wayland utilities
    wev # Wayland event viewer (like xev for X11)
    wl-clipboard # Command-line copy/paste utilities for Wayland
    wayland-utils # Wayland utilities including wayland-info

    # X11 and graphics tools
    xorg.xhost # For managing access to the X server
    glxinfo # OpenGL information tool

    # Vulkan support (works with both Intel and NVIDIA)
    vulkan-tools # Vulkan utilities (vulkaninfo, etc.)
    vulkan-loader # Vulkan ICD loader
  ];

  # Create a script to check general graphics status
  home.file.".local/bin/check-graphics.sh" = {
    executable = true;
    text = ''
      #!/usr/bin/env bash

      echo "=== Graphics System Information ==="

      # Display server detection
      echo -e "\n=== Current Display Server ==="
      if [[ "$XDG_SESSION_TYPE" == "wayland" ]]; then
        echo "Currently running on Wayland"
        
        echo -e "\n=== Wayland Compositor Info ==="
        if command -v wayland-info &> /dev/null; then
          wayland-info | head -15  # Show just the first 15 lines to avoid information overload
        else
          echo "wayland-info not found. Cannot determine Wayland compositor details."
        fi
      elif [[ "$XDG_SESSION_TYPE" == "x11" ]]; then
        echo "Currently running on X11"
        
        echo -e "\n=== X11 OpenGL Information ==="
        if command -v glxinfo &> /dev/null; then
          glxinfo | grep -E "OpenGL vendor|OpenGL renderer|OpenGL version"
        else
          echo "glxinfo not found. Cannot determine OpenGL information."
        fi
      else
        echo "Unknown display server: $XDG_SESSION_TYPE"
      fi

      # GPU Detection
      echo -e "\n=== GPU Detection ==="
      if command -v lspci &> /dev/null; then
        echo "GPU devices found:"
        lspci | grep -i vga
        lspci | grep -i 3d
      else
        echo "lspci not found. Cannot detect GPU devices."
      fi

      # Check for Vulkan support
      echo -e "\n=== Vulkan Support ==="
      if command -v vulkaninfo &> /dev/null; then
        vulkaninfo --summary 2>/dev/null | grep -E "GPU|deviceName|driverVersion" | head -10
      else
        echo "vulkaninfo not found. Cannot determine Vulkan support."
      fi

      # DRM devices
      echo -e "\n=== DRM Devices ==="
      if [ -d /sys/class/drm ]; then
        echo "DRM devices:"
        ls -la /sys/class/drm/card*/device/vendor 2>/dev/null | while read line; do
          device=$(echo "$line" | cut -d' ' -f9)
          vendor=$(cat "$device" 2>/dev/null)
          case "$vendor" in
            "0x8086") echo "  Intel GPU: $device" ;;
            "0x10de") echo "  NVIDIA GPU: $device" ;;
            "0x1002") echo "  AMD GPU: $device" ;;
            *) echo "  Unknown GPU ($vendor): $device" ;;
          esac
        done
      else
        echo "No DRM devices found."
      fi
    '';
  };
}
