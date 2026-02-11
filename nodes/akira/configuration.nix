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
  networking.firewall.enable = false;

  # Time & Locale
  time.timeZone = "UTC";
  i18n.defaultLocale = "en_US.UTF-8";

  # Filesystem 
  fileSystems."/data" = {
    device = "/dev/sda2";
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

  # Jellyfin
  services.jellyfin = {
    enable = true;
    openFirewall = true;
    dataDir = "/data/jellyfin";
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
        "hosts allow" = "192.168.106. 127.0.0.1 100.";
        "guest account" = "nobody";
        "map to guest" = "bad user";
      };
      "akira-smb500" = {
        "path" = "/data";
        "browseable" = "yes";
        "read only" = "no";
        "guest ok" = "no";
        "create mask" = "0644";
        "directory mask" = "0755";
      };
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
        SHUTDOWNCMD = "/run/current-system/sw/bin/sudo ${pkgs.systemd}/bin/systemctl hibernate";
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
          command = "${pkgs.systemd}/bin/systemctl hibernate";
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

  # User
  users.users.gmglbn_0 = {
    isNormalUser = true;
    description = "Kita Lembrik";
    extraGroups = [ "networkmanager" "wheel" "docker" ];
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPwrKg5K7ntD1x1WuVIl23zsTdppkd3gGfFsP24bUTkA"
    ];
  };

  # State version
  system.stateVersion = "23.05";
}
