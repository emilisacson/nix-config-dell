# System-Specific Performance Configuration
# This module configures performance settings based on detected hardware and system-specific preferences

{ config, lib, pkgs, ... }:

let
  # System-specific performance configuration
  systemSpecs = config.systemSpecs;
  system_id = systemSpecs.system_id or "unknown";

  # Determine performance tier based on hardware
  performanceTier =
    if systemSpecs.hasNvidiaGPU && systemSpecs.memory_gb >= 32 then
      "high"
    else if systemSpecs.hasNvidiaGPU || systemSpecs.memory_gb >= 16 then
      "medium"
    else
      "low";

  # System-specific performance configurations
  performanceConfigs = {
    # ThinkPad P1 Gen 4 - High-performance hybrid GPU laptop
    "laptop-20Y30016MX-hybrid" = {
      enableGameMode = true;
      enableNvidiaOptimus = true;
      powerProfile = "performance";
      enableAdvancedPowerManagement = true;
    };

    # Dell Latitude 7410 - Business laptop, balanced performance
    "laptop-Latitude_7410-intel" = {
      enableGameMode = false;
      enableNvidiaOptimus = false;
      powerProfile = "balanced";
      enableAdvancedPowerManagement = true;
    };

    # Default configuration
    "default" = {
      enableGameMode = false;
      enableNvidiaOptimus = false;
      powerProfile = "balanced";
      enableAdvancedPowerManagement = false;
    };
  };

  # Get configuration for current system
  perfConfig = performanceConfigs.${system_id} or performanceConfigs.default;

  # Performance settings based on detected hardware tier
  performanceSettings = {
    high = {
      cpuGovernor = "performance";
      enableGameMode = true;
      swappiness = 10;
      enableZram = true;
    };
    medium = {
      cpuGovernor = "powersave";
      enableGameMode = false;
      swappiness = 60;
      enableZram = true;
    };
    low = {
      cpuGovernor = "powersave";
      enableGameMode = false;
      swappiness = 100;
      enableZram = true;
    };
  };

  currentPerformanceConfig = performanceSettings.${performanceTier};

  # Hardware detection helpers
  isHybridGPU = systemSpecs.hasNvidiaGPU && systemSpecs.hasIntelGPU;
  primaryGPU = if systemSpecs.hasNvidiaGPU then
    "nvidia"
  else if systemSpecs.hasAMDGPU then
    "amd"
  else
    "intel";

in {
  # System-specific performance configuration via environment variables and settings
  # Note: gamemode is typically a system-level service, not managed through home-manager

  # Add system-specific environment variables for performance tuning
  home.sessionVariables = {
    # Performance tier indicator
    PERFORMANCE_TIER = performanceTier;

    # System configuration indicator
    SYSTEM_PERFORMANCE_PROFILE = perfConfig.powerProfile;

    # Memory management
    MALLOC_MMAP_THRESHOLD = if performanceTier == "high" then
      "131072"
    else if performanceTier == "medium" then
      "65536"
    else
      "32768";
  } // lib.optionalAttrs systemSpecs.hasNvidiaGPU {
    # GPU-specific variables only when Nvidia GPU is present
    __GLX_VENDOR_LIBRARY_NAME = "nvidia";
  };

  # System-specific packages based on hardware
  home.packages = with pkgs;
    [ ] ++ lib.optionals (performanceTier == "high") [ gamemode mangohud ]
    ++ lib.optionals systemSpecs.is_laptop [ powertop acpi ];

  # System-specific shell aliases for performance monitoring
  programs.bash.shellAliases = {
    # GPU monitoring
    "gpu-status" = lib.mkIf systemSpecs.hasNvidiaGPU "nvidia-smi";
    "gpu-top" = lib.mkIf systemSpecs.hasNvidiaGPU "nvtop";

    # System performance
    "perf-status" =
      "echo 'Performance Tier: ${performanceTier}' && echo 'GPU: ${primaryGPU}' && echo 'System Profile: ${perfConfig.powerProfile}'";

    # System-specific info
    "system-info" =
      "echo 'System ID: ${system_id}' && echo 'Performance: ${perfConfig.powerProfile}' && echo 'Multi-Monitor: ${
        if systemSpecs.displays.count > 1 then "Yes" else "No"
      }'";

    # Laptop-specific
  } // lib.optionalAttrs systemSpecs.is_laptop {
    "battery" = "acpi -b";
    "power-usage" = "sudo powertop --html=powertop.html";
  };
}
