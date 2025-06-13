{ pkgs, unstable, lib, config, ... }:

let
  # Toggle between VS Code Insiders and stable version
  useInsiders = false; # Set to false to use stable version

  vscodePackage = if useInsiders then
  # VS Code Insiders version
    (pkgs.vscode.override { isInsiders = true; }).overrideAttrs (oldAttrs: rec {
      src = (builtins.fetchTarball {
        url =
          "https://code.visualstudio.com/sha/download?build=insider&os=linux-x64";
        sha256 = "sha256:0yad7xdr28lbq4m0h97fapzifjbkb47m6ds6szzalpz8m9lc1hvj";
      });
      version = "latest";
      buildInputs = oldAttrs.buildInputs ++ [ pkgs.krb5 ];
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
        sha256 =
          "sha256:15g1is7km8n5zc8nps1ajv2vsqhkz8sp7jjhx7zch0g9by6dn51v"; # "sha256:1gicmx3lkifigwr6dqf8gghbm1fmiafdzrbw2x5069absji3x6pg";
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
        automatalabs-copilot-mcp =
          unstable.vscode-utils.extensionFromVscodeMarketplace {
            name = "copilot-mcp";
            publisher = "automatalabs";
            version = "0.0.49";
            sha256 = "sha256-+G2OQl5SCN7bh7MzGdYiRclIZefBE7lWnGg1kNpCvnA=";
          };

        # Custom extension built from GitHub source
        copilot-taskmaster-extension = pkgs.buildNpmPackage rec {
          pname = "copilot-taskmaster-extension";
          version = "1.0.0";

          src = pkgs.fetchFromGitHub {
            owner = "lookatitude";
            repo = "copilot-taskmaster-extension";
            rev = "main";
            sha256 = "sha256-cwS/Gz4G8LgNaCH5ftI7T0dQPf15GIFNQSoLdmonwpE=";
          };

          npmDepsHash = "sha256-XpVJWqEreLGxM3Uc2WNg0+k9D72A9HduQHPjfloeC7Q=";

          buildPhase = ''
                        runHook preBuild

                        # Build the extension with TypeScript
                        npm run build

                        # Fix the package.json to include required VS Code extension metadata
                        cat > package.json << 'EOF'
            {
              "name": "copilot-taskmaster-extension",
              "displayName": "Copilot Taskmaster Extension",
              "description": "A GitHub Copilot chat extension that integrates with the Taskmaster-AI MCP server.",
              "version": "1.0.0",
              "publisher": "lookatitude",
              "engines": {
                "vscode": "^1.99.0"
              },
              "categories": ["Other"],
              "main": "./out/extension.js",
              "activationEvents": [
                "onCommand:copilot-taskmaster.start",
                "onCommand:copilot-taskmaster.sendMessage",
                "onCommand:copilot-taskmaster.disconnect"
              ],
              "contributes": {
                "commands": [
                  {
                    "command": "copilot-taskmaster.start",
                    "title": "Copilot Taskmaster: Start"
                  },
                  {
                    "command": "copilot-taskmaster.sendMessage",
                    "title": "Copilot Taskmaster: Send Message"
                  },
                  {
                    "command": "copilot-taskmaster.disconnect",
                    "title": "Copilot Taskmaster: Disconnect"
                  }
                ]
              },
              "dependencies": {
                "axios": "^1.9.0",
                "ws": "^7.4.6"
              }
            }
            EOF

                        runHook postBuild
          '';

          installPhase = ''
            runHook preInstall

            mkdir -p $out/share/vscode/extensions/lookatitude.copilot-taskmaster-extension
            cp -r . $out/share/vscode/extensions/lookatitude.copilot-taskmaster-extension/

            runHook postInstall
          '';

          passthru = {
            vscodeExtPublisher = "lookatitude";
            vscodeExtName = "copilot-taskmaster-extension";
            vscodeExtUniqueId = "lookatitude.copilot-taskmaster-extension";
          };

          meta = with lib; {
            description =
              "A GitHub Copilot chat extension that integrates with the Taskmaster-AI MCP server";
            homepage =
              "https://github.com/lookatitude/copilot-taskmaster-extension";
            license = licenses.mit;
            maintainers = [ ];
            platforms = platforms.all;
          };
        };
      in with unstable.vscode-extensions; [
        arrterian.nix-env-selector
        jnoortheen.nix-ide
        github.copilot
        github.copilot-chat
        ms-python.python
        ms-python.vscode-pylance
        shd101wyy.markdown-preview-enhanced
        vscodevim.vim
        # vintharas.learn-vim # Extension not available in nixpkgs
        yutengjing-modify-file-warning # Custom extension from marketplace
        automatalabs-copilot-mcp # Copilot MCP extension for managing MCP servers
        copilot-taskmaster-extension # Copilot Taskmaster extension from GitHub
      ];
    };
  };

  # Make nixfmt and Node.js (for npx) available in PATH for VS Code
  home.packages = [
    pkgs.nixfmt-classic
    pkgs.nodejs_22 # Provides npx for MCP servers
  ];

  # Add an activation script to set up VS Code settings
  home.activation.vscodeProfiles = lib.mkForce
    (lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      echo "Setting up VS Code settings..."
      $DRY_RUN_CMD ${config.home.homeDirectory}/.nix-config/extras/setup-vscode-settings.sh
    '');
}

#TODO: Add extension specific configurations
