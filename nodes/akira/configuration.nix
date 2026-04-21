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

  # WireGuard
  networking.wireguard.interfaces.wg0 = {
    ips = [ "10.0.0.2/24" ];
    listenPort = 51820;
    privateKeyFile = "/etc/wireguard/private.key";
    peers = [
      {
        # brianna
        publicKey = "YYiMSeoOKFsI/jtNtJnp3frmV0xx7bhRyO2DARI8NQ8=";
        endpoint = "91.132.132.199:51820";
        allowedIPs = [ "10.0.0.0/24" ];
        persistentKeepalive = 25;
      }
    ];
  };

  # Time & Locale
  time.timeZone = "UTC";
  i18n.defaultLocale = "en_US.UTF-8";

  # Filesystem
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

        # Apple / Time Machine support
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
    };
  };

  # Avahi (mDNS for Time Machine discovery)
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

  # eco-friendly!
  powerManagement.enable = true;
  powerManagement.powertop.enable = true;
  powerManagement.cpuFreqGovernor = "powersave";

  environment.systemPackages = [ pkgs.hdparm ];

  systemd.services.hdparm-spindown = {
    description = "hdparm-spindown service";
    wantedBy = [ "multi-user.target" ];
    after = [ "local-fs.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = pkgs.writeShellScript "hdparm-spindown" ''
        for dev in /dev/sd?; do
          [ -b "$dev" ] && ${pkgs.hdparm}/bin/hdparm -S 180 "$dev"
        done
      '';
    };
  };

  services.udev.extraRules = ''
    ACTION=="add", SUBSYSTEM=="block", KERNEL=="sd[a-z]", \
      RUN+="${pkgs.hdparm}/bin/hdparm -S 180 /dev/%k"
  '';

  # Hardware OpenGL (Mesa) for VM 3D Acceleration
  hardware.opengl.enable = true;

  # Tailscale
  services.tailscale.enable = true;

  # Nix
  nix.settings.trusted-users = [ "root" "gmglbn_0" "dipierro" ];

  # SSH
  services.openssh.settings = {
    PasswordAuthentication = false;
    PermitRootLogin = "no";
  };

  # User (extends common)
  users.users.gmglbn_0.extraGroups = [ "docker" ];

  users.users.dipierro = {
    isNormalUser = true;
    description = "Avgustina DiPierro";
    extraGroups = [ "wheel" "docker" ];
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

  networking.firewall.allowedTCPPorts = [ 445 8000 8081 8083 946 ];
  networking.firewall.allowedUDPPorts = [ 5353 51820 ];  # mDNS, WireGuard

  # Windows 11 VM
  systemd.services.swtpm-win11 = {
    description = "SWTPM for Windows 11 VM";
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      ExecStartPre = "${pkgs.coreutils}/bin/mkdir -p /var/lib/vm/win11/swtpm";
      ExecStart = "${pkgs.swtpm}/bin/swtpm socket --tpmstate dir=/var/lib/vm/win11/swtpm --ctrl type=unixio,path=/var/lib/vm/win11/swtpm-sock --tpm2";
      Restart = "on-failure";
    };
  };

  systemd.services.win11-vm = {
    description = "Windows 11 QEMU VM";
    wants = [ "swtpm-win11.service" ];
    after = [ "swtpm-win11.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      ExecStartPre = [
        "${pkgs.coreutils}/bin/mkdir -p /var/lib/vm/win11"
        "${pkgs.bash}/bin/sh -c 'if [ ! -f /var/lib/vm/win11/OVMF_VARS.fd ]; then ${pkgs.coreutils}/bin/cp --no-preserve=mode ${pkgs.OVMFFull.fd}/FV/OVMF_VARS.fd /var/lib/vm/win11/OVMF_VARS.fd; fi'"
        "${pkgs.bash}/bin/sh -c 'if [ ! -f /var/lib/vm/win11/disk.qcow2 ]; then ${pkgs.qemu_kvm}/bin/qemu-img create -f qcow2 /var/lib/vm/win11/disk.qcow2 120G; fi'"
      ];
      ExecStart = ''
        ${pkgs.qemu_kvm}/bin/qemu-system-x86_64 -name win11 -enable-kvm -m 6G -smp 4 \
          -cpu host,hv_relaxed,hv_spinlocks=0x1fff,hv_vapic,hv_time -machine q35 \
          -device virtio-vga-gl -display egl-headless,rendernode=/dev/dri/renderD128 \
          -chardev socket,id=chrtpm,path=/var/lib/vm/win11/swtpm-sock \
          -tpmdev emulator,id=tpm0,chardev=chrtpm \
          -device tpm-tis,tpmdev=tpm0 \
          -drive if=pflash,format=raw,readonly=on,file=${pkgs.OVMFFull.fd}/FV/OVMF_CODE.fd \
          -drive if=pflash,format=raw,file=/var/lib/vm/win11/OVMF_VARS.fd \
          -drive file=/var/lib/vm/win11/disk.qcow2,format=qcow2,if=virtio \
          -netdev user,id=net0 -device virtio-net-pci,netdev=net0 \
          -device usb-ehci,id=ehci -device usb-tablet \
          -vnc 127.0.0.1:1
      '';
      Restart = "on-failure";
    };
  };

  # Proxy VNC to port 946
  systemd.services.win11-vnc-proxy = {
    description = "VNC Proxy for Windows 11 VM on port 946";
    requires = [ "win11-vm.service" ];
    after = [ "win11-vm.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      ExecStart = "${pkgs.socat}/bin/socat TCP-LISTEN:946,fork,reuseaddr TCP:127.0.0.1:5901";
      Restart = "always";
      RestartSec = 3;
    };
  };

  # State version
  system.stateVersion = "23.05";
}
