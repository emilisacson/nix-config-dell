{ config, pkgs, lib, ... }:

let
  # System-specific VM configurations
  systemSpecs = config.systemSpecs;
  systemId = systemSpecs.system_id or "unknown";

  # System-specific VM settings based on available resources
  vmConfig = {
    "laptop-20Y30016MX-hybrid" = {
      memory = "8192"; # 8GB RAM for VM
      cores = "4"; # 4 CPU cores
      disk_size = "60G"; # 60GB disk
    };
    "laptop-Latitude_7410-intel" = {
      memory = "6144"; # 6GB RAM for VM
      cores = "2"; # 2 CPU cores
      disk_size = "60G"; # 60GB disk
    };
    # Default fallback configuration
    "unknown" = {
      memory = "4096"; # 4GB RAM
      cores = "2"; # 2 CPU cores
      disk_size = "40G"; # 40GB disk
    };
  };

  currentVmConfig = vmConfig.${systemId} or vmConfig."unknown";

  # Pure QEMU approach (more Nix-native than libvirt)
  createWindowsVm = pkgs.writeShellScriptBin "create-windows-vm" ''
    set -e

    VM_DIR="$HOME/.local/share/qemu-vms"
    VM_NAME="windows-vm"
    ISO_DIR="$HOME/.local/share/qemu-vms/isos"

    echo "🖥️  Setting up Windows VM (Pure QEMU + Nix)..."
    echo "💡 This approach is more Nix-native and doesn't require libvirt services"
    echo ""

    # Create directories
    mkdir -p "$VM_DIR" "$ISO_DIR"

    echo "📁 VM Directory: $VM_DIR"
    echo "💿 ISO Directory: $ISO_DIR"
    echo ""
    echo "⚙️  VM Configuration:"
    echo "   Memory: ${currentVmConfig.memory}MB"
    echo "   CPU Cores: ${currentVmConfig.cores}"
    echo "   Disk Size: ${currentVmConfig.disk_size}"
    echo ""

    # Check if Windows ISO exists
    ISO_FILE="Win11_24H2_EnglishInternational_x64.iso"
    if [ ! -f "$ISO_DIR/$ISO_FILE" ]; then
      echo "❌ Windows ISO not found at $ISO_DIR/$ISO_FILE"
      echo ""
      echo "📥 Please download a Windows ISO and place it at:"
      echo "   $ISO_DIR/$ISO_FILE"
      echo ""
      echo "💡 You can download Windows 11 from:"
      echo "   https://www.microsoft.com/software-download/windows11"
      echo ""
      echo "🚀 Quick setup commands:"
      echo "   mkdir -p $ISO_DIR"
      echo "   # Then download your Windows ISO"
      exit 1
    fi

    # Create VM disk if it doesn't exist
    if [ ! -f "$VM_DIR/$VM_NAME.qcow2" ]; then
      echo "💾 Creating VM disk..."
      ${pkgs.qemu_kvm}/bin/qemu-img create -f qcow2 "$VM_DIR/$VM_NAME.qcow2" ${currentVmConfig.disk_size}
      echo "✅ Created $VM_DIR/$VM_NAME.qcow2 (${currentVmConfig.disk_size})"
    else
      echo "ℹ️  VM disk already exists: $VM_DIR/$VM_NAME.qcow2"
    fi

    # Create OVMF vars file if it doesn't exist (for UEFI)
    if [ ! -f "$VM_DIR/OVMF_VARS.fd" ]; then
      echo "🔧 Setting up UEFI firmware..."
      cp ${pkgs.OVMF.fd}/FV/OVMF_VARS.fd "$VM_DIR/"
      chmod +w "$VM_DIR/OVMF_VARS.fd"
      echo "✅ UEFI firmware ready"
    else
      echo "ℹ️  UEFI firmware already configured"
    fi

    echo ""
    echo "✅ Windows VM environment ready!"
    echo ""
    echo "🚀 To start the VM (first time will boot from ISO):"
    echo "   start-windows-vm"
    echo ""
    echo "📋 For clipboard sharing, download SPICE guest tools:"
    echo "   download-spice-tools"
    echo "   Then install them inside Windows after first boot"
    echo ""
    echo "🛠️  VM files are located at: $VM_DIR"
  '';

  # Download SPICE guest tools helper script
  downloadSpiceTools = pkgs.writeShellScriptBin "download-spice-tools" ''
    set -e

    ISO_DIR="$HOME/.local/share/qemu-vms/isos"
    SPICE_TOOLS_URL="https://www.spice-space.org/download/windows/spice-guest-tools/spice-guest-tools-latest.exe"

    echo "📋 Downloading SPICE Guest Tools for clipboard sharing..."
    echo ""

    mkdir -p "$ISO_DIR"

    # Download SPICE guest tools
    echo "🌐 Downloading from: $SPICE_TOOLS_URL"
    if command -v wget >/dev/null 2>&1; then
      ${pkgs.wget}/bin/wget -O "$ISO_DIR/spice-guest-tools-latest.exe" "$SPICE_TOOLS_URL"
    elif command -v curl >/dev/null 2>&1; then
      ${pkgs.curl}/bin/curl -L -o "$ISO_DIR/spice-guest-tools-latest.exe" "$SPICE_TOOLS_URL"
    else
      echo "❌ Neither wget nor curl found!"
      echo "💡 Please manually download:"
      echo "   $SPICE_TOOLS_URL"
      echo "   Save as: $ISO_DIR/spice-guest-tools-latest.exe"
      exit 1
    fi

    echo ""
    echo "✅ SPICE Guest Tools downloaded to:"
    echo "   $ISO_DIR/spice-guest-tools-latest.exe"
    echo ""
    echo "📋 To install (inside Windows VM):"
    echo "   1. Start your Windows VM: start-windows-vm"
    echo "   2. In Windows, download and run the installer from a web browser"
    echo "   3. Or access the downloaded file via shared folder"
    echo "   4. Run as Administrator in Windows"
    echo "   5. Reboot Windows after installation"
    echo "   6. Clipboard sharing will work after reboot!"
    echo ""
    echo "💡 Alternative: Install from VirtIO ISO (already mounted in VM):"
    echo "   - In Windows File Explorer, go to VirtIO CD drive"
    echo "   - Navigate to guest-agent/ folder"
    echo "   - Install qemu-ga-x86_64.msi"
    echo "   - Then go to spice-guest-tools/ and install the exe"
  '';

  # Windows VM start script (Pure QEMU - no libvirt needed)
  startWindowsVm = pkgs.writeShellScriptBin "start-windows-vm" ''
        VM_DIR="$HOME/.local/share/qemu-vms"
        VM_NAME="windows-vm"
        ISO_DIR="$HOME/.local/share/qemu-vms/isos"

        # Detect already running instance unless forced new
        if [ "''${WIN_FORCE_NEW:-0}" != "1" ]; then
          EXISTING_PID=$(pgrep -f "qemu-system-x86_64.*$VM_NAME" | head -n1 || true)
          if [ -n "''${EXISTING_PID}" ]; then
            echo "ℹ️  Windows VM already running (PID: ''${EXISTING_PID})."
            # Try to extract SPICE port from cmdline
            CMDLINE=$(tr '\0' ' ' < /proc/"''${EXISTING_PID}"/cmdline 2>/dev/null || echo "")
            SPICE_PORT_DETECTED=$(echo "''${CMDLINE}" | sed -n 's/.*-spice[[:space:]]\+port=\([0-9]\{4,5\}\).*/\1/p' | sed -n '1p')
            if [ -z "''${SPICE_PORT_DETECTED}" ]; then
              # Fallback: handle pattern with no whitespace between -spice and port definition
              SPICE_PORT_DETECTED=$(echo "''${CMDLINE}" | sed -n 's/.*-spice[[:space:]]\+port=\([0-9]\{4,5\}\)[, ].*/\1/p' | sed -n '1p')
            fi
            if [ -z "''${SPICE_PORT_DETECTED}" ]; then
              # Second fallback: generic port= capture
              SPICE_PORT_DETECTED=$(echo "''${CMDLINE}" | sed -n 's/.*port=\([0-9]\{4,5\}\)[, ].*/\1/p' | head -n1)
            fi
            if [ -n "''${SPICE_PORT_DETECTED}" ]; then
              echo "🔍 Detected SPICE port: ''${SPICE_PORT_DETECTED}"
              if ss -ltn 2>/dev/null | grep -q ":''${SPICE_PORT_DETECTED} "; then
                if [ "''${WIN_NO_VIEWER:-0}" = "1" ]; then
                  echo "🖥️  WIN_NO_VIEWER=1 set; not launching viewer. Connect manually: spice://localhost:''${SPICE_PORT_DETECTED}"
                else
                  if command -v ${pkgs.virt-viewer}/bin/remote-viewer >/dev/null 2>&1; then
                    echo "🖥️  Attaching SPICE viewer to existing VM (port ''${SPICE_PORT_DETECTED})..."
                    ${pkgs.virt-viewer}/bin/remote-viewer spice://localhost:''${SPICE_PORT_DETECTED} &
                  else
                    echo "💡 Install virt-viewer to auto-open. Manual: ${pkgs.virt-viewer}/bin/remote-viewer spice://localhost:''${SPICE_PORT_DETECTED}"
                  fi
                fi
              else
                echo "⚠️  SPICE port ''${SPICE_PORT_DETECTED} not (yet) listening. VM may still be initializing."
              fi
            else
              echo "⚠️  Could not parse SPICE port from existing QEMU command line."
            fi
            echo "➡️  Use WIN_FORCE_NEW=1 start-windows-vm to ignore existing instance and launch another (not recommended)."
            exit 0
          fi
        else
          echo "🚩 WIN_FORCE_NEW=1 set; ignoring any existing instance."
        fi

        # Dynamic SPICE port selection & configuration
        SPICE_PORT="''${WIN_SPICE_PORT:-5900}"
        if ss -ltn 2>/dev/null | grep -q ":$SPICE_PORT "; then
          if [ "''${WIN_SPICE_PORT_FORCE:-0}" = "1" ]; then
            echo "❌ Requested SPICE port $SPICE_PORT already in use (WIN_SPICE_PORT_FORCE=1)."
            exit 1
          fi
          BASE=$SPICE_PORT
          for inc in $(seq 1 20); do
            CAND=$((BASE+inc))
            if ! ss -ltn 2>/dev/null | grep -q ":$CAND "; then
              echo "ℹ️  SPICE port $SPICE_PORT busy; using $CAND instead. (Override with WIN_SPICE_PORT_FORCE=1 to forbid change)"
              SPICE_PORT=$CAND
              break
            fi
          done
        fi

        echo "🚀 Starting Windows VM (Pure QEMU)..."

        if [ ! -f "$VM_DIR/$VM_NAME.qcow2" ]; then
          echo "❌ VM disk not found!"
          echo "💡 Create it first with: create-windows-vm"
          exit 1
        fi

        # Start TPM emulator (required for Windows 11)
        echo "🔐 Starting TPM 2.0 emulator..."
        pkill -f "swtpm socket" 2>/dev/null || true
        ${pkgs.swtpm}/bin/swtpm socket --tpmstate dir=$VM_DIR --ctrl type=unixio,path=$VM_DIR/swtpm-sock --log level=20 --tpm2 --daemon

        # Check if this is likely the first boot (empty disk)
        DISK_USAGE=$(${pkgs.qemu_kvm}/bin/qemu-img info "$VM_DIR/$VM_NAME.qcow2" | grep "disk size" | awk '{print $3}')

        # Decide networking & optional RDP host forwarding BEFORE building QEMU_ARGS
        RDP_PORT="''${WIN_RDP_PORT:-33890}"
        NETDEV_SPEC="user,id=net0"
        if { [ "''${WIN_RDP_DISABLE:-0}" != "1" ] || [ "''${WIN_RDP_ENABLE:-0}" = "1" ]; }; then
          if ss -ltn 2>/dev/null | grep -q ":$RDP_PORT "; then
            if [ "''${WIN_RDP_FORCE:-0}" = "1" ]; then
              echo "⚠️  Host port ''${RDP_PORT} busy but WIN_RDP_FORCE=1 set; attempting anyway (forward may fail)."
              NETDEV_SPEC="user,id=net0,hostfwd=tcp::''${RDP_PORT}-:3389"
            else
              for inc in $(seq 1 50); do
                CAND=$((RDP_PORT+inc))
                if ! ss -ltn 2>/dev/null | grep -q ":$CAND "; then
                  echo "ℹ️  RDP port ''${RDP_PORT} busy; using $CAND instead. Override with WIN_RDP_FORCE=1 to insist."
                  RDP_PORT=$CAND
                  NETDEV_SPEC="user,id=net0,hostfwd=tcp::''${RDP_PORT}-:3389"
                  break
                fi
              done
            fi
          else
            NETDEV_SPEC="user,id=net0,hostfwd=tcp::''${RDP_PORT}-:3389"
          fi
        fi

        # Build base QEMU command
        QEMU_ARGS=(
          "-enable-kvm"
          "-machine" "q35,smm=on"
          "-cpu" "host,+kvm_pv_unhalt,+kvm_pv_eoi,hv_vendor_id=null,hv_spinlocks=0x1fff,hv_vapic,hv_time,hv_relaxed"
          "-smp" "${currentVmConfig.cores}"
          "-m" "${currentVmConfig.memory}"
          "-drive" "if=pflash,format=raw,readonly=on,file=${pkgs.OVMF.fd}/FV/OVMF_CODE.fd"
          "-drive" "if=pflash,format=raw,file=$VM_DIR/OVMF_VARS.fd"
          "-drive" "file=$VM_DIR/$VM_NAME.qcow2,format=qcow2,if=virtio,id=hd0"
    "-netdev" "$NETDEV_SPEC"
          "-device" "virtio-net,netdev=net0"
          "-vga" "qxl"
      "-spice" "port=$SPICE_PORT,addr=127.0.0.1,disable-ticketing=on,streaming-video=all"
          "-device" "virtio-serial-pci"
          "-device" "virtserialport,chardev=spicechannel0,name=com.redhat.spice.0"
          "-chardev" "spicevmc,id=spicechannel0,name=vdagent"
          "-audiodev" "spice,id=spice"
          "-device" "ich9-intel-hda"
          "-device" "hda-duplex,audiodev=spice"
          "-usb"
          "-device" "usb-tablet"
          "-rtc" "base=localtime,clock=host"
          "-device" "qemu-xhci,id=xhci"
          "-chardev" "socket,id=chrtpm,path=$VM_DIR/swtpm-sock"
          "-tpmdev" "emulator,id=tpm0,chardev=chrtpm"
          "-device" "tpm-tis,tpmdev=tpm0"
          "-global" "kvm-pit.lost_tick_policy=delay"
          "-global" "ICH9-LPC.disable_s3=1"
          "-global" "ICH9-LPC.disable_s4=1"
      )    # Base QEMU args complete
        ########################################################################
        # Shared folder support (host directory exposed as a FAT-like disk)    #
        # Implementation: QEMU vvfat backend presented via usb-storage device.  #
        # Pros: No guest additions required. Appears as a removable disk.       #
        # Cons: Filename length / symlink limitations (FAT semantics).         #
        #                                                                         
        # Environment variables:                                                
        #   WIN_SHARE_DIR=/path/to/share  (override default)                     
        #   WIN_SHARE_DISABLE=1            (turn off sharing)                     
        #   WIN_SHARE_RO=1                 (export read-only)                     
        # Default path: $HOME/WindowsShare                                      
        ########################################################################
        if [ "''${WIN_SHARE_DISABLE:-0}" != "1" ]; then
          SHARE_DIR="''${WIN_SHARE_DIR:-$HOME/WindowsShare}"
          mkdir -p "$SHARE_DIR" 2>/dev/null || true
          if [ ! -d "$SHARE_DIR" ]; then
            echo "⚠️  Shared folder path '$SHARE_DIR' is not a directory; skipping share."
          else
            SHARE_MODE="rw"
            [ "''${WIN_SHARE_RO:-0}" = "1" ] && SHARE_MODE="ro"
            # Use an index to avoid collision with existing devices
            echo "📂 Exporting host directory '$SHARE_DIR' to guest (mode=$SHARE_MODE)"
            # Provide a deterministic id for later extension if multiple shares are desired
            if [ "$SHARE_MODE" = "ro" ]; then
              VFAT_SPEC="fat:ro:$SHARE_DIR"
            else
              VFAT_SPEC="fat:rw:$SHARE_DIR"
            fi
            QEMU_ARGS+=("-drive" "if=none,id=sharedvfat,file=$VFAT_SPEC,format=raw")
            QEMU_ARGS+=("-device" "usb-storage,drive=sharedvfat")
          fi
        else
          echo "📂 Shared folder disabled (WIN_SHARE_DISABLE=1)"
        fi

        # Continue with ISO / media configuration
        # ---------------------------------------
        ISO_FILE="Win11_24H2_EnglishInternational_x64.iso"
        VIRTIO_ISO="virtio-win-0.1.271.iso"
        SPICE_TOOLS_ISO="spice-guest-tools-latest.iso"

        # Decide whether to mount install ISOs ---------------------------------
      OS_MARKER="$VM_DIR/.os-installed"
      FORCE_INSTALL="''${FORCE_WIN_INSTALL:-0}"
      SKIP_ISO="''${SKIP_WIN_ISO:-0}"          # Set to 1 to skip Windows ISO even if marker missing
      CREATE_MARKER="''${CREATE_OS_MARKER:-0}"  # Set to 1 to force-create marker (post-install convenience)

        # Heuristic: if qcow2 has > minimal size and marker absent, infer install done
        if [ ! -f "$OS_MARKER" ]; then
          USED_BYTES=$(stat -c '%s' "$VM_DIR/$VM_NAME.qcow2" 2>/dev/null || echo 0)
          if [ "$USED_BYTES" -gt 3000000000 ]; then
            echo "ℹ️  Disk usage suggests OS already installed (used >3G). Creating marker file."
            touch "$OS_MARKER"
          fi
        fi

      if [ "''${CREATE_MARKER}" = "1" ] && [ ! -f "$OS_MARKER" ]; then
          echo "📝 CREATE_OS_MARKER=1 -> creating install marker file."; touch "$OS_MARKER"
        fi

      echo "🧪 ISO decision vars: FORCE_INSTALL=$FORCE_INSTALL SKIP_ISO=$SKIP_ISO MARKER=$([ -f "$OS_MARKER" ] && echo 1 || echo 0)"

      if [ "''${FORCE_INSTALL}" = "1" ]; then
          echo "🚩 FORCE_WIN_INSTALL=1 -> forcing mount of Windows ISO for (re)installation."
        fi

      if { [ -f "$OS_MARKER" ] && [ "''${FORCE_INSTALL}" != "1" ]; } || { [ "$SKIP_ISO" = "1" ] && [ "''${FORCE_INSTALL}" != "1" ]; }; then
          # Either we know OS installed, or user explicitly skips ISO
      if [ -f "$OS_MARKER" ]; then
            echo "💿 OS marker present; not mounting Windows ISO (boot from disk)."
      elif [ "$SKIP_ISO" = "1" ]; then
            echo "💿 SKIP_WIN_ISO=1 -> not mounting Windows ISO (even without marker)."
          fi
          QEMU_ARGS+=("-boot" "order=c")
        else
          # Proceed to mount installation media
          if [ -f "$ISO_DIR/$ISO_FILE" ]; then
            echo "💿 Mounting Windows ISO for installation/boot"
            QEMU_ARGS+=("-drive" "file=$ISO_DIR/$ISO_FILE,format=raw,if=none,media=cdrom,id=cd0,readonly=on")
            QEMU_ARGS+=("-device" "ide-cd,drive=cd0,bootindex=1")
            QEMU_ARGS+=("-boot" "order=dc")
            # VirtIO drivers
            if [ -f "$ISO_DIR/$VIRTIO_ISO" ]; then
              echo "🔧 Mounting VirtIO drivers ISO"
              QEMU_ARGS+=("-drive" "file=$ISO_DIR/$VIRTIO_ISO,format=raw,if=none,media=cdrom,id=cd1,readonly=on")
              QEMU_ARGS+=("-device" "ahci,id=ahci")
              QEMU_ARGS+=("-device" "ide-cd,drive=cd1,bus=ahci.0")
            else
              echo "⚠️  VirtIO drivers ISO not found at $ISO_DIR/$VIRTIO_ISO"
            fi
            # SPICE tools
            if [ -f "$ISO_DIR/$SPICE_TOOLS_ISO" ]; then
              echo "📋 Mounting SPICE guest tools ISO"
              QEMU_ARGS+=("-drive" "file=$ISO_DIR/$SPICE_TOOLS_ISO,format=raw,if=none,media=cdrom,id=cd2,readonly=on")
              QEMU_ARGS+=("-device" "ide-cd,drive=cd2,bus=ahci.1")
            fi
          else
            echo "⚠️  No ISO found. VM will boot from disk only."
            QEMU_ARGS+=("-boot" "order=c")
          fi
        fi

      echo "✅ Starting VM with SPICE display on localhost:$SPICE_PORT"
      echo "🔍 You can connect with any SPICE client to: spice://localhost:$SPICE_PORT"
        echo ""

        # Start VM in background
        ${pkgs.qemu_kvm}/bin/qemu-system-x86_64 "''${QEMU_ARGS[@]}" &
        QEMU_PID=$!

        # Wait for SPICE port to listen (up to 15s)
        for i in $(seq 1 30); do
          if ss -ltn 2>/dev/null | grep -q ":$SPICE_PORT "; then
            READY=1
            break
          fi
          sleep 0.5
        done
        if [ "${"READY:-0"}" != "1" ]; then
          echo "⚠️  SPICE port $SPICE_PORT not detected listening after timeout. Viewer not auto-started."
          echo "   Use: ${pkgs.virt-viewer}/bin/remote-viewer spice://localhost:$SPICE_PORT once ready."
        else
          if [ "''${WIN_NO_VIEWER:-0}" = "1" ]; then
            echo "🖥️  WIN_NO_VIEWER=1 set; not auto-launching viewer. Connect manually: spice://localhost:$SPICE_PORT"
          else
            if command -v ${pkgs.virt-viewer}/bin/remote-viewer >/dev/null 2>&1; then
              echo "🖥️  Opening SPICE viewer (port $SPICE_PORT)..."
              ${pkgs.virt-viewer}/bin/remote-viewer spice://localhost:$SPICE_PORT &
            else
              echo "💡 Install virt-viewer to auto-open. Manual: ${pkgs.virt-viewer}/bin/remote-viewer spice://localhost:$SPICE_PORT"
            fi
          fi
        fi

        echo "🖥️  VM running (PID: $QEMU_PID)"
        echo "⏹️  Stop with: stop-windows-vm"
        echo ""
        echo "📋 CLIPBOARD SHARING SETUP:"
        echo "   After Windows installation, install SPICE guest tools:"
        echo "   1. In Windows, go to VirtIO CD drive → guest-agent/ → install qemu-ga-x86_64.msi"
        echo "   2. Then go to spice-guest-tools/ → install the .exe file"
        echo "   3. Reboot Windows"
        echo "   4. Clipboard will work between Linux host and Windows VM!"
        echo ""
      echo "📂 SHARED FOLDER (vvfat usb-storage):"
      echo "   Host path (override with WIN_SHARE_DIR): $HOME/WindowsShare (mode: $([ "''${SHARE_MODE:-rw}" = "ro" ] && echo read-only || echo read-write))"
      echo "   Disable: WIN_SHARE_DISABLE=1 start-windows-vm"
      echo "   Read-only: WIN_SHARE_RO=1 start-windows-vm"
      echo "   In Windows it appears as a Removable Drive (check File Explorer)."
      echo "   Limitations: FAT semantics (no symlinks, filename length limits)."
      echo ""
        echo "📝 Or use Ctrl+Alt+2 in QEMU monitor, then type 'quit'"
  '';

  # Windows VM stop script
  stopWindowsVm = pkgs.writeShellScriptBin "stop-windows-vm" ''
      echo "⏹️  Stopping Windows VM..."

      # Find QEMU process for our VM
      QEMU_PID=$(pgrep -f "qemu-system-x86_64.*windows-vm" || echo "")

      if [ -n "$QEMU_PID" ]; then
        echo "🔄 Sending graceful shutdown signal to VM..."
        kill -TERM "$QEMU_PID"
        
        # Wait up to 30 seconds for graceful shutdown
        for i in {1..30}; do
          if ! kill -0 "$QEMU_PID" 2>/dev/null; then
            echo "✅ VM shutdown gracefully"
            break
          fi
          sleep 1
          echo -n "."
        done
        
        # Force kill if still running
        if kill -0 "$QEMU_PID" 2>/dev/null; then
          echo ""
          echo "💥 Force stopping VM..."
          kill -KILL "$QEMU_PID"
          echo "✅ VM force stopped"
        fi
      else
        echo "ℹ️  Windows VM is not running"
      fi

      # Also clean up any remote-viewer instances
    # Attempt to clean up any remote-viewer attached to localhost SPICE sessions (common ports 5900-5920)
    pkill -f "remote-viewer.*spice://localhost:" 2>/dev/null || true
      echo "🧹 Cleaned up SPICE viewer connections"
  '';

  # VM status script
  statusWindowsVm = pkgs.writeShellScriptBin "status-windows-vm" ''
    VM_DIR="$HOME/.local/share/qemu-vms"
    VM_NAME="windows-vm"

    echo "📊 Windows VM Status"
    echo "===================="

    # Check if VM files exist
    if [ -f "$VM_DIR/$VM_NAME.qcow2" ]; then
      echo "💾 VM Disk: ✅ Found"
      
      # Get disk info
      DISK_INFO=$(${pkgs.qemu_kvm}/bin/qemu-img info "$VM_DIR/$VM_NAME.qcow2")
      VIRTUAL_SIZE=$(echo "$DISK_INFO" | grep "virtual size" | awk '{print $3 " " $4}')
      DISK_SIZE=$(echo "$DISK_INFO" | grep "disk size" | awk '{print $3}')
      
      echo "   Virtual Size: $VIRTUAL_SIZE"
      echo "   Used Space: $DISK_SIZE"
    else
      echo "💾 VM Disk: ❌ Not found"
      echo "   Run: create-windows-vm"
    fi

    # Check if VM is running
    QEMU_PID=$(pgrep -f "qemu-system-x86_64.*windows-vm" || echo "")
    if [ -n "$QEMU_PID" ]; then
      echo "🔄 VM Status: ✅ Running (PID: $QEMU_PID)"
      CMDLINE=$(tr '\0' ' ' < /proc/$QEMU_PID/cmdline 2>/dev/null || echo "")
      DETECTED_PORT=$(echo "$CMDLINE" | sed -n 's/.*-spice[^ ]*port=\([0-9]\{4,5\}\).*/\1/p' | head -n1)
      if [ -n "$DETECTED_PORT" ]; then
        echo "   SPICE: spice://localhost:$DETECTED_PORT"
      else
        echo "   SPICE: (port not detected)"
      fi
    else
      echo "🔄 VM Status: ⏹️ Stopped"
    fi

    echo ""
    echo "🎮 Available Commands:"
    echo "   create-windows-vm     - Set up VM environment"
    echo "   start-windows-vm      - Start the VM"
    echo "   stop-windows-vm       - Stop the VM"
    echo "   status-windows-vm     - Show this status"
    echo "   download-spice-tools  - Download clipboard sharing tools"
  '';

in {
  # Install virtualization packages (pure QEMU approach)
  home.packages = with pkgs; [
    # Core virtualization (no libvirt needed!)
    qemu_kvm

    # Libvirt GUI manager (Path A official workflow)
    virt-manager

    # SPICE viewer for remote display
    virt-viewer
    spice-gtk

    # UEFI firmware
    OVMF

    # TPM emulator for Windows 11
    swtpm

    # Download tools
    wget
    curl

    # Our custom VM scripts
    createWindowsVm
    startWindowsVm
    stopWindowsVm
    statusWindowsVm
    downloadSpiceTools
  ];

  # Create desktop entries for easy access
  xdg.desktopEntries = {
    windows-vm = {
      name = "Windows VM";
      comment = "Start Windows Virtual Machine (Pure QEMU)";
      exec = "start-windows-vm";
      icon = "computer";
      categories = [ "System" "Emulator" ];
      terminal = true;
    };

    windows-vm-status = {
      name = "Windows VM Status";
      comment = "Check Windows VM status";
      exec = "status-windows-vm";
      icon = "computer";
      categories = [ "System" "Emulator" ];
      terminal = true;
    };
  };
}
