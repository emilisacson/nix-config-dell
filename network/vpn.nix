{ pkgs, ... }:

{
  # Install OpenConnect VPN and related tools
  home.packages = with pkgs; [
    # OpenConnect VPN client (open source alternative to Cisco AnyConnect)
    openconnect

    # NetworkManager integration
    networkmanager-openconnect

    # GUI front-end for OpenConnect
    networkmanager-vpnc
  ];

  # You can add specific OpenConnect configurations here if needed
  # For example, you might want to create desktop entries or scripts
  # to connect to specific VPNs with custom parameters

  # Example script to connect to a specific VPN (uncomment and modify as needed)
  # home.file.".local/bin/connect-to-work-vpn" = {
  #   executable = true;
  #   text = ''
  #     #!/bin/sh
  #     echo "Connecting to work VPN..."
  #     sudo openconnect --protocol=anyconnect \
  #       --user=yourusername \
  #       --no-dtls \
  #       vpn.example.com
  #   '';
  # };
}
