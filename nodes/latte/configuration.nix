{ config, lib, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
  ];

  # Boot
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.kernelPackages = pkgs.linuxPackages_latest;

  # Kernel patches for Mi Pad 2 - REQUIRED for boot and audio
  boot.kernelPatches = [
    {
      name = "i915-fix";
      patch = pkgs.fetchurl {
        url = "https://gitlab.postmarketos.org/postmarketOS/pmaports/-/raw/master/device/testing/linux-xiaomi-latte/latte-i915-fix.patch";
        sha256 = "168r3jpvg3dld683ydvpwrp1mbfclaq52idp4jv04xlj0lbjm3xb";
      };
    }
    {
      name = "audio-fix";
      patch = pkgs.fetchurl {
        url = "https://gitlab.postmarketos.org/postmarketOS/pmaports/-/raw/master/device/testing/linux-xiaomi-latte/latte-audio-fix.patch";
        sha256 = "011i83vh06d7j7finmdv3m208hgyzl86a057aq10cn2qfxb2hmdc";
      };
    }
  ];

  # Networking
  networking.networkmanager.enable = true;
  networking.firewall.enable = false;

  # Time & Locale
  time.timeZone = "Asia/Yerevan";
  i18n.defaultLocale = "en_US.UTF-8";

  # Phosh
  services.xserver = {
    enable = true;
    desktopManager.phosh = {
      enable = true;
      group = "users";
      user = "gmglbn_0";
    };
  };
  
  # Touchscreen
  services.libinput.enable = true;

  # Audio
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  # Tailscale
  services.tailscale.enable = true;

  # Programs
  programs.firefox.enable = true;
  programs.zsh.enable = true;
  users.defaultUserShell = pkgs.zsh;

  # User
  users.users.gmglbn_0 = {
    isNormalUser = true;
    description = "Kita Lembrik";
    extraGroups = [ "networkmanager" "wheel" "video" "audio" ];
  };

  # System packages
  environment.systemPackages = with pkgs; [
    lshw
  ];

  # S   tate version
  system.stateVersion = "24.11";
}
