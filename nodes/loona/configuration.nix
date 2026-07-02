{ config, pkgs, lib, inputs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    inputs.nixos-hardware.nixosModules.lenovo-thinkpad-x13-yoga
    inputs.lanzaboote.nixosModules.lanzaboote
    ../../modules
  ];

  # Secure Boot
  boot = {
    loader = {
      systemd-boot.enable = lib.mkForce false;
      efi.canTouchEfiVariables = true;
    };
    lanzaboote = {
      enable = true;
      pkiBundle = "/var/lib/sbctl";
    };
    kernelPackages = pkgs.cachyosKernels.linuxPackages-cachyos-latest;
    initrd = {
      kernelModules = [ "amdgpu" "i915" ];
      systemd.enable = true;
    };
    kernelParams = [
      "modprobe.blacklist=spi-nor"
      "modprobe.blacklist=kvm_amd"
      "i2c-i801.disable_features=0x10"
    ];
    extraModprobeConfig = ''
      options thinkpad_acpi fan_control=1
    '';
  };

  # Networking
  networking = {
    networkmanager.enable = true;
    firewall.enable = false;
    modemmanager.enable = true;
  };

  # Quectel modem fix
  services.quectel-modem-fix.enable = true;

  # Time & Locale
  time.timeZone = "Asia/Yerevan";
  i18n = {
    defaultLocale = "en_US.UTF-8";
    extraLocaleSettings = {
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
  };

  # Niri compositor
  programs = {
    niri.enable = true;
    xwayland.enable = true;
  };

  services.xserver = {
    videoDrivers = [ "amdgpu" ];
    xkb = {
      layout = "us,ru";
      variant = "";
    };
  };

  services.upower.enable = true;

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

  # XDG portals for Wayland
  xdg.portal = {
    enable = true;
    extraPortals = [
      pkgs.xdg-desktop-portal-gnome
      pkgs.xdg-desktop-portal-gtk
    ];
  };

  # Bluetooth
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
  };

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

  # Power & Thermals — keep it cool and quiet
  services.thermald.enable = true;

  services.thinkfan = {
    enable = true;
    levels = [
      [ 0     0  70 ]
      [ 1    65  75 ]
      [ 2    70  80 ]
      [ 3    75  85 ]
      [ 6    80  90 ]
      [ 7    85  95 ]
      [ "level auto" 90  32767 ]
    ];
  };

  services.auto-cpufreq = {
    enable = true;
    settings = {
      battery = {
        governor = "powersave";
        turbo = "never";
      };
      charger = {
        governor = "powersave";
        turbo = "auto";
      };
    };
  };

  services.power-profiles-daemon.enable = false;
  powerManagement.powertop.enable = true;

  # Audio
  services = {
    printing.enable = true;
    pulseaudio.enable = false;
    pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;   
    };
  };
  security.rtkit.enable = true;

  # Thunderbolt
  services.hardware.bolt.enable = true;

  # Fingerprint
  services.fprintd.enable = true;

  # TPM 2.0
  security.tpm2 = {
    enable = true;
    pkcs11.enable = true;
  };

  # iOS
  services.usbmuxd.enable = true;

  # Tailscale
  services.tailscale.enable = true;

  # Programs
  programs = {
    steam.enable = true;
    _1password.enable = true;
    _1password-gui = {
      enable = true;
      polkitPolicyOwners = [ "gmglbn_0" ];
    };
    firefox.enable = true;
    zsh.enable = true;
    zsh.ohMyZsh = {
      enable = true;
      plugins = [ "git" "sudo" ];
    };
  };

  # nix-ld
  programs.nix-ld.enable = true;
  programs.nix-ld.libraries = with pkgs; [
    stdenv.cc.cc.lib
    zlib
    openssl
  ];

  # Unfree and insecure
  nixpkgs.config.permittedInsecurePackages = [ "olm-3.2.16" ];
  nixpkgs.config.permittedUnfreePackages = [ "antigravity" ];

  # User
  users = {
    defaultUserShell = pkgs.zsh;
    users.gmglbn_0 = {
      extraGroups = [ "libvirtd" "kvm" "video" "render" "dialout" ];
      packages = with pkgs; [
        thunderbird
        qbittorrent-enhanced
        krita
        ayugram-desktop
        zed-editor
        parsec-bin
        xwayland-satellite
        alacritty
        fuzzel
        brightnessctl
        playerctl
        wl-clipboard
        wtype
        cliphist
        grim
        slurp
        networkmanagerapplet
        noctalia-shell
        nautilus
        obs-studio
        dnsmasq
        libmbim
        libqmi
        pciutils
        usbutils
        chatty
        pkg-config
        freetype
        fontconfig
        antigravity
        nheko
        signal-desktop
        chromium
        slack
        mpv
        modrinth-app
        spotify
        file-roller
        p7zip
        unrar
      ];
    };
  };

  # Additional system packages
  environment.systemPackages = with pkgs; [
    fastfetch
    hyfetch
    modemmanager
    e2fsprogs
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
