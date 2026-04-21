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
  boot.kernelPackages = pkgs.cachyosKernels.linuxPackages-cachyos-latest;
  boot.initrd.kernelModules = [ "amdgpu" "i915" ];
  boot.initrd.systemd.enable = true;
  boot.kernelParams = [ "modprobe.blacklist=spi-nor" "modprobe.blacklist=kvm_amd" "i2c-i801.disable_features=0x10" ];

  # Networking
  networking.networkmanager.enable = true;
  networking.firewall.enable = false;

  # ModemManager
  networking.modemmanager.enable = true;

  # Quectel modem fix
  services.quectel-modem-fix.enable = true;

  # Time & Locale
  time.timeZone = "Asia/Tbilisi";
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
    extraPackages = with pkgs; [
      libva
      libva-utils
      mesa
      libva-vdpau-driver
      libvdpau-va-gl
      intel-media-driver
      intel-vaapi-driver
      intel-compute-runtime
    ];
  };

  # Power and Thermal Management
  services.thermald.enable = true;
  services.power-profiles-daemon.enable = true;
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
  services.fprintd = {
    enable = true;
    tod = {
      enable = true;
      driver = pkgs.libfprint-2-tod1-goodix;
    };
  };
  security.pam.services = let
    lidCheckScript = pkgs.writeShellScript "is-lid-open" ''
      set -eoui pipefail
      lidstate="$(${pkgs.systemd}/bin/busctl get-property org.freedesktop.login1 /org/freedesktop/login1 org.freedesktop.login1.Manager LidClosed 2>/dev/null || echo 'b false')"
      if [ "''${lidstate}" = "b false" ]; then
        exit 0
      fi
      exit 1
    '';
    lidCheckRule = {
      enable = true;
      control = "[success=ok default=1]";
      modulePath = "${pkgs.pam}/lib/security/pam_exec.so";
      args = [ "quiet" "quiet_log" "${lidCheckScript}" ];
    };
  in {
    login.fprintAuth = lib.mkForce true;
    gdm-fingerprint.fprintAuth = true;

    login.rules.auth.fprintd-only-if-lid-open = lidCheckRule // {
      order = config.security.pam.services.login.rules.auth.fprintd.order - 1;
    };
    gdm-fingerprint.rules.auth.fprintd-only-if-lid-open = lidCheckRule // {
      order = config.security.pam.services.gdm-fingerprint.rules.auth.fprintd.order - 1;
    };
    sudo.rules.auth.fprintd-only-if-lid-open = lidCheckRule // {
      order = config.security.pam.services.sudo.rules.auth.fprintd.order - 1;
    };
    su.rules.auth.fprintd-only-if-lid-open = lidCheckRule // {
      order = config.security.pam.services.su.rules.auth.fprintd.order - 1;
    };
    polkit-1.rules.auth.fprintd-only-if-lid-open = lidCheckRule // {
      order = config.security.pam.services.polkit-1.rules.auth.fprintd.order - 1;
    };
  };

  # TPM 2.0
  security.tpm2 = {
    enable = true;
    pkcs11.enable = true;
    tctiEnvironment.enable = true;
  };

  # Virtualization
  virtualisation.libvirtd.enable = true;
  virtualisation.spiceUSBRedirection.enable = true;
  virtualisation.virtualbox.host.enable = true;
  users.extraGroups.vboxusers.members = [ "gmglbn_0" ];

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
    plugins = [ "git" "sudo" "kubectl" ];
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
  nixpkgs.config.permittedUnfreePackages = [ "antigravity" "libfprint-2-tod1-goodix" ];

  # User
  users.users.gmglbn_0 = {
    extraGroups = [ "libvirtd" "kvm" "video" "render" ];
    packages = with pkgs; [
      thunderbird
      qbittorrent-enhanced
      krita
      ayugram-desktop
      zed-editor
      wakatime-cli
      parsec-bin
      gnomeExtensions.appindicator
      gnomeExtensions.user-themes
      gnome-catppuccin
      obs-studio
      ptyxis
      dnsmasq
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
      rustup
      pkg-config
      gcc
      freetype
      fontconfig
      antigravity
      nheko
      deltachat-desktop
      lm_sensors
      signal-desktop
      chromium
      slack
      vlc 
      mpv
      modrinth-app
      eden
      bottles
    ];
  };

  # Additional system packages
  environment.systemPackages = with pkgs; [
    sbctl
    fastfetch
    hyfetch
    modemmanager
  ];

  services.sunshine = {
    enable = true;
    autoStart = true;
    capSysAdmin = true;
    openFirewall = true;
    package = pkgs.sunshine;
    settings = {
      capture_method = "wayland"; 
    };    
  };

  # State version
  system.stateVersion = "25.11";
}
