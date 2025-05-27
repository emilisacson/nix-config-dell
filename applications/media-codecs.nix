{ pkgs, ... }:

{
  # Install comprehensive media codec support including H.265/HEVC
  home.packages = with pkgs; [
    # FFmpeg with full codec support
    ffmpeg-full

    # GStreamer plugins for H.265 and other codecs
    gst_all_1.gstreamer
    gst_all_1.gst-plugins-base
    gst_all_1.gst-plugins-good
    gst_all_1.gst-plugins-bad
    gst_all_1.gst-plugins-ugly
    gst_all_1.gst-libav # FFmpeg integration for GStreamer
    gst_all_1.gst-vaapi # Hardware video acceleration

    # x264 and x265 encoders/decoders
    x264
    x265

    # Additional media libraries
    libva # Video Acceleration API
    libva-utils # VA-API utilities for testing
    intel-media-driver # Intel hardware video acceleration
    intel-vaapi-driver # Legacy Intel VA-API driver
    mesa # Mesa drivers for video acceleration

    # Media players with codec support
    vlc # VLC media player with extensive codec support
    # mpv # Lightweight media player

    # NVIDIA-specific packages (if using NVIDIA GPU)
    # Uncomment these if you have NVIDIA graphics
    nvidia-vaapi-driver # NVIDIA VA-API driver
    vdpauinfo # VDPAU info utility
  ];

  # Set environment variables for hardware acceleration
  home.sessionVariables = {
    # Enable NVIDIA hardware video acceleration
    LIBVA_DRIVER_NAME = "nvidia";
    VDPAU_DRIVER = "nvidia";

    # FFmpeg hardware acceleration
    FFMPEG_VAAPI = "1";
    FFMPEG_VDPAU = "1";

    # GStreamer hardware acceleration
    GST_VAAPI_ALL_DRIVERS = "1";

    # Chromium/Brave hardware acceleration flags
    CHROMIUM_FLAGS =
      "--enable-features=VaapiVideoDecoder,VaapiVideoEncoder --use-gl=desktop --enable-gpu-rasterization --enable-zero-copy";
  };

  # Configure GStreamer plugin registry
  home.file.".config/gstreamer-1.0/.gstreamer-1.0" = {
    text = "";
    force = true;
  };

  # XDG MIME associations for video files
  xdg.mimeApps = {
    enable = true;
    defaultApplications = {
      # H.265/HEVC video files
      "video/x-h265" = [ "vlc.desktop" ];
      "video/h265" = [ "vlc.desktop" ];
      "video/hevc" = [ "vlc.desktop" ];

      # Other video formats
      "video/mp4" = [ "vlc.desktop" ];
      "video/x-matroska" = [ "vlc.desktop" ];
      "video/webm" = [ "vlc.desktop" ];
      "video/x-msvideo" = [ "vlc.desktop" ];
      "video/quicktime" = [ "vlc.desktop" ];
    };
  };

  # Chromium/Brave hardware acceleration configuration
  home.file.".config/chromium-flags.conf".text = ''
    # Enable hardware video acceleration for H.265 and other codecs
    --enable-features=VaapiVideoDecoder,VaapiVideoEncoder,VaapiIgnoreDriverChecks
    --use-gl=desktop
    --enable-gpu-rasterization
    --enable-zero-copy
    --disable-software-rasterizer
    --enable-hardware-overlays
    --enable-oop-rasterization

    # NVIDIA-specific flags
    --ignore-gpu-blocklist
    --enable-gpu-sandbox
    --enable-accelerated-video-decode
    --enable-accelerated-video-encode
  '';

  # Brave browser specific configuration
  home.file.".config/brave-flags.conf".text = ''
    # Enable hardware video acceleration for H.265 and other codecs
    --enable-features=VaapiVideoDecoder,VaapiVideoEncoder,VaapiIgnoreDriverChecks
    --use-gl=desktop
    --enable-gpu-rasterization
    --enable-zero-copy
    --disable-software-rasterizer
    --enable-hardware-overlays
    --enable-oop-rasterization

    # NVIDIA-specific flags
    --ignore-gpu-blocklist
    --enable-gpu-sandbox
    --enable-accelerated-video-decode
    --enable-accelerated-video-encode

    # H.265/HEVC support
    --enable-features=PlatformHEVCDecoderSupport
  '';
}
