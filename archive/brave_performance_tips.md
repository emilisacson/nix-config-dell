# Brave Browser Performance Tips

## CPU Performance Mode
For maximum performance during intensive browsing sessions:
```bash
sudo cpupower frequency-set -g performance
```
To revert back to power saving:
```bash
sudo cpupower frequency-set -g powersave
```

## Browser Flags to Test
Navigate to `brave://flags/` and try these experimental features:
- `#enable-gpu-rasterization` - Enable
- `#enable-zero-copy` - Enable  
- `#enable-vulkan` - Enable
- `#enable-quic` - Enable
- `#enable-experimental-web-platform-features` - Enable

## Monitor Performance
- Check GPU usage: `watch -n 1 nvidia-smi`
- Check graphics status: `~/.nix-config/debug_brave_performance.sh`
- Launch with performance mode: `~/.local/bin/brave-performance`

## Troubleshooting
If animations are still laggy:
1. Check `brave://gpu/` for any disabled features
2. Try disabling some extensions temporarily
3. Reset Brave flags to default if issues persist
4. Consider using the performance CPU governor during heavy usage

## NVIDIA Optimus Note
Your laptop has hybrid graphics (Intel + NVIDIA). The system should automatically use the NVIDIA GPU for demanding applications, but you can force it with:
```bash
__NV_PRIME_RENDER_OFFLOAD=1 __GLX_VENDOR_LIBRARY_NAME=nvidia brave
```
