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

  # Niri compositor
  programs.niri.enable = true;
  programs.xwayland.enable = true;
  services.xserver.videoDrivers = [ "amdgpu" ];
  services.xserver.xkb = {
    layout = "us,ru";
    variant = "";
  };

  # Login manager — greetd with regreet, hosted inside niri
  programs.regreet.enable = true;
  services.greetd = {
    enable = true;
    settings = {
      default_session = {
        command = "${pkgs.niri}/bin/niri -c ${pkgs.writeText "niri-greeter-config" ''
          hotkey-overlay { skip-at-startup; }
          environment {
            GTK_USE_PORTAL "0"
            GDK_DEBUG "no-portals"
          }
          spawn-at-startup "sh" "-c" "${pkgs.regreet}/bin/regreet; pkill -f niri"
        ''}";
        user = "greeter";
      };
    };
  };

  # XDG portals for Wayland (screen sharing, file dialogs, etc.)
  xdg.portal = {
    enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-gnome pkgs.xdg-desktop-portal-gtk ];
  };

  # Bluetooth
  hardware.bluetooth.enable = true;
  hardware.bluetooth.powerOnBoot = true;

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
  services.upower = {
    enable = true;
    percentageLow = 10;
    percentageCritical = 5;
    percentageAction = 3;
    criticalPowerAction = "Hibernate";
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

  # TPM 2.0
  security.tpm2 = {
    enable = true;
    pkcs11.enable = false; # Temporarily disabled: tpm2-pytss 2.3.0 tests fail with Python 3.13 in nixpkgs-unstable
    # tctiEnvironment.enable = true;
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
    extraGroups = [ "libvirtd" "kvm" "video" "render" "dialout" ];
    packages = with pkgs; [
      thunderbird
      qbittorrent-enhanced
      krita
      ayugram-desktop
      zed-editor
      wakatime-cli
      parsec-bin
      # Niri companion tools
      alacritty
      fuzzel
      awww
      brightnessctl
      playerctl
      wl-clipboard
      grim
      slurp
      networkmanagerapplet
      noctalia-shell
      # Desktop apps
      obs-studio
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
      lm_sensors
      signal-desktop
      chromium
      slack
      vlc
      mpv
      modrinth-app
      spotify
      # bottles ## OpenLDAP is fucked up
    ];
  };

  # Additional system packages
  environment.systemPackages = with pkgs; [
    sbctl
    fastfetch
    hyfetch
    modemmanager
  ];

  # Deploy Niri config to user home
  system.activationScripts.niri-config = ''
    mkdir -p /home/gmglbn_0/.config/niri
    cp ${./niri-config.kdl} /home/gmglbn_0/.config/niri/config.kdl
    chown gmglbn_0:users /home/gmglbn_0/.config/niri/config.kdl
    chmod 644 /home/gmglbn_0/.config/niri/config.kdl
  '';

  # State version
  system.stateVersion = "25.11";
}
