{ config, pkgs, lib, ... }:

{
  # NVIDIA driver packages and tools
  # These packages are installed via Nix, but the kernel modules are handled by Fedora/RPM
  home.packages = with pkgs; [
    # Basic packages that should be available in most distributions
    libglvnd # Vendor-neutral OpenGL dispatch library
    wev # Wayland event viewer (like xev for X11)
    wl-clipboard # Command-line copy/paste utilities for Wayland

    # X11 and graphics tools
    xorg.xhost # For managing access to the X server
    glxinfo # OpenGL information tool
    vulkan-tools # Vulkan utilities (vulkaninfo, etc.)
    vulkan-loader # Vulkan ICD loader
    wayland-utils # Wayland utilities including wayland-info

    # CUDA packages for NVIDIA GPU compute capabilities
    cudaPackages.cuda_cudart # CUDA runtime
    cudaPackages.cuda_nvcc # NVIDIA CUDA Compiler
  ];

  # Create a script to check NVIDIA driver status
  # This will provide detailed information about your NVIDIA setup
  home.file.".local/bin/check-nvidia.sh" = {
    executable = true;
    text = ''
      #!/usr/bin/env bash

      echo "=== NVIDIA Driver Status ==="
      if command -v nvidia-smi &> /dev/null; then
        nvidia-smi
      else
        echo "nvidia-smi not found. NVIDIA drivers may not be installed correctly."
      fi

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

      # Check for Vulkan support
      echo -e "\n=== Vulkan Support ==="
      if command -v vulkaninfo &> /dev/null; then
        vulkaninfo --summary 2>/dev/null | grep -E "GPU|deviceName|driverVersion" | head -10
      else
        echo "vulkaninfo not found. Cannot determine Vulkan support."
      fi
    '';
  }; # Create a symlink for the Wayland setup script
  home.file.".local/bin/setup-nvidia-wayland.sh" = {
    source = ../extras/setup-nvidia-wayland.sh;
    executable = true;
  };

  # Create a symlink for the permanent Wayland environment setup script
  # This makes the environment variables persist across sessions
  home.file.".local/bin/setup-permanent-nvidia-wayland.sh" = {
    source = ../extras/setup-permanent-nvidia-wayland.sh;
    executable = true;
  };

  # Documentation about the NVIDIA setup
  home.file.".local/share/nvidia-setup-readme.md" = {
    text = ''
      # NVIDIA Setup for Fedora with Nix/Home Manager

      This guide helps you set up NVIDIA drivers on your Fedora system alongside your Nix configuration.

      ## System-level Driver Installation

      Run the following command to install the required kernel modules and system packages:

      ```bash
      sudo ~/.nix-config/extras/setup-nvidia-drivers.sh
      ```

      ## Wayland Configuration

      For temporary Wayland environment variables (current session only):

      ```bash
      source ~/.local/bin/setup-nvidia-wayland.sh
      ```

      For permanent Wayland environment variables (applies to all future sessions):

      ```bash
      ~/.local/bin/setup-permanent-nvidia-wayland.sh
      ```

      ## Checking NVIDIA Status

      To check the status of your NVIDIA drivers and configuration:

      ```bash
      ~/.local/bin/check-nvidia.sh
      ```

      ## Troubleshooting

      If you encounter issues with the NVIDIA drivers:

      1. Make sure the kernel modules are loaded: `lsmod | grep nvidia`
      2. Check the X/Wayland logs: `journalctl -b -0 -u gdm`
      3. Verify that the NVIDIA card is detected: `nvidia-smi`
    '';
  };
}
