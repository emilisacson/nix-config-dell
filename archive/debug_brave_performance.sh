#!/usr/bin/env bash

echo "=== Brave Browser Performance Diagnostic ==="
echo "Date: $(date)"
echo ""

echo "=== System Information ==="
echo "Kernel: $(uname -r)"
echo "Session Type: $XDG_SESSION_TYPE"
echo "Current Desktop: $XDG_CURRENT_DESKTOP"
echo ""

echo "=== Graphics Hardware ==="
lspci | grep -E "(VGA|3D|Graphics)"
echo ""

echo "=== NVIDIA Status ==="
if command -v nvidia-smi &> /dev/null; then
    nvidia-smi --query-gpu=name,driver_version,utilization.gpu,utilization.memory --format=csv,noheader,nounits
else
    echo "NVIDIA drivers not available"
fi
echo ""

echo "=== GPU Memory Usage ==="
if command -v nvidia-smi &> /dev/null; then
    nvidia-smi --query-gpu=memory.used,memory.total --format=csv,noheader,nounits
fi
echo ""

echo "=== Wayland Compositor ==="
if [[ "$XDG_SESSION_TYPE" == "wayland" ]]; then
    echo "Running on Wayland"
    ps aux | grep -E "(gnome-shell|mutter)" | grep -v grep | head -3
else
    echo "Not running on Wayland"
fi
echo ""

echo "=== CPU Governor ==="
if [ -f /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor ]; then
    echo "Current CPU governor: $(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor)"
else
    echo "CPU governor information not available"
fi
echo ""

echo "=== Browser Process Check ==="
if pgrep -f brave &> /dev/null; then
    echo "Brave processes currently running:"
    ps aux | grep -E "(brave|chromium)" | grep -v grep | wc -l
    echo "Total Brave processes: $(pgrep -f brave | wc -l)"
else
    echo "No Brave processes currently running"
fi
echo ""

echo "=== Chrome/Brave GPU Status Test ==="
echo "To test GPU acceleration in Brave:"
echo "1. Open Brave browser"
echo "2. Navigate to: brave://gpu/"
echo "3. Check that 'Graphics Feature Status' shows 'Hardware accelerated' for:"
echo "   - Canvas: Hardware accelerated"
echo "   - Compositing: Hardware accelerated"
echo "   - Multiple Raster Threads: Enabled"
echo "   - OpenGL: Enabled"
echo "   - Rasterization: Hardware accelerated"
echo "   - Video Decode: Hardware accelerated"
echo ""

echo "=== Recommended Browser Test Pages ==="
echo "Test CSS animation performance on these pages:"
echo "- https://webkit.org/blog-files/3d-transforms/morphing-cubes.html"
echo "- https://css-tricks.com/examples/Animations/"
echo "- https://codepen.io/collection/HtAne/"
echo ""

echo "=== Performance Tips ==="
echo "1. Restart Brave after configuration changes"
echo "2. Close unnecessary tabs and extensions"
echo "3. Check brave://flags/ for experimental features"
echo "4. Monitor GPU usage with: watch -n 1 nvidia-smi"
echo "5. Consider using the performance script: ~/.local/bin/brave-performance"
