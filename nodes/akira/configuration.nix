{ config, lib, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
  ];

  # Boot
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Networking
  networking.networkmanager.enable = true;
  networking.firewall.enable = true;

  # Time & Locale
  time.timeZone = "UTC";
  i18n.defaultLocale = "en_US.UTF-8";

  # Filesystem 
  fileSystems."/data" = {
    device = "/dev/disk/by-label/ssd500";
    fsType = "btrfs";
    options = [ "defaults" "nofail" ];
  };

  fileSystems."/media" = {
    device = "/dev/disk/by-label/RAID0";
    fsType = "btrfs";
    options = [ "defaults" "nofail" ];
  };

  # Docker 
  virtualisation.docker = {
    enable = true;
    daemon.settings = {
      data-root = "/data/docker";
    };
  };
  
  # Samba
  services.samba = {
    enable = true;
    openFirewall = true;
    settings = {
      global = {
        "workgroup" = "WORKGROUP";
        "server string" = "akira";
        "security" = "user";
        "map to guest" = "bad user";
        "hosts allow" = "192.168.106. 127.0.0.1 100.";
        "log file" = "/var/log/samba/%m.log";
        "max log size" = "50";
        
        # Performance Tweaks
        "socket options" = "TCP_NODELAY IPTOS_LOWDELAY SO_RCVBUF=131072 SO_SNDBUF=131072";
        "read raw" = "yes";
        "write raw" = "yes";
        "oplocks" = "yes";
        "max xmit" = "65535";
        "deadtime" = "15";
        "getwd cache" = "yes";
        "lpq cache time" = "30";
        "use sendfile" = "yes";
        "aio read size" = "16384";
        "aio write size" = "16384";
        "server signing" = "no";
        "strict locking" = "no";
      };
      "data" = {
        "path" = "/data";
        "browseable" = "yes";
        "read only" = "no";
        "guest ok" = "no";
        "create mask" = "0644";
        "directory mask" = "0755";
      };
      "media" = {
        "path" = "/media";
        "browseable" = "yes";
        "read only" = "no";
        "guest ok" = "no";
        "create mask" = "0644";
        "directory mask" = "0755";
      };
    };
  };


  # qBittorrent
  systemd.services.qbittorrent-nox = {
    description = "qBittorrent CLI";
    documentation = [ "man:qbittorrent-nox(1)" ];
    wants = [ "network-online.target" ];
    after = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      User = "gmglbn_0";
      Group = "users";
      ExecStart = "${pkgs.qbittorrent-nox}/bin/qbittorrent-nox --webui-port=8081";
      Restart = "on-failure";
    };
  };

  # UPS
  power.ups = {
    enable = true;
    mode = "netclient";
    upsmon = {
      enable = true;
      monitor."ups@192.168.106.2" = {
        powerValue = 1;
        user = "akira";
        passwordFile = "/etc/nixos/secrets/ups-password";
        type = "slave";
      };
      settings = {
        SHUTDOWNCMD = "sudo /run/current-system/sw/bin/systemctl hibernate";
        FINALDELAY = 5;
      };
    };
  };

  # Passwordless hibernate
  security.sudo.extraRules = [
    {
      users = [ "nutmon" ];
      commands = [
        {
          command = "/run/current-system/sw/bin/systemctl hibernate";
          options = [ "NOPASSWD" ];
        }
      ];
    }
  ];

  # Power management
  powerManagement.enable = true;
  powerManagement.powertop.enable = true;
  powerManagement.cpuFreqGovernor = "powersave";

  # Tailscale
  services.tailscale.enable = true;

  # Nix
  nix.settings.trusted-users = [ "root" "gmglbn_0" ];

  # SSH
  services.openssh.settings = {
    PasswordAuthentication = false;
    PermitRootLogin = "yes";
  };

  # User (extends common)
  users.users.gmglbn_0.extraGroups = [ "docker" ];

  # State version
  system.stateVersion = "23.05";
}
