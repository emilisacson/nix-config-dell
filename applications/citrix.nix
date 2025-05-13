{ pkgs, config, lib, ... }:

let
  # Read the Citrix version information from the JSON file created by download-citrix-latest.sh
  citrixInfoFile = "${config.home.homeDirectory}/.cache/citrix-workspace-latest.json";
  
  # Default values in case the file doesn't exist yet
  defaultCitrixInfo = {
    version = "25.03.0.66";  # Fallback to known version
    sha256 = "052zibykhig9091xl76z2x9vn4f74w5q8i9frlpc473pvfplsczk";
    filename = "linuxx64-25.03.0.66.tar.gz";
  };
  
  # Try to read the JSON file, fall back to defaults if not found
  citrixInfo = 
    if builtins.pathExists citrixInfoFile
    then builtins.fromJSON (builtins.readFile citrixInfoFile)
    else defaultCitrixInfo;
    
  # Create a custom Citrix Workspace package based on the downloaded version
  citrix_workspace_custom = pkgs.citrix_workspace.overrideAttrs (oldAttrs: {
    pname = "citrix-workspace-custom";
    version = citrixInfo.version;
    src = pkgs.fetchurl {
      url = "file://${config.home.homeDirectory}/Downloads/${citrixInfo.filename}";
      sha256 = citrixInfo.sha256;
    };
    
    # Add missing dependencies
    buildInputs = (oldAttrs.buildInputs or []) ++ [ pkgs.sane-backends ];
    
    # If adding the dependency doesn't work, we can tell the auto-patchelf to ignore the missing library
    autoPatchelfIgnoreMissingDeps = [ "libsane.so.1" ];
  });
in
{
  # Citrix Workspace configuration
  home.packages = [
    # Using the dynamically determined Citrix Workspace version
    citrix_workspace_custom
  ];
}