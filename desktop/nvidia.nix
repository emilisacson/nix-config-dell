{ config, pkgs, lib, ... }:

let
  # Check if this system has NVIDIA GPU based on detection
  hasNvidia = config.systemSpecs.hasNvidiaGPU or false;
in {
  # NVIDIA-specific packages and tools - only install if NVIDIA GPU detected
  home.packages = with pkgs;
    lib.optionals hasNvidia [
      # CUDA packages for NVIDIA GPU compute capabilities
      cudaPackages.cuda_cudart # CUDA runtime
      cudaPackages.cuda_nvcc # NVIDIA CUDA Compiler
    ];

  # Create a script to check NVIDIA-specific driver status
  # This will provide detailed information about your NVIDIA setup
  home.file.".local/bin/check-nvidia.sh" = lib.mkIf hasNvidia {
    executable = true;
    text = ''
      #!/usr/bin/env bash

      echo "=== NVIDIA Driver Status ==="
      if command -v nvidia-smi &> /dev/null; then
        nvidia-smi
      else
        echo "nvidia-smi not found. NVIDIA drivers may not be installed correctly."
      fi

      echo -e "\n=== NVIDIA GPU Information ==="
      if command -v lspci &> /dev/null; then
        echo "NVIDIA devices found:"
        lspci | grep -i nvidia
      else
        echo "lspci not found. Cannot detect NVIDIA devices."
      fi

      echo -e "\n=== NVIDIA Vulkan Support ==="
      if command -v vulkaninfo &> /dev/null; then
        vulkaninfo --summary 2>/dev/null | grep -i nvidia | head -5
      else
        echo "vulkaninfo not found. Cannot determine NVIDIA Vulkan support."
      fi

      echo -e "\n=== NVIDIA CUDA Support ==="
      if command -v nvcc &> /dev/null; then
        nvcc --version
      else
        echo "nvcc not found. CUDA toolkit may not be installed."
      fi
    '';
  }; # Create symlinks for NVIDIA Wayland setup scripts - only if NVIDIA detected
  home.file.".local/bin/setup-nvidia-wayland.sh" = lib.mkIf hasNvidia {
    source = ../extras/setup-nvidia-wayland.sh;
    executable = true;
  };

  # Create a symlink for the permanent Wayland environment setup script
  # This makes the environment variables persist across sessions
  home.file.".local/bin/setup-permanent-nvidia-wayland.sh" =
    lib.mkIf hasNvidia {
      source = ../extras/setup-permanent-nvidia-wayland.sh;
      executable = true;
    };

  # Documentation about the NVIDIA setup - only if NVIDIA detected
  home.file.".local/share/nvidia-setup-readme.md" = lib.mkIf hasNvidia {
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
