#!/usr/bin/env bash

# Test script for system detection (standalone version)
# This script tests the actual detection logic without Nix evaluation

echo "🔍 Testing System Detection..."
echo "════════════════════════════════"

# Initialize variables
VENDOR=""
MODEL=""
GPU_CONFIG=""

# Try to detect vendor and model
echo "📋 Detecting DMI information..."
if [ -f /sys/class/dmi/id/sys_vendor ] && [ -r /sys/class/dmi/id/sys_vendor ]; then
  VENDOR=$(cat /sys/class/dmi/id/sys_vendor 2>/dev/null | tr -d '\n' | tr -d '\r' | sed 's/^[ \t]*//;s/[ \t]*$//')
  echo "  ✅ Vendor detected: '$VENDOR'"
else
  echo "  ❌ Cannot read /sys/class/dmi/id/sys_vendor"
fi

if [ -f /sys/class/dmi/id/product_name ] && [ -r /sys/class/dmi/id/product_name ]; then
  MODEL=$(cat /sys/class/dmi/id/product_name 2>/dev/null | tr -d '\n' | tr -d '\r' | sed 's/^[ \t]*//;s/[ \t]*$//')
  echo "  ✅ Model detected: '$MODEL'"
else
  echo "  ❌ Cannot read /sys/class/dmi/id/product_name"
fi

# Try to detect GPU configuration
echo ""
echo "🎮 Detecting GPU configuration..."
if command -v lspci >/dev/null 2>&1; then
  echo "  ✅ lspci command available"
  if lspci | grep -i nvidia >/dev/null 2>&1; then
    GPU_CONFIG="nvidia-intel"
    echo "  ✅ NVIDIA GPU detected"
  else
    GPU_CONFIG="intel-only"
    echo "  ✅ Intel-only GPU configuration"
  fi
else
  echo "  ❌ lspci command not available"
fi

echo ""
echo "📊 Detection Results:"
echo "════════════════════════════════"

# Build system type string based on what we detected
if [ -n "$VENDOR" ] && [ -n "$MODEL" ] && [ -n "$GPU_CONFIG" ]; then
  if [[ "$VENDOR" == "LENOVO" || "$VENDOR" == "Lenovo" ]]; then
    SYSTEM_TYPE="lenovo-$MODEL-$GPU_CONFIG"
    echo "  🏷️  System Type: $SYSTEM_TYPE"
    echo "  ✅ Full detection successful"
  elif [[ "$VENDOR" == "Dell Inc." || "$VENDOR" == "DELL" ]]; then
    SYSTEM_TYPE="dell-$MODEL-$GPU_CONFIG"
    echo "  🏷️  System Type: $SYSTEM_TYPE"
    echo "  ✅ Full detection successful"
  else
    SYSTEM_TYPE="$VENDOR-$MODEL-$GPU_CONFIG"
    echo "  🏷️  System Type: $SYSTEM_TYPE"
    echo "  ⚠️  Unknown vendor, but full detection successful"
  fi
elif [ -n "$GPU_CONFIG" ]; then
  # We can detect GPU but not vendor/model
  SYSTEM_TYPE="unable-to-detect-vendor-model-$GPU_CONFIG"
  echo "  🏷️  System Type: $SYSTEM_TYPE"
  echo "  ⚠️  Partial detection: GPU only"
else
  # Cannot detect anything
  SYSTEM_TYPE="unable-to-detect-system"
  echo "  🏷️  System Type: $SYSTEM_TYPE"
  echo "  ❌ Detection failed"
fi

echo ""
echo "📋 Summary:"
echo "  • Vendor: ${VENDOR:-"unable-to-detect"}"
echo "  • Model: ${MODEL:-"unable-to-detect"}"
echo "  • GPU Config: ${GPU_CONFIG:-"unable-to-detect"}"
echo "  • Final System Type: $SYSTEM_TYPE"

# Test if this would work in our Nix configuration
echo ""
echo "🧪 Nix Configuration Test:"
echo "════════════════════════════════"

case "$SYSTEM_TYPE" in
  *nvidia-intel)
    echo "  ✅ Would enable NVIDIA configurations"
    ;;
  *intel-only)
    echo "  ✅ Would use Intel-only configurations"
    ;;
  unable-to-detect-*)
    echo "  ⚠️  Would use safe fallback configurations"
    ;;
  *)
    echo "  ❌ Unexpected system type format"
    ;;
esac

echo ""
echo "🎯 Test completed!"
