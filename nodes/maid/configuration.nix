{ config, lib, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
  ];

  # Boot loader
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Networking
  networking.networkmanager.enable = true;
  networking.firewall.enable = true;

  # Time & Locale
  time.timeZone = "Asia/Yerevan";
  i18n.defaultLocale = "en_US.UTF-8";

  # Tailscale
  services.tailscale.enable = true;

  # QEMU Guest Agent
  services.qemuGuest.enable = true;

  # SSH configuration
  services.openssh.settings = {
    PasswordAuthentication = false;
    PermitRootLogin = "prohibit-password";
  };

  users.users.root.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIB8hdK1kb0EHpDzC5WTLkQ4kS5GFt8IBZRjjgNx7SKj8"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPwrKg5K7ntD1x1WuVIl23zsTdppkd3gGfFsP24bUTkA"
  ];

  # ── Sudo ─────────────────────────────────────────────────────────────────
  security.sudo.wheelNeedsPassword = false;

  # Nix configuration
  nix.settings.trusted-users = [ "root" "gmglbn_0" ];

  # ── Packages ─────────────────────────────────────────────────────────────
  environment.systemPackages = with pkgs; [
    btrfs-progs
  ];

  # ── Storage (Btrfs RAID0 Game Cache) ─────────────────────────────────────
  fileSystems."/mnt/cache" = {
    device = "/dev/disk/by-label/gamestore";
    fsType = "btrfs";
    options = [ "defaults" "noatime" "compress=zstd:1" "nofail" ];
  };

  # ── Swap (Memory Headroom for Docker on 1GB VM) ──────────────────────────
  swapDevices = [
    {
      device = "/var/lib/swapfile";
      size = 4096;
    }
  ];

  # ── Firewall ─────────────────────────────────────────────────────────────
  networking.firewall.allowedTCPPorts = [ 80 443 53 ];
  networking.firewall.allowedUDPPorts = [ 53 ];

  # ── Docker ───────────────────────────────────────────────────────────────
  virtualisation.docker.enable = true;

  # ── LanCache (Game Cache + DNS) ───────────────────────────────────────────
  virtualisation.oci-containers.backend = "docker";

  virtualisation.oci-containers.containers.lancache-monolithic = {
    image = "lancachenet/monolithic:latest";
    ports = [
      "80:80"
      "443:443"
    ];
    environment = {
      CACHE_DISK_SIZE = "900g";
      CACHE_INDEX_SIZE = "250m";
      CACHE_MAX_AGE = "3650d";
      UPSTREAM_DNS = "1.1.1.1 1.0.0.1";
    };
    volumes = [
      "/mnt/cache/data:/data/cache"
      "/mnt/cache/logs:/data/logs"
      "/etc/localtime:/etc/localtime:ro"
    ];
  };

  virtualisation.oci-containers.containers.lancache-dns = {
    image = "lancachenet/lancache-dns:latest";
    ports = [
      "53:53/udp"
      "53:53/tcp"
    ];
    environment = {
      USE_GENERIC_CACHE = "true";
      LANCACHE_IP = "10.13.37.167";
      UPSTREAM_DNS = "1.1.1.1 1.0.0.1";
    };
  };

  # Cache directories
  systemd.tmpfiles.rules = [
    "d /mnt/cache      0755 root root -"
    "d /mnt/cache/data 0755 root root -"
    "d /mnt/cache/logs 0755 root root -"
  ];

  # State version
  system.stateVersion = "25.11";
}
