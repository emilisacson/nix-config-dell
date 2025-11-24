{ config, pkgs, lib, ... }:

{
  # Install Podman and related tools
  home.packages = with pkgs; [
    podman
    podman-compose
    podman-tui # Terminal UI for managing containers
    buildah # Container image building tool
    skopeo # Container image management
    runc # Container runtime
    crun # Alternative container runtime (faster)
    slirp4netns # User-mode networking for unprivileged containers
    fuse-overlayfs # Overlay filesystem for rootless containers
  ];

  # Configure Podman for rootless operation
  home.file.".config/containers/storage.conf".text = ''
    [storage]
    driver = "overlay"
    runroot = "/run/user/1000/containers"
    graphroot = "/home/${config.home.username}/.local/share/containers/storage"

    [storage.options]
    additionalimagestores = [
    ]

    [storage.options.overlay]
    mountopt = "nodev,metacopy=on"
  '';

  home.file.".config/containers/containers.conf".text = ''
    [containers]
    default_capabilities = [
      "CHOWN",
      "DAC_OVERRIDE", 
      "FOWNER",
      "FSETID",
      "KILL",
      "NET_BIND_SERVICE",
      "SETFCAP",
      "SETGID",
      "SETPCAP",
      "SETUID",
      "SYS_CHROOT"
    ]

    default_sysctls = [
      "net.ipv4.ping_group_range=0 0",
    ]

    # Use crun as the default runtime for better performance
    runtime = "crun"

    [network]
    # Use slirp4netns for rootless networking
    network_backend = "netavark"

    [engine]
    # Set compose providers
    compose_providers = ["podman-compose"]
  '';

  # Add shell aliases for convenience
  home.shellAliases = {
    docker = "podman"; # Alias docker to podman for compatibility
    dc = "podman-compose";
    pd = "podman";
    pps = "podman ps";
    pi = "podman images";
    prm = "podman rm";
    prmi = "podman rmi";
    plog = "podman logs";
    pexec = "podman exec -it";
  };

  # Set DOCKER_HOST environment variable for Docker compatibility
  home.sessionVariables = {
    DOCKER_HOST = "unix:///run/user/1000/podman/podman.sock";
  };

  # Activation script to ensure Podman socket is set up and running
  home.activation.setupPodmanSocket =
    lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      echo "Setting up Podman socket..."

      # Create podman directory in user runtime directory
      $DRY_RUN_CMD mkdir -p /run/user/1000/podman

      # Reload systemd daemon to pick up new services
      $DRY_RUN_CMD ${pkgs.systemd}/bin/systemctl --user daemon-reload

      # Enable and start the podman socket service
      $DRY_RUN_CMD ${pkgs.systemd}/bin/systemctl --user enable podman-socket.service
      $DRY_RUN_CMD ${pkgs.systemd}/bin/systemctl --user start podman-socket.service

      # Check if service is active
      if $DRY_RUN_CMD ${pkgs.systemd}/bin/systemctl --user is-active podman-socket.service >/dev/null 2>&1; then
        echo "✅ Podman socket service is active"
        # Wait a moment for socket file to be created
        sleep 2
        if [ -S /run/user/1000/podman/podman.sock ]; then
          echo "✅ Podman socket file created successfully"
        else
          echo "⚠️  Socket file not yet created, will be available for next connection"
        fi
      else
        echo "❌ Failed to start podman socket service"
      fi

      echo "Podman socket setup completed"
    '';

  # Enable systemd user services for Podman
  systemd.user.services.podman-auto-update = {
    Unit = {
      Description = "Podman auto-update service";
      Wants = "network-online.target";
      After = "network-online.target";
    };
    Service = {
      Type = "oneshot";
      ExecStart = "${pkgs.podman}/bin/podman auto-update";
      ExecStartPost = "${pkgs.podman}/bin/podman image prune -f";
    };
    Install = { WantedBy = [ "default.target" ]; };
  };

  systemd.user.timers.podman-auto-update = {
    Unit = {
      Description = "Podman auto-update timer";
      Requires = "podman-auto-update.service";
    };
    Timer = {
      OnCalendar = "weekly";
      Persistent = true;
    };
    Install = { WantedBy = [ "timers.target" ]; };
  };

  # Enable Podman socket for Docker-compatible API
  systemd.user.services.podman-socket = {
    Unit = {
      Description = "Podman API Socket";
      Documentation = [ "man:podman-system-service(1)" ];
      RequiresMountsFor = [ "%t/containers" ];
      After = [ "network-online.target" ];
      Wants = [ "network-online.target" ];
    };
    Service = {
      Type = "exec";
      ExecStart =
        "${pkgs.podman}/bin/podman system service --time=0 unix:///run/user/1000/podman/podman.sock";
      ExecStartPre = "${pkgs.coreutils}/bin/mkdir -p /run/user/1000/podman";
      KillMode = "process";
      Environment = [ "LOGGING=--log-level=info" ];
      Restart = "on-failure";
      RestartSec = "5s";
    };
    Install = { WantedBy = [ "default.target" ]; };
  };
}
