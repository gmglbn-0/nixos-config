{ config, pkgs, lib, inputs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    inputs.nixos-hardware.nixosModules.lenovo-thinkpad-x13-yoga
    inputs.lanzaboote.nixosModules.lanzaboote
    ../../modules
  ];

  # Secure Boot
  boot.loader.systemd-boot.enable = lib.mkForce false;
  boot.lanzaboote = {
    enable = true;
    pkiBundle = "/var/lib/sbctl";
  };

  # Boot
  boot.loader.efi.canTouchEfiVariables = true;
  boot.kernelPackages = pkgs.linuxPackages_latest;
  boot.initrd.kernelModules = [ "amdgpu" ];
  boot.initrd.systemd.enable = true;

  # Networking
  networking.networkmanager.enable = true;
  networking.firewall.enable = false;

  # ModemManager
  networking.modemmanager.enable = true;
  
  # Quectel modem fix
  services.quectel-modem-fix.enable = true;

  # Time & Locale
  time.timeZone = "Asia/Yerevan";
  i18n.defaultLocale = "en_US.UTF-8";
  i18n.extraLocaleSettings = {
    LC_ADDRESS = "en_US.UTF-8";
    LC_IDENTIFICATION = "en_US.UTF-8";
    LC_MEASUREMENT = "en_US.UTF-8";
    LC_MONETARY = "en_US.UTF-8";
    LC_NAME = "en_US.UTF-8";
    LC_NUMERIC = "en_US.UTF-8";
    LC_PAPER = "en_US.UTF-8";
    LC_TELEPHONE = "en_US.UTF-8";
    LC_TIME = "en_US.UTF-8";
  };

  # Graphics
  services.xserver.enable = true;
  services.displayManager.gdm.enable = true;
  services.desktopManager.gnome.enable = true;
  services.xserver.xkb = {
    layout = "us";
    variant = "";
  };
  services.xserver.videoDrivers = [ "amdgpu" ];

  # Hardware acceleration
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };
  hardware.amdgpu.opencl.enable = true;

  # Audio
  services.printing.enable = true;
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    # AirPlay support for music streaming
    extraConfig.pipewire."99-airplay" = {
      "context.modules" = [
        {
          name = "libpipewire-module-raop-discover";
          args = { };
        }
      ];
    };
  };

  # Avahi
  services.avahi = {
    enable = true;
    nssmdns4 = true;
    openFirewall = true;
  };

  # Thunderbolt
  services.hardware.bolt.enable = true;

  # Fingerprint
  services.fprintd.enable = true;
  security.pam.services.login.fprintAuth = lib.mkForce true;
  security.pam.services.gdm-fingerprint.fprintAuth = true;

  # TPM 2.0
  security.tpm2 = {
    enable = true;
    pkcs11.enable = true;
    tctiEnvironment.enable = true;
  };

  # Virtualization
  virtualisation.libvirtd.enable = true;
  virtualisation.spiceUSBRedirection.enable = true;

  # iOS
  services.usbmuxd.enable = true;

  # Tailscale
  services.tailscale.enable = true;

  # Programs
  programs.steam.enable = true;
  programs._1password.enable = true;
  programs._1password-gui = {
    enable = true;
    polkitPolicyOwners = [ "gmglbn_0" ];
  };
  programs.firefox.enable = true;
  programs.zsh.enable = true;
  programs.zsh.ohMyZsh = {
    enable = true;
    plugins = [ "git" "sudo" "docker" "kubectl" ];
  };
  users.defaultUserShell = pkgs.zsh;

  # nix-ld
  programs.nix-ld.enable = true;
  programs.nix-ld.libraries = with pkgs; [
    stdenv.cc.cc.lib
    zlib
    openssl
  ];

  # Unfree and insecure
  nixpkgs.config.permittedInsecurePackages = [ "olm-3.2.16" ];

  # User
  users.users.gmglbn_0 = {
    isNormalUser = true;
    description = "Kita Lembrik";
    extraGroups = [ "networkmanager" "wheel" "libvirtd" "kvm" ];
    packages = with pkgs; [
      thunderbird
      qbittorrent-enhanced
      krita
      chromium
      ayugram-desktop
      zed-editor
      wakatime-cli
      libimobiledevice
      ifuse
      parsec-bin
      gnomeExtensions.appindicator
      obs-studio
      ptyxis
      twinkle
      gnome-boxes
      dnsmasq
      phodav
      libmbim
      libqmi
      pciutils
      usbutils
      modem-manager-gui
      chatty
      rustc
      cargo
      rustfmt
      clippy
      rust-analyzer
      pkg-config
      lact
      gcc
      freetype
      fontconfig
      antigravity
      nheko
      deltachat-desktop
      howdy
    ];
  };

  # Additional system packages
  environment.systemPackages = with pkgs; [
    sbctl
    fastfetch
    hyfetch
    modemmanager
  ];

  # State version
  system.stateVersion = "25.11";
}
