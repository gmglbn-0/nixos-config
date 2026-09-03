{ config, pkgs, lib, inputs, ... }:

{
  imports = [
    ./hardware-configuration.nix
  ];

  # ── Bootloader ───────────────────────────────────────────────────────────
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # ── Networking & Hostname ────────────────────────────────────────────────
  networking.networkmanager.enable = true;
  networking.firewall.enable = true;

  # ── Time & Locale ────────────────────────────────────────────────────────
  time.timeZone = "Asia/Yerevan";
  i18n.defaultLocale = "en_US.UTF-8";

  # ── User Account for TV Auto-login ───────────────────────────────────────
  users.users.tv = {
    isNormalUser = true;
    description = "Living Room TV User";
    extraGroups = [ "wheel" "video" "audio" "networkmanager" "input" ];
  };

  # ── Desktop Environment (KDE Plasma 6 + Bigscreen TV Layout) ─────────────
  services.xserver.enable = true;
  services.desktopManager.plasma6.enable = true;

  services.displayManager = {
    sddm = {
      enable = true;
      wayland.enable = true;
    };
    autoLogin = {
      enable = true;
      user = "tv";
    };
  };

  # ── Graphics & Hardware Acceleration (Intel N100 Alder Lake-N) ───────────
  hardware.graphics = {
    enable = true;
    extraPackages = with pkgs; [
      intel-media-driver  # VA-API QuickSync driver for AV1, HEVC 10-bit, VP9, H.264
      intel-vaapi-driver  # Legacy i965 fallback
      libvdpau-va-gl
    ];
  };

  # ── Audio & Passthrough (PipeWire) ───────────────────────────────────────
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  # ── Bluetooth (Android TV Remote & Gamepads) ─────────────────────────────
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
  };

  # ── System Packages & HTPC Software ──────────────────────────────────────
  environment.systemPackages = with pkgs; [
    # TV UI & Media Players
    kdePackages.plasma-bigscreen
    kodi-wayland
    jellyfin-media-player
    mpv

    # HDMI-CEC Utilities (Pulse-Eight USB-CEC Adapter support)
    libcec
    cec-utils

    # System & Diagnostics
    intel-gpu-tools
    libva-utils
    git
    htop
    curl
  ];

  # ── Power & Display Rules ────────────────────────────────────────────────
  # Prevent screen dimming / sleep during media playback
  powerManagement.enable = true;

  system.stateVersion = "24.11";
}
