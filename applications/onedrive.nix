{ config, pkgs, lib, ... }:

{
  # Install OneDrive clients and GUI tools
  home.packages = with pkgs; [
    # Base OneDrive client (CLI)
    onedrive
    
    # GUI for OneDrive
    onedrivegui
  ];

  # Add autostart entry for OneDriveGUI
  xdg.desktopEntries.onedrivegui-autostart = {
    name = "OneDriveGUI";
    exec = "onedrivegui";
    icon = "onedrivegui";
    comment = "GUI for OneDrive Client";
    categories = [ "Utility" ];
    terminal = false;
    startupNotify = false;
  };

  # Ensure OneDriveGUI autostart
  xdg.configFile."autostart/onedrivegui.desktop" = {
    text = ''
      [Desktop Entry]
      Name=OneDriveGUI
      Exec=onedrivegui
      Icon=onedrivegui
      Comment=GUI for OneDrive Client
      Categories=Utility;
      Terminal=false
      StartupNotify=false
      Type=Application
    '';
  };
}
