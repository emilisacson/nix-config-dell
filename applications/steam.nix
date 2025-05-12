{ pkgs, ... }:

{
  # Add Steam and related packages directly
  home.packages = with pkgs; [
    # Steam client
    steam
    
    # Additional Steam-related utilities
    steamtinkerlaunch  # Helper for launching Steam games with custom settings
    gamescope         # SteamOS session compositing window manager (useful for some games)
  ];
  
  # Note: proton-ge-bin was removed as it was causing build failures
  # If you need Proton GE, consider installing it through Steam's compatibility tool interface
  # or use an alternative method to manage Proton GE versions
}