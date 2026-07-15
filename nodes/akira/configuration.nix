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
  time.timeZone = "Asia/Yerevan";
  i18n.defaultLocale = "en_US.UTF-8";

  # Filesystem
  fileSystems."/media" = {
    device = "/dev/disk/by-label/RAID0";
    fsType = "btrfs";
    options = [ "defaults" "nofail" ];
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

        "server min protocol" = "SMB3_00";
        "client min protocol" = "SMB3_00";
        "log file" = "/var/log/samba/%m.log";
        "max log size" = "50";

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
        "strict sync" = "no";

        # Time Machine feat
        "vfs objects" = "catia fruit streams_xattr";
        "fruit:aapl" = "yes";
        "fruit:nfs_aces" = "no";
        "fruit:model" = "MacSamba";
      };
      "media" = {
        "path" = "/media";
        "browseable" = "yes";
        "read only" = "no";
        "guest ok" = "yes";
        "create mask" = "0644";
        "directory mask" = "0755";
      };
      "timemachine-dipierro" = {
        "path" = "/media/timemachine/dipierro";
        "valid users" = "dipierro";
        "browseable" = "yes";
        "writable" = "yes";
        "fruit:time machine" = "yes";
        "fruit:time machine max size" = "1536G";
      };
      "timemachine-gmglbn_0" = {
        "path" = "/media/timemachine/gmglbn_0";
        "valid users" = "gmglbn_0";
        "browseable" = "yes";
        "writable" = "yes";
        "fruit:time machine" = "yes";
        "fruit:time machine max size" = "1536G";
      };
    };
  };

  # Avahi 
  services.avahi = {
    enable = true;
    nssmdns4 = true;
    publish = {
      enable = true;
      userServices = true;
    };
    extraServiceFiles = {
      smb = ''
        <?xml version="1.0" standalone='no'?>
        <!DOCTYPE service-group SYSTEM "avahi-service.dtd">
        <service-group>
          <name replace-wildcards="yes">%h</name>
          <service>
            <type>_smb._tcp</type>
            <port>445</port>
          </service>
          <service>
            <type>_device-info._tcp</type>
            <port>0</port>
            <txt-record>model=TimeCapsule8,119</txt-record>
          </service>
          <service>
            <type>_adisk._tcp</type>
            <port>9</port>
            <txt-record>sys=waMa=0,adVF=0x100</txt-record>
            <txt-record>dk0=adVN=timemachine-dipierro,adVF=0x82</txt-record>
            <txt-record>dk1=adVN=timemachine-gmglbn_0,adVF=0x82</txt-record>
          </service>
        </service-group>
      '';
    };
  };

  # WebDAV
  services.webdav = {
    enable = true;
    user = "gmglbn_0";
    group = "users";
    environmentFile = "/etc/nixos/secrets/webdav.env";
    settings = {
      address = "0.0.0.0";
      port = 8083;
      auth = true;
      tls = false;
      prefix = "/";
      directory = "/media";
      permissions = "CRUD";
      users = [
        {
          username = "gmglbn_0";
          password = "{env}WEBDAV_PASS_GMGLBN_0";
          permissions = "CRUD";
        }
        {
          username = "dipierro";
          password = "{env}WEBDAV_PASS_DIPIERRO";
          permissions = "CRUD";
        }
      ];
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

  # Tailscale
  services.tailscale.enable = true;

  # Nix
  nix.settings.trusted-users = [ "root" "gmglbn_0" "dipierro" ];

  # SSH
  services.openssh.settings = {
    PasswordAuthentication = false;
    PermitRootLogin = "prohibit-password";
  };

  users.users.root.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIB8hdK1kb0EHpDzC5WTLkQ4kS5GFt8IBZRjjgNx7SKj8"
  ];

  users.users.dipierro = {
    isNormalUser = true;
    description = "Avgustina DiPierro";
    extraGroups = [ "wheel" ];
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJprtCdLq8X4sYWZp3loq69iED8h1YEvfe2j3vUEIsVy"
    ];
  };

  # Restic
  services.restic.server = {
    enable = true;
    dataDir = "/media/restic";
    appendOnly = false;
    listenAddress = "8000";
    privateRepos = true;
    htpasswd-file = "/media/restic/.htpasswd";
  };

  networking.firewall.allowedTCPPorts = [ 445 8000 8081 8083 ];
  networking.firewall.allowedUDPPorts = [ 5353 ];  # mDNS

  # Create Time Machine directories on /media
  systemd.tmpfiles.rules = [
    "d /media/timemachine/dipierro  0770 dipierro  users -"
    "d /media/timemachine/gmglbn_0  0770 gmglbn_0  users -"
  ];

  # QEMU Guest Agent
  services.qemuGuest.enable = true;

  # State version
  system.stateVersion = "23.05";
}
