{ config, pkgs, lib, inputs, ... }:

{
  imports = [
    ./hardware-configuration.nix
  ];

  # ── Networking ───────────────────────────────────────────────────────────
  networking.firewall.enable = true;
  networking.firewall.allowedTCPPorts = [ 3000 3001 3005 8080 8085 ];

  # ── Time & Locale ────────────────────────────────────────────────────────
  time.timeZone = "Asia/Yerevan";
  i18n.defaultLocale = "en_US.UTF-8";

  # ── Docker ───────────────────────────────────────────────────────────────
  virtualisation.docker.enable = true;
  virtualisation.oci-containers.backend = "docker";

  # ── kaas-bot ─────────────────────────────────────────────────────────────
  virtualisation.oci-containers.containers.kaas-bot = {
    image = "kaas-bot";
    ports = [ "3005:3000" ];
    volumes = [ "/data/kaas-bot/data:/app/data" ];
    environmentFiles = [ "/data/kaas-bot/.env" ];
  };

  # ── once-tagger ──────────────────────────────────────────────────────────
  virtualisation.oci-containers.containers.once-tagger = {
    image = "once-tagger";
    volumes = [ "/data/once-tagger/data:/app/data" ];
    environmentFiles = [ "/data/once-tagger/.env" ];
  };

  # ── OpenSpeedTest ────────────────────────────────────────────────────────
  virtualisation.oci-containers.containers.openspeedtest = {
    image = "openspeedtest/latest";
    ports = [
      "3000:3000"
      "3001:3001"
    ];
  };

  # ── Firefly III ──────────────────────────────────────────────────────────
  virtualisation.oci-containers.containers.firefly-iii-db = {
    image = "postgres:15";
    environment = {
      POSTGRES_USER = "firefly";
      POSTGRES_DB = "firefly";
    };
    environmentFiles = [ "/data/firefly-iii/.env.db" ];
    volumes = [ "/data/firefly-iii/db:/var/lib/postgresql/data" ];
    extraOptions = [ "--network=firefly-net" ];
  };

  virtualisation.oci-containers.containers.firefly-iii = {
    image = "fireflyiii/core:latest";
    ports = [ "8080:8080" ];
    dependsOn = [ "firefly-iii-db" ];
    environment = {
      DB_CONNECTION = "pgsql";
      DB_HOST = "firefly-iii-db";
      DB_PORT = "5432";
      DB_DATABASE = "firefly";
      DB_USERNAME = "firefly";
    };
    environmentFiles = [ "/data/firefly-iii/.env" ];
    volumes = [ "/data/firefly-iii/upload:/var/www/html/storage/upload" ];
    extraOptions = [ "--network=firefly-net" ];
  };

  # Ensure Firefly III docker network exists before containers start
  systemd.services.docker-firefly-network = {
    description = "Create Docker network for Firefly III";
    after = [ "docker.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${pkgs.bash}/bin/bash -c '${pkgs.docker}/bin/docker network create firefly-net || true'";
    };
  };

  # ── avb-builder ──────────────────────────────────────────────────────────
  virtualisation.oci-containers.containers.avb-builder = {
    image = "avb-builder:latest";
    ports = [ "8085:8085" ];
    volumes = [
      "/data/avb-builder:/data"
    ];
    environment = {
      AVB_DATA_DIR = "/data";
      AVB_PORT = "8085";
      AVB_HOST = "0.0.0.0";
      AVB_BASE_URL = "http://100.64.0.131:8085";
    };
  };

  # ── Directory rules & dev nodes ──────────────────────────────────────────
  systemd.tmpfiles.rules = [
    "c! /dev/net/tun 0666 root root - 10:200"
    "d /data 0755 root root -"
    "d /data/kaas-bot 0755 gmglbn_0 users -"
    "d /data/kaas-bot/data 0755 gmglbn_0 users -"
    "d /data/once-tagger 0755 gmglbn_0 users -"
    "d /data/once-tagger/data 0755 gmglbn_0 users -"
    "d /data/firefly-iii 0755 gmglbn_0 users -"
    "d /data/firefly-iii/db 0755 gmglbn_0 users -"
    "d /data/firefly-iii/upload 0775 33 users -"
    "d /data/avb-builder 0755 gmglbn_0 users -"
    "d /data/avb-builder/keys 0700 gmglbn_0 users -"
    "d /data/avb-builder/storage 0755 gmglbn_0 users -"
    "d /data/avb-builder/www 0755 gmglbn_0 users -"
    "d /data/avb-builder/www/ota 0755 gmglbn_0 users -"
    "d /data/avb-builder/www/builds 0755 gmglbn_0 users -"
  ];

  # ── Tailscale ────────────────────────────────────────────────────────────
  services.tailscale.enable = true;

  # ── SSH ──────────────────────────────────────────────────────────────────
  services.openssh.settings = {
    PasswordAuthentication = false;
    PermitRootLogin = "prohibit-password";
  };

  users.users.root.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIB8hdK1kb0EHpDzC5WTLkQ4kS5GFt8IBZRjjgNx7SKj8"
  ];

  # ── Shell & Utilities ───────────────────────────────────────────────────
  programs.zsh.enable = true;
  programs.zsh.ohMyZsh = {
    enable = true;
    plugins = [ "git" "sudo" ];
  };
  users.defaultUserShell = pkgs.zsh;

  # ── User ─────────────────────────────────────────────────────────────────
  users.users.gmglbn_0 = {
    extraGroups = [ "docker" ];
    packages = with pkgs; [
      fastfetch
      htop
    ];
  };

  # ── Sudo ─────────────────────────────────────────────────────────────────
  security.sudo.wheelNeedsPassword = false;

  # ── Nix ──────────────────────────────────────────────────────────────────
  nix.settings.trusted-users = [ "root" "gmglbn_0" ];

  # ── State version ────────────────────────────────────────────────────────
  system.stateVersion = "25.11";
}
