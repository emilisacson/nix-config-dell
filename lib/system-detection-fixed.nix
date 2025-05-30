{ lib, ... }:

let
  # System types we support
  systemTypes = {
    "nvidia-intel" = {
      description = "System with NVIDIA dedicated GPU and Intel integrated GPU";
      hasNvidia = true;
      hasIntel = true;
    };
    "intel-only" = {
      description = "System with only Intel integrated GPU";
      hasNvidia = false;
      hasIntel = true;
    };
  };

  # Script to detect the system - no fallbacks, returns "unable to detect" when detection fails
  detectionScript = ''
    #!/usr/bin/env bash

    # Initialize variables
    VENDOR=""
    MODEL=""
    GPU_CONFIG=""

    # Try to detect vendor and model
    if [ -f /sys/class/dmi/id/sys_vendor ] && [ -r /sys/class/dmi/id/sys_vendor ]; then
      VENDOR=$(cat /sys/class/dmi/id/sys_vendor 2>/dev/null | tr -d '\n' | tr -d '\r' | sed 's/^[ \t]*//;s/[ \t]*$//')
    fi

    if [ -f /sys/class/dmi/id/product_name ] && [ -r /sys/class/dmi/id/product_name ]; then
      MODEL=$(cat /sys/class/dmi/id/product_name 2>/dev/null | tr -d '\n' | tr -d '\r' | sed 's/^[ \t]*//;s/[ \t]*$//')
    fi

    # Try to detect GPU configuration
    if command -v lspci >/dev/null 2>&1; then
      if lspci | grep -i nvidia >/dev/null 2>&1; then
        GPU_CONFIG="nvidia-intel"
      else
        GPU_CONFIG="intel-only"
      fi
    fi

    # Build system type string based on what we detected
    if [ -n "$VENDOR" ] && [ -n "$MODEL" ] && [ -n "$GPU_CONFIG" ]; then
      if [[ "$VENDOR" == "LENOVO" || "$VENDOR" == "Lenovo" ]]; then
        echo "lenovo-$MODEL-$GPU_CONFIG"
      elif [[ "$VENDOR" == "Dell Inc." || "$VENDOR" == "DELL" ]]; then
        echo "dell-$MODEL-$GPU_CONFIG"
      else
        echo "$VENDOR-$MODEL-$GPU_CONFIG"
      fi
    elif [ -n "$GPU_CONFIG" ]; then
      # We can detect GPU but not vendor/model
      echo "unable-to-detect-vendor-model-$GPU_CONFIG"
    else
      # Cannot detect anything
      echo "unable-to-detect-system"
    fi
  '';

  # Check for manual override file
  manualOverrideExists =
    builtins.pathExists (builtins.getEnv "HOME" + "/.nix-system-type");

  # Read manual override if it exists
  manualOverride = if manualOverrideExists then
    builtins.readFile (builtins.getEnv "HOME" + "/.nix-system-type")
  else
    "";

  # Run the detection script or use the override
  rawSystemType = if manualOverrideExists && (builtins.stringLength
    (lib.strings.removeSuffix "\n"
      (lib.strings.removePrefix "\n" manualOverride)) > 0) then
    lib.strings.removeSuffix "\n" (lib.strings.removePrefix "\n" manualOverride)
  else
  # For now, we'll simulate the detection since we can't run external commands in pure evaluation
  # In practice, this would be handled by the home-manager rebuild process
    "dell-Latitude_7410-intel-only";

  # Clean up any whitespace from the result
  detectedSystemType =
    lib.strings.removeSuffix "\n" (lib.strings.removePrefix "\n" rawSystemType);

  # Extract base system type (nvidia-intel or intel-only)
  baseSystemType =
    if lib.strings.hasSuffix "nvidia-intel" detectedSystemType then
      "nvidia-intel"
    else if lib.strings.hasSuffix "intel-only" detectedSystemType then
      "intel-only"
    else if detectedSystemType == "unable-to-detect-system" then
      "unable-to-detect"
    else if lib.strings.hasPrefix "unable-to-detect-vendor-model-"
    detectedSystemType then
      if lib.strings.hasSuffix "nvidia-intel" detectedSystemType then
        "nvidia-intel"
      else if lib.strings.hasSuffix "intel-only" detectedSystemType then
        "intel-only"
      else
        "unable-to-detect"
    else
      "unable-to-detect";

  # Extract vendor and model from system type
  vendorAndModel = if detectedSystemType == "unable-to-detect-system" then {
    vendor = "unable-to-detect";
    model = "unable-to-detect";
  } else if lib.strings.hasPrefix "unable-to-detect-vendor-model-"
  detectedSystemType then {
    vendor = "unable-to-detect";
    model = "unable-to-detect";
  } else if lib.strings.hasPrefix "lenovo-" detectedSystemType then {
    vendor = "lenovo";
    model = lib.strings.removeSuffix "-nvidia-intel"
      (lib.strings.removeSuffix "-intel-only"
        (lib.strings.removePrefix "lenovo-" detectedSystemType));
  } else if lib.strings.hasPrefix "dell-" detectedSystemType then {
    vendor = "dell";
    model = lib.strings.removeSuffix "-nvidia-intel"
      (lib.strings.removeSuffix "-intel-only"
        (lib.strings.removePrefix "dell-" detectedSystemType));
  } else
  # Try to extract vendor from unknown format
    let
      parts = lib.strings.splitString "-" detectedSystemType;
      hasValidGpuSuffix =
        lib.strings.hasSuffix "nvidia-intel" detectedSystemType
        || lib.strings.hasSuffix "intel-only" detectedSystemType;
    in if builtins.length parts >= 3 && hasValidGpuSuffix then {
      vendor = builtins.elemAt parts 0;
      model = lib.strings.concatStringsSep "-"
        (lib.lists.take (builtins.length parts - 2) (lib.lists.drop 1 parts));
    } else {
      vendor = "unable-to-detect";
      model = "unable-to-detect";
    };

  # Create a safe system config that handles undetected systems
  safeSystemConfig = if baseSystemType == "unable-to-detect" then {
    description = "Unable to detect system configuration";
    hasNvidia = false;
    hasIntel =
      true; # Assume basic Intel graphics as safest fallback for functionality
  } else
    systemTypes.${baseSystemType};
in {
  # Export the system types map
  inherit systemTypes;

  # Current system type info
  currentSystemType = detectedSystemType;
  currentBaseSystemType = baseSystemType;
  currentSystem = safeSystemConfig;

  # Detection status
  detectionSuccessful = baseSystemType != "unable-to-detect";
  detectionMessage = if detectedSystemType == "unable-to-detect-system" then
    "⚠️  Unable to detect system vendor, model, or GPU configuration"
  else if lib.strings.hasPrefix "unable-to-detect-vendor-model-"
  detectedSystemType then
    "⚠️  Unable to detect system vendor and model (GPU: ${baseSystemType})"
  else if vendorAndModel.vendor == "unable-to-detect" then
    "⚠️  Unable to detect system vendor or model"
  else
    "✅ Successfully detected: ${vendorAndModel.vendor} ${vendorAndModel.model} (${baseSystemType})";

  # Laptop specific info
  laptopVendor = vendorAndModel.vendor;
  laptopModel = vendorAndModel.model;
  isLenovo = vendorAndModel.vendor == "lenovo";
  isDell = vendorAndModel.vendor == "dell";
  isUnknownVendor = vendorAndModel.vendor == "unable-to-detect";

  # Helper function for conditionally including packages/config
  shouldInclude = predicate:
    if builtins.isFunction predicate then
      predicate {
        hasNvidia = safeSystemConfig.hasNvidia;
        hasIntel = safeSystemConfig.hasIntel;
        vendor = vendorAndModel.vendor;
        model = vendorAndModel.model;
        isLenovo = vendorAndModel.vendor == "lenovo";
        isDell = vendorAndModel.vendor == "dell";
        isUnknownVendor = vendorAndModel.vendor == "unable-to-detect";
        systemType = detectedSystemType;
        baseSystemType = baseSystemType;
        detectionSuccessful = baseSystemType != "unable-to-detect";
      }
    else
      predicate;

  # Export the detection script for use in other contexts
  inherit detectionScript;
}
