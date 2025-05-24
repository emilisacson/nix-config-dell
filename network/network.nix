{ pkgs, ... }:

{
  # Import specific network modules
  imports = [ ./vpn.nix ];

  # Install basic network utilities
  home.packages = with pkgs; [
    networkmanager-openvpn
    networkmanagerapplet # Network manager applet for the system tray
    inetutils # Basic network utilities (ping, ifconfig, etc.)
    dig # DNS lookup utility
    whois # Domain information lookup utility
  ];
}
