{ config, lib, systemConfig ? null, ... }:

{
  # Add activation script to show system type when rebuilding
  home.activation.showSystemType = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    echo ""
    echo "╔════════════════════════════════════════╗"
    echo "║       System Configuration Info        ║"
    echo "╚════════════════════════════════════════╝"
    echo "• System Type: ${
      if systemConfig != null then
        (if systemConfig ? currentSystem && systemConfig.currentSystem
        ? description then
          systemConfig.currentSystem.description
        else
          "Unknown attributes")
      else
        "Unknown"
    }"
    echo "• System Detected: ${
      if systemConfig != null && systemConfig ? currentSystemType then
        systemConfig.currentSystemType
      else
        "Unknown"
    }"
    echo "• NVIDIA GPU:  ${
      if systemConfig != null && systemConfig ? currentSystem
      && systemConfig.currentSystem ? hasNvidia then
        (if systemConfig.currentSystem.hasNvidia then
          "Present"
        else
          "Not detected")
      else
        "Unknown"
    }"
    echo "• Intel GPU:   ${
      if systemConfig != null && systemConfig ? currentSystem
      && systemConfig.currentSystem ? hasIntel then
        (if systemConfig.currentSystem.hasIntel then
          "Present"
        else
          "Not detected")
      else
        "Unknown"
    }"
    echo ""
  '';
}
