{ config, lib, ... }:

let
  # Pure orientation-based dash-to-panel configuration
  systemSpecs = config.systemSpecs;

  # Generate dash-to-panel configuration from detected system specs
  allMonitors = systemSpecs.displays.monitors or [ ];
  primaryMonitor = systemSpecs.displays.primary or "unknown";

  # Generate panel configuration based purely on monitor orientation
  generateDashToPanelConfig = let
    # For each monitor, determine the panel position based on orientation
    monitorConfigs = builtins.map (monitor: {
      panel_id = monitor.panel_id;
      # Pure orientation-based logic: portrait = TOP, landscape = RIGHT
      position =
        if monitor.actual_orientation == "portrait" then "TOP" else "RIGHT";
      size = 48; # Standard panel size
      length = -1;
      anchor = "MIDDLE";
    }) allMonitors;

    # Convert to the format dash-to-panel expects
    panelPositions = builtins.listToAttrs (builtins.map (config: {
      name = config.panel_id;
      value = config.position;
    }) monitorConfigs);

    panelSizes = builtins.listToAttrs (builtins.map (config: {
      name = config.panel_id;
      value = config.size;
    }) monitorConfigs);

    panelLengths = builtins.listToAttrs (builtins.map (config: {
      name = config.panel_id;
      value = config.length;
    }) monitorConfigs);

    panelAnchors = builtins.listToAttrs (builtins.map (config: {
      name = config.panel_id;
      value = config.anchor;
    }) monitorConfigs);

  in {
    positions = panelPositions;
    sizes = panelSizes;
    lengths = panelLengths;
    anchors = panelAnchors;
  };

  panelConfig = generateDashToPanelConfig;

  # Check if we have any monitors detected
  hasMonitors = systemSpecs.displays.count > 0;

in {
  # This is a proper Home Manager module that sets dconf settings
  dconf.settings = {
    # Dash to Panel settings (dynamically configured based on detected monitors)
    "org/gnome/shell/extensions/dash-to-panel" = if hasMonitors then {
      # Static settings (same for all monitor configurations)
      animate-appicon-hover-animation-extent =
        ''{"RIPPLE": 4, "PLANK": 4, "SIMPLE": 1}'';
      appicon-margin = 8;
      appicon-padding = 4;
      dot-position = "LEFT";
      dot-style-focused = "METRO";
      dot-style-unfocused = "DOTS";
      extension-version = 68;
      group-apps = true;
      hotkeys-overlay-combo = "TEMPORARILY";
      intellihide = false;
      isolate-workspaces = true;

      show-favorites = true;
      show-running-apps = true;
      show-window-previews = true;
      stockgs-keep-top-panel = false;
      stockgs-panelbtn-click-only = false;
      trans-panel-opacity = 0.8;
      trans-use-custom-opacity = true;
      trans-use-dynamic-opacity = true;
      tray-size = 16;
      window-preview-title-position = "TOP";

      # Monitor-specific settings based on detected monitors
      isolate-monitors = systemSpecs.displays.count
        > 1; # Enable workspace isolation for multi-monitor setups
      multi-monitors = systemSpecs.displays.count > 1;
      primary-monitor = if primaryMonitor != "unknown" then 0 else -1;

      # Panel positions: from generated config
      panel-positions = builtins.toJSON panelConfig.positions;

      # Panel sizes: from generated config  
      panel-sizes = builtins.toJSON panelConfig.sizes;

      # Panel lengths: from generated config
      panel-lengths = builtins.toJSON panelConfig.lengths;

      # Panel anchors: from generated config
      panel-anchors = builtins.toJSON panelConfig.anchors;

      # Element positions: generate based on detected monitors
      panel-element-positions = builtins.toJSON (builtins.listToAttrs (map
        (monitor: {
          name = monitor.panel_id;
          value = [
            {
              element = "showAppsButton";
              visible = true;
              position = "stackedTL";
            }
            {
              element = "activitiesButton";
              visible = false;
              position = "stackedTL";
            }
            {
              element = "leftBox";
              visible = true;
              position = "stackedTL";
            }
            {
              element = "taskbar";
              visible = true;
              position = "centerMonitor";
            }
            {
              element = "centerBox";
              visible = true;
              position = "centerMonitor";
            }
            {
              element = "rightBox";
              visible = true;
              position = "stackedBR";
            }
            {
              element = "dateMenu";
              visible = true;
              position = "stackedBR";
            }
            {
              element = "systemMenu";
              visible = true;
              position = "stackedBR";
            }
            {
              element = "desktopButton";
              visible = true;
              position = "stackedBR";
            }
          ];
        }) systemSpecs.displays.monitors));

      panel-element-positions-monitors-sync = false;
      prefs-opened = false;
    } else
      {
        # Fallback settings when no monitors are detected
        # animate-appicon-hover-animation-extent = ''{"RIPPLE": 4, "PLANK": 4, "SIMPLE": 1}'';
        # appicon-margin = 8;
        # appicon-padding = 4;
        # dot-position = "LEFT";
        # dot-style-focused = "METRO";
        # dot-style-unfocused = "DOTS";
        # extension-version = 68;
        # group-apps = true;
        # hotkeys-overlay-combo = "TEMPORARILY";
        # intellihide = false;
        # isolate-workspaces = true;
        # show-favorites = true;
        # show-running-apps = true;
        # show-window-previews = true;
        # stockgs-keep-top-panel = false;
        # stockgs-panelbtn-click-only = false;
        # trans-panel-opacity = 0.8;
        # trans-use-custom-opacity = true;
        # trans-use-dynamic-opacity = true;
        # tray-size = 16;
        # window-preview-title-position = "TOP";

        # isolate-monitors = false;
        # multi-monitors = false;
        # primary-monitor = 0;
        # panel-positions = ''{"fallback-monitor":"RIGHT"}'';
        # panel-sizes = ''{"fallback-monitor":48}'';
        # panel-lengths = ''{"fallback-monitor":100}'';
        # panel-anchors = ''{"fallback-monitor":"MIDDLE"}'';
        # panel-element-positions = ''{"fallback-monitor":[{"element":"showAppsButton","visible":true,"position":"stackedTL"},{"element":"activitiesButton","visible":false,"position":"stackedTL"},{"element":"leftBox","visible":true,"position":"stackedTL"},{"element":"taskbar","visible":true,"position":"centerMonitor"},{"element":"centerBox","visible":true,"position":"centerMonitor"},{"element":"rightBox","visible":true,"position":"stackedBR"},{"element":"dateMenu","visible":true,"position":"stackedBR"},{"element":"systemMenu","visible":true,"position":"stackedBR"},{"element":"desktopButton","visible":true,"position":"stackedBR"}]}'';
        # panel-element-positions-monitors-sync = false;
        # prefs-opened = false;
      }; # End of dash-to-panel dconf settings
  }; # End of dconf.settings
} # End of module
