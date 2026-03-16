{ pkgs, unstable, lib, config, ... }:

let
  # Toggle between VS Code Insiders and stable version
  useInsiders = true; # Set to false to use stable version

  vscodePackage = if useInsiders then
  # VS Code Insiders version
  # Manual download: https://code.visualstudio.com/sha/download?build=insider&os=linux-x64
  # Empty the sha256 to update the package to the latest version
  # Or use the following to get the latest hash directly:
  #   nix-prefetch-url --unpack https://update.code.visualstudio.com/latest/linux-x64/insider
    (pkgs.vscode.override { isInsiders = true; }).overrideAttrs (oldAttrs: rec {
      src = (builtins.fetchTarball {
        url = "https://update.code.visualstudio.com/latest/linux-x64/insider";
        sha256 = "sha256:12xxhkk7klmi3qdgnnd0581928r3xl1ldx9jrprmvaz01axrlrnk";
      });
      version = "latest";
      buildInputs = oldAttrs.buildInputs
        ++ [ pkgs.krb5 pkgs.webkitgtk_4_1 pkgs.libsoup_3 ];
      postInstall = (oldAttrs.postInstall or "") + ''
        # Create a 'code' symlink for VS Code Insiders
        ln -sf $out/bin/code-insiders $out/bin/code || true

        # Create a standard 'code.desktop' entry for GNOME launcher
        if [ -f $out/share/applications/code-insiders.desktop ]; then
          cp $out/share/applications/code-insiders.desktop $out/share/applications/code.desktop
          # Update the desktop entry to use the generic 'code' command
          sed -i 's/code-insiders/code/g' $out/share/applications/code.desktop
          sed -i 's/Code - Insiders/Visual Studio Code/g' $out/share/applications/code.desktop
          sed -i 's/Visual Studio Code - Insiders/Visual Studio Code/g' $out/share/applications/code.desktop
        fi
      '';
    })
  else
  # VS Code stable version
  # Empty the sha256 to update the package to the latest version
  # Or use the following to get the latest hash directly:
  #   nix-prefetch-url --unpack https://update.code.visualstudio.com/latest/linux-x64/stable
    (pkgs.vscode.override { }).overrideAttrs (oldAttrs: rec {
      src = (builtins.fetchTarball {
        url = "https://update.code.visualstudio.com/latest/linux-x64/stable";
        sha256 = "sha256:08nbnqc388155jnyy4ny7xdx4r6qhsdy3djhaayskw2dq952vsh5";
      });
      version = "latest";
      buildInputs = oldAttrs.buildInputs ++ [ pkgs.krb5 pkgs.nixfmt-classic ];
    });
in {
  # VS Code configuration with configurable version
  programs.vscode = {
    enable = true;
    package = vscodePackage;

    # Allow VS Code to manage extensions
    mutableExtensionsDir = true;

    # Just install the extensions, but let VS Code manage the settings
    profiles.default = {
      extensions = let
        yutengjing-modify-file-warning =
          unstable.vscode-utils.extensionFromVscodeMarketplace {
            name = "modify-file-warning";
            publisher = "yutengjing";
            version = "1.0.0";
            sha256 = "sha256-U86l4XIfr2LVD93tU6wfMREvnRGejnJWxDaLJAXiJes=";
          };
        /* automatalabs-copilot-mcp =
             unstable.vscode-utils.extensionFromVscodeMarketplace {
               name = "copilot-mcp";
               publisher = "automatalabs";
               version = "0.0.49";
               sha256 = "sha256-+G2OQl5SCN7bh7MzGdYiRclIZefBE7lWnGg1kNpCvnA=";
             };

           };
        */
      in with unstable.vscode-extensions; [
        arrterian.nix-env-selector
        jnoortheen.nix-ide
        github.copilot
        github.copilot-chat
        ms-python.python
        ms-python.vscode-pylance
        ms-vscode-remote.remote-containers # Dev Containers extension
        shd101wyy.markdown-preview-enhanced
        vscodevim.vim
        # vintharas.learn-vim # Extension not available in nixpkgs
        yutengjing-modify-file-warning # Custom extension from marketplace
        #automatalabs-copilot-mcp # Copilot MCP extension for managing MCP servers
        #copilot-taskmaster-extension # Copilot Taskmaster extension from GitHub
      ];
    };
  };

  # Make nixfmt and Node.js (for npx) available in PATH for VS Code
  home.packages = [
    pkgs.nixfmt-classic
    pkgs.nodejs_22 # Provides npx for MCP servers
  ] ++ lib.optionals (config.systemSpecs.hasIntelGPU or false) [
    pkgs.nixgl.nixGLIntel # Include Intel support
  ] ++ lib.optionals (config.systemSpecs.hasNvidiaGPU or false) [
    # Use explicit NVIDIA version to avoid auto-detection issues
    (pkgs.nixgl.override { nvidiaVersion = "575.64.03"; }).auto.nixGLNvidia
  ];

  # Add an activation script to set up VS Code settings
  home.activation.vscodeProfiles = lib.mkForce
    (lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      echo "Setting up VS Code settings..."
      $DRY_RUN_CMD ${config.home.homeDirectory}/.nix-config/extras/setup-vscode-settings.sh
    '');

  # Create a wrapper script for VS Code with nixGL
  home.file.".local/bin/code-nixgl" = {
    text = ''
      #!/usr/bin/env bash
      # VS Code launcher with nixGL for graphics support
      # Using --disable-gpu and --max-memory=4096 to prevent freezing issues
      # Setting WAYLAND_DISPLAY="" to force X11 instead of Wayland

      # Force X11 instead of Wayland to prevent freezing issues
      export WAYLAND_DISPLAY=""

      # Try to detect the best nixGL wrapper to use (prefer specific NVIDIA version that works)
      if command -v nixGLNvidia-575.64.03 &> /dev/null; then
          echo "Using nixGLNvidia-575.64.03 for VS Code with GPU acceleration disabled and memory limited (X11 mode)..."
          exec nixGLNvidia-575.64.03 code --disable-gpu --max-memory=4096 "$@"
      elif command -v nixGLNvidia &> /dev/null; then
          echo "Using nixGLNvidia for VS Code with GPU acceleration disabled and memory limited (X11 mode)..."
          exec nixGLNvidia code --disable-gpu --max-memory=4096 "$@"
      elif command -v nixGLIntel &> /dev/null; then
          echo "Using nixGLIntel for VS Code with GPU acceleration disabled and memory limited (X11 mode)..."
          exec nixGLIntel code --disable-gpu --max-memory=4096 "$@"
      elif command -v nixGLDefault &> /dev/null; then
          echo "Using nixGLDefault for VS Code with GPU acceleration disabled and memory limited (X11 mode)..."
          exec nixGLDefault code --disable-gpu --max-memory=4096 "$@"
      else
          echo "No nixGL wrapper found, running VS Code directly with GPU acceleration disabled and memory limited (X11 mode)..."
          echo "This should help prevent freezing issues."
          exec code --disable-gpu --max-memory=4096 "$@"
      fi
    '';
    executable = true;
  };

  # Create a custom desktop entry that uses the nixGL wrapper
  home.file.".local/share/applications/code-nixgl.desktop" = {
    text = ''
      [Desktop Entry]
      Name=Visual Studio Code (nixGL)
      Comment=Code Editing. Redefined. With hardware acceleration.
      GenericName=Text Editor
      Exec=code-nixgl %F
      Icon=vscode
      Type=Application
      StartupNotify=false
      StartupWMClass=Code
      Categories=TextEditor;Development;IDE;
      MimeType=text/plain;inode/directory;application/x-code-workspace;
      Actions=new-empty-window;
      Keywords=vscode;

      [Desktop Action new-empty-window]
      Name=New Empty Window
      Exec=code-nixgl --new-window %F
      Icon=vscode
    '';
  };

  # Hide the original VS Code desktop entry to avoid duplicates
  home.file.".local/share/applications/code.desktop" = {
    text = ''
      [Desktop Entry]
      Hidden=true
    '';
  };
}

#TODO: Add extension specific configurations
