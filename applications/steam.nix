{ pkgs, lib, config, ... }:

{
  # Add Steam and related packages directly
  home.packages = with pkgs; [
    # Steam client
    steam

    # Additional Steam-related utilities
    steamtinkerlaunch # Helper for launching Steam games with custom settings
    gamescope # SteamOS session compositing window manager (useful for some games)
  ];

  # Create a small wrapper script that prefers the system runtime (disable Steam's bundled runtime)
  # and sets common GPU environment variables for hybrid systems. This avoids some pressure-vessel
  # / steamrt conflicts where the bundled runtime can't find 32-bit or GLX providers.
  home.file.".local/bin/steam-nix-wrapper" = {
    text = ''
      #!/usr/bin/env bash
            # Prefer system libraries over Steam's runtime
            export STEAM_RUNTIME=0

            # Force X11 (helps when Wayland/Xwayland GLX visuals are problematic)
            export WAYLAND_DISPLAY=""

            # If system has NVIDIA available, enable prime render offload and set GLX vendor
            if command -v nvidia-smi &>/dev/null; then
              export __GLX_VENDOR_LIBRARY_NAME=nvidia
              export __NV_PRIME_RENDER_OFFLOAD=1
            fi

            # Run Steam (fall back to steam binary in PATH)
            exec steam "$@"
    '';
    executable = true;
  };

  # Create a desktop entry that uses the wrapper so launching from GNOME/menus uses the safer env
  home.file.".local/share/applications/steam-nix-wrapper.desktop" = {
    text = ''
      [Desktop Entry]
          Name=Steam (system runtime)
          Comment=Steam (prefer system libs, wrapper)
          Exec=$HOME/.local/bin/steam-nix-wrapper %U
          Icon=steam
          Type=Application
          StartupNotify=false
          Categories=Game;Entertainment;
    '';
  };

  # Note: proton-ge-bin was removed as it was causing build failures
  # If you need Proton GE, consider installing it through Steam's compatibility tool interface
  # or use an alternative method to manage Proton GE versions
}
