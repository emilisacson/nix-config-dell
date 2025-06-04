# System Specifications Module
# This module reads system specifications from a JSON file created by the detection script
# and provides them as Nix configuration options.

{ config, lib, pkgs, ... }:

let
  # Path to the system specifications JSON file (user's config directory)
  configDir = builtins.getEnv "HOME" + "/.nix-config";
  specsFile = configDir + "/system-specs.json";

  # Read and parse the JSON file if it exists, otherwise use defaults
  systemSpecs = if builtins.pathExists specsFile then
    builtins.fromJSON (builtins.readFile specsFile)
  else {
    # Default/fallback specifications
    hostname = "unknown";
    os_name = "NixOS";
    os_version = "unknown";
    os_id = "nixos";
    architecture = "x86_64";
    cpu_model = "Unknown CPU";
    cpu_cores = 4;
    cpu_vendor = "unknown";
    gpus = [ ];
    displays = {
      count = 0;
      monitors = [ ];
      primary = "unknown";
    };
    memory_gb = 8;
    storage = [ ];
    network_interfaces = [ ];
    is_laptop = false;
    system_id = "fallback-system";
    detection_timestamp = "never";
    detection_method = "fallback";
  };

  # Helper functions for GPU detection
  hasGPUVendor = vendor:
    builtins.any (gpu: gpu.vendor == vendor) systemSpecs.gpus;
  hasNvidiaGPU = hasGPUVendor "nvidia";
  hasIntelGPU = hasGPUVendor "intel";
  hasAMDGPU = hasGPUVendor "amd";

in {
  # Make system specifications and helper functions available to other modules
  options.systemSpecs = lib.mkOption {
    type = lib.types.attrs;
    description = "Detected system specifications with computed values";
    readOnly = true;
  };

  config = {
    # Set the systemSpecs option
    systemSpecs = systemSpecs // {
      # Add computed GPU detection values
      hasNvidiaGPU = hasNvidiaGPU;
      hasIntelGPU = hasIntelGPU;
      hasAMDGPU = hasAMDGPU;
    };

    # Ensure the JSON file exists - fail the build if it doesn't
    assertions = [{
      assertion = builtins.pathExists specsFile;
      message = ''
        ❌ REQUIRED: System specifications file not found!

        Missing file: ${toString specsFile}

        The JSON-based system detection requires this file to be generated
        before building the Home Manager configuration.

        🔧 To fix this error:
        1. Run the detection script:
           cd ~/.nix-config && ./extras/detect-system-specs.sh

        2. Then rebuild your configuration:
           cd ~/.nix-config && NIXPKGS_ALLOW_UNFREE=1 nix run --impure .#homeConfigurations.$USER.activationPackage

        The detection script analyzes your hardware and generates the required
        system-specs.json file for hardware-specific configuration.
      '';
    }];

    # Optional: Add system info to home.sessionVariables for debugging
    home.sessionVariables =
      lib.mkIf (systemSpecs.detection_method != "fallback") {
        DETECTED_SYSTEM_ID = systemSpecs.system_id;
        DETECTED_HOSTNAME = systemSpecs.hostname;
        DETECTED_GPU_COUNT = toString (builtins.length systemSpecs.gpus);
        DETECTED_MONITOR_COUNT = toString systemSpecs.displays.count;
        DETECTED_IS_LAPTOP = if systemSpecs.is_laptop then "true" else "false";
      };
  };
}
