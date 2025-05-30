{ config, lib, systemConfig ? null, ... }:

{
  # Add activation script to show system type when rebuilding
  home.activation.showSystemType = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    echo "╔═══════════════════════════════════════════════════╗"
    echo "║ 🖥️  System Detection Report"
    echo "╠═══════════════════════════════════════════════════╣"

    # Show build-time detection if available
    ${if systemConfig != null && systemConfig ? detectionMessage then ''
      echo "║ ${systemConfig.detectionMessage}"
    '' else ''
      echo "║ ⚠️  No build-time detection available"
    ''}

    ${if systemConfig != null && systemConfig ? currentSystemType then ''
      echo "║ • Build-time system: ${systemConfig.currentSystemType}"
    '' else
      ""}

    ${if systemConfig != null && systemConfig ? currentSystem
    && systemConfig.currentSystem ? description then ''
      echo "║ • Configuration: ${systemConfig.currentSystem.description}"
    '' else
      ""}

    echo "╠═══════════════════════════════════════════════════╣"
    echo "║ 🔍 Runtime Detection:"

    # Detect system information at runtime (not build time)
    VENDOR=""
    MODEL=""

    if [ -f /sys/class/dmi/id/sys_vendor ] && [ -r /sys/class/dmi/id/sys_vendor ]; then
      VENDOR=$(cat /sys/class/dmi/id/sys_vendor 2>/dev/null | tr -d '\n' | tr -d '\r' | sed 's/^[ \t]*//;s/[ \t]*$//')
    fi

    if [ -f /sys/class/dmi/id/product_name ] && [ -r /sys/class/dmi/id/product_name ]; then
      MODEL=$(cat /sys/class/dmi/id/product_name 2>/dev/null | tr -d '\n' | tr -d '\r' | sed 's/^[ \t]*//;s/[ \t]*$//')
    fi

    # Check for NVIDIA GPU using multiple methods
    HAS_NVIDIA=false
    GPU_DETECTION_METHOD=""

    # Method 1: lspci
    if command -v lspci >/dev/null 2>&1; then
      if lspci 2>/dev/null | grep -i nvidia >/dev/null 2>&1; then
        HAS_NVIDIA=true
        GPU_DETECTION_METHOD="lspci"
      fi
    fi

    # Method 2: Check for NVIDIA driver files (if lspci failed)
    if [[ "$HAS_NVIDIA" == "false" ]]; then
      if [ -d /proc/driver/nvidia ] || [ -f /dev/nvidia0 ] || [ -f /dev/nvidiactl ]; then
        HAS_NVIDIA=true
        GPU_DETECTION_METHOD="nvidia-driver"
      fi
    fi

    # Method 3: Check for NVIDIA in dmesg (if available)
    if [[ "$HAS_NVIDIA" == "false" ]] && command -v dmesg >/dev/null 2>&1; then
      if dmesg 2>/dev/null | grep -i nvidia >/dev/null 2>&1; then
        HAS_NVIDIA=true
        GPU_DETECTION_METHOD="dmesg"
      fi
    fi

    # Method 4: Check PCI devices directory
    if [[ "$HAS_NVIDIA" == "false" ]] && [ -d /sys/bus/pci/devices ]; then
      for device in /sys/bus/pci/devices/*/vendor; do
        if [ -r "$device" ] && [ "$(cat "$device" 2>/dev/null)" = "0x10de" ]; then
          HAS_NVIDIA=true
          GPU_DETECTION_METHOD="pci-vendor-id"
          break
        fi
      done
    fi

    # Display runtime detection results
    if [ -n "$VENDOR" ] && [ -n "$MODEL" ]; then
      echo "║ • Vendor: $VENDOR"
      echo "║ • Model: $MODEL"
      
      if [[ "$VENDOR" == "LENOVO" || "$VENDOR" == "Lenovo" ]]; then
        LAPTOP_TYPE="Lenovo"
      elif [[ "$VENDOR" == "Dell Inc." || "$VENDOR" == "DELL" ]]; then
        LAPTOP_TYPE="Dell"
      else
        LAPTOP_TYPE="$VENDOR"
      fi
      
      echo "║ • Laptop: $LAPTOP_TYPE $MODEL"
    else
      echo "║ • ⚠️  Unable to detect vendor/model at runtime"
    fi

    # Display GPU detection results
    if [[ "$HAS_NVIDIA" == "true" ]]; then
      echo "║ • GPU: NVIDIA + Intel (hybrid) [detected via $GPU_DETECTION_METHOD]"
    elif command -v lspci >/dev/null 2>&1; then
      echo "║ • GPU: Intel only [detected via lspci]"
    elif [ -d /sys/class/drm ]; then
      # Check DRM devices as fallback
      INTEL_FOUND=false
      NVIDIA_FOUND=false
      
      for card in /sys/class/drm/card*/device/vendor; do
        if [ -r "$card" ]; then
          vendor=$(cat "$card" 2>/dev/null)
          case "$vendor" in
            "0x8086") INTEL_FOUND=true ;;
            "0x10de") NVIDIA_FOUND=true ;;
          esac
        fi
      done
      
      if [[ "$NVIDIA_FOUND" == "true" ]]; then
        echo "║ • GPU: NVIDIA + Intel (hybrid) [detected via DRM]"
      elif [[ "$INTEL_FOUND" == "true" ]]; then
        echo "║ • GPU: Intel only [detected via DRM]"
      else
        echo "║ • GPU: Unknown configuration [DRM accessible but no recognized vendors]"
      fi
    else
      echo "║ • GPU: Unable to detect (limited runtime environment)"
      echo "║   ℹ️  Build-time detection shows: ${
        systemConfig.currentSystem.description or "Unknown"
      }"
    fi

    echo "╚═══════════════════════════════════════════════════╝"
  '';
}
