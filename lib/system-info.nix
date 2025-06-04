{ config, lib, ... }:

{
  # Add activation script to show system detection report when rebuilding
  home.activation.showSystemType = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    echo "╔═══════════════════════════════════════════════════╗"
    echo "║ 🖥️  System Detection Report"
    echo "╠═══════════════════════════════════════════════════╣"

    # SECTION 1: Detection Method & Status
    echo "║ 🔍 Detection Method:"
    echo "║ • Detection script: ./extras/detect-system-specs.sh"
    echo "║ • JSON file: ~/.nix-config/system-specs.json"
    echo "║ • System ID: ${config.systemSpecs.system_id}"
    echo "║ • Generated: ${config.systemSpecs.detection_timestamp}"

    echo "╠═══════════════════════════════════════════════════╣"
    # SECTION 2: System Specifications
    echo "║ 💻 System Specifications:"
    echo "║ • Hostname: ${config.systemSpecs.hostname}"
    echo "║ • OS: ${config.systemSpecs.os_name} ${config.systemSpecs.os_version}"
    echo "║ • Architecture: ${config.systemSpecs.architecture}"
    echo "║ • Kernel: ${config.systemSpecs.kernel or "unknown"}"
    echo "║ • CPU: ${config.systemSpecs.cpu_model}"
    echo "║ • CPU Cores: ${toString config.systemSpecs.cpu_cores}"
    echo "║ • Memory: ${toString config.systemSpecs.memory_gb} GB"
    echo "║ • Laptop: ${if config.systemSpecs.is_laptop then "Yes" else "No"}"
    echo "║"
    echo "║ 🎮 GPU Configuration:"
    ${let
      gpuVendors = builtins.map (gpu: gpu.vendor) config.systemSpecs.gpus;
      gpuModels = builtins.map (gpu: "${gpu.vendor} ${gpu.model}")
        config.systemSpecs.gpus;
    in if builtins.length config.systemSpecs.gpus > 0 then ''
      echo "║ • GPUs: ${builtins.concatStringsSep ", " gpuModels}"
      echo "║ • NVIDIA GPU: ${
        if config.systemSpecs.hasNvidiaGPU then "✅ Yes" else "❌ No"
      }"
      echo "║ • Intel GPU: ${
        if config.systemSpecs.hasIntelGPU then "✅ Yes" else "❌ No"
      }"
      echo "║ • AMD GPU: ${
        if config.systemSpecs.hasAMDGPU then "✅ Yes" else "❌ No"
      }"
    '' else ''
      echo "║ • GPUs: None detected"
      echo "║ • GPU flags: All disabled (fallback mode)"
    ''}

    # SECTION 3: Monitor Configuration
    echo "║"
    echo "║ 📺 Monitor Configuration:"
    echo "║ • Monitor count: ${toString config.systemSpecs.displays.count}"
    ${if config.systemSpecs.displays.count > 0 then ''
      echo "║ • Primary monitor: ${config.systemSpecs.displays.primary}"
      ${builtins.concatStringsSep "\n" (builtins.map (monitor: ''
        echo "║ • ${monitor.name}: ${toString monitor.width}×${
          toString monitor.height
        } (${monitor.orientation})"
      '') config.systemSpecs.displays.monitors)}
    '' else ''
      echo "║ • No monitors detected in JSON file"
    ''}

    echo "╚═══════════════════════════════════════════════════╝"
  '';
}
