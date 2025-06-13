{ config, pkgs, lib, ... }:

{
  # Install Evolution and related packages
  home.packages = with pkgs; [
    evolution
    evolution-data-server
    evolution-ews # Exchange Web Services support for O365
    gnome-calendar # Calendar integration with Evolution
    gnome-online-accounts # For online account integration
    gnome-keyring
    #webkitgtk # WebKit for rendering HTML emails
    #glib-networking # SSL/TLS support for secure connections
    #gsettings-desktop-schemas # Desktop integration schemas
    #libsecret # Keyring integration for OAuth tokens
    #gcr # Certificate and key management
  ];

  # Set environment variables for Evolution to fix WebKit issues
  /* home.sessionVariables = {
       # Fix WebKit sandbox issues
       WEBKIT_DISABLE_COMPOSITING_MODE = "1";
       WEBKIT_DISABLE_SANDBOX = "1";
       # Ensure Evolution finds the correct webkit
       GST_PLUGIN_SYSTEM_PATH_1_0 =
         "${pkgs.gst_all_1.gst-plugins-base}/lib/gstreamer-1.0:${pkgs.gst_all_1.gst-plugins-good}/lib/gstreamer-1.0:${pkgs.gst_all_1.gst-plugins-bad}/lib/gstreamer-1.0";
     };
  */

  # Configure Evolution dconf settings
  dconf.settings = {
    # Evolution mail settings (correct schema path)
    "org/gnome/evolution/mail" = {
      layout = 1; # 0 = classic view, 1 = vertical view
      forward-style-name =
        "attached"; # Forwarding style: inline, attached, quoted
      reply-style-name = "quoted"; # Reply style
      composer-reply-start-bottom =
        true; # Start typing at the bottom when replying
      browser-close-on-reply-policy =
        "ask"; # Ask before closing browser windows
      # image-loading-policy = "never"; # Never load images automatically for security
    };

    # Evolution calendar settings
    "org/gnome/evolution/calendar" = {
      use-24hour-format = true; # Use 24-hour format for time
      week-start-day-name = "monday"; # Start week on Monday
      show-week-numbers = true; # Show week numbers
      editor-show-timezone = true; # Show time zone in editor
    };

    # Evolution shell settings
    "org/gnome/evolution/shell" = {
      default-component-id = "mail"; # Start with mail component
      start-offline = false; # Start online
    };
  }; # Set Evolution as default email client using Home Manager's xdg configuration
  xdg.mimeApps = {
    enable = true;
    defaultApplications = {
      "x-scheme-handler/mailto" = [ "org.gnome.Evolution.desktop" ];
      "message/rfc822" = [ "org.gnome.Evolution.desktop" ];
      "application/x-extension-eml" = [ "org.gnome.Evolution.desktop" ];
    };
  };
}
