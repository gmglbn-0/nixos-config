{ config, lib, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
  ];

  # Networking
  networking.firewall.enable = true;
  networking.firewall.allowedTCPPorts = [ 2283 ];

  # Time & Locale
  time.timeZone = "Asia/Yerevan";
  i18n.defaultLocale = "en_US.UTF-8";

  # Tailscale
  services.tailscale.enable = true;

  # SSH
  services.openssh.settings = {
    PasswordAuthentication = false;
    PermitRootLogin = "prohibit-password";
  };

  users.users.root.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIB8hdK1kb0EHpDzC5WTLkQ4kS5GFt8IBZRjjgNx7SKj8"
  ];

  # Sudo & Nix permissions
  security.sudo.wheelNeedsPassword = false;
  nix.settings.trusted-users = [ "root" "gmglbn_0" ];

  # Hardware acceleration
  hardware.graphics.enable = true;

  # ── Docker ───────────────────────────────────────────────────────────────
  virtualisation.docker.enable = true;

  # ── Immich ───────────────────────────────────────────────────────────────
  virtualisation.oci-containers.backend = "docker";

  virtualisation.oci-containers.containers.immich-server = {
    image = "ghcr.io/immich-app/immich-server:release";
    ports = [ "2283:2283" ];
    volumes = [
      "/mnt/immich/im/upload:/data"
      "/etc/localtime:/etc/localtime:ro"
    ];
    environmentFiles = [ "/mnt/immich/im/.env" ];
    dependsOn = [ "immich-redis" "immich-postgres" ];
    extraOptions = [
      "--network=immich"
      "--device=/dev/dri:/dev/dri"
    ];
  };

  virtualisation.oci-containers.containers.immich-machine-learning = {
    image = "ghcr.io/immich-app/immich-machine-learning:release";
    volumes = [
      "immich-model-cache:/cache"
    ];
    environmentFiles = [ "/mnt/immich/im/.env" ];
    extraOptions = [
      "--network=immich"
      "--device=/dev/dri:/dev/dri"
    ];
  };

  virtualisation.oci-containers.containers.immich-redis = {
    image = "docker.io/valkey/valkey:9";
    extraOptions = [ "--network=immich" "--health-cmd" "redis-cli ping || exit 1" ];
  };

  virtualisation.oci-containers.containers.immich-postgres = {
    image = "ghcr.io/immich-app/postgres:14-vectorchord0.4.3-pgvectors0.2.0";
    environment = {
      POSTGRES_USER = "immich";
      POSTGRES_DB = "immich";
      POSTGRES_INITDB_ARGS = "--data-checksums";
    };
    environmentFiles = [ "/mnt/immich/im/.env" ];
    volumes = [ "/mnt/immich/im/db:/var/lib/postgresql/data" ];
    extraOptions = [ "--network=immich" "--shm-size=128mb" ];
  };

  # Create the Docker network for Immich before containers start
  systemd.services.docker-immich-network = {
    description = "Create Docker network for Immich";
    after = [ "docker.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${pkgs.bash}/bin/bash -c '${pkgs.docker}/bin/docker network create immich || true'";
    };
  };

  # Ensure directory structures exist for Immich
  systemd.tmpfiles.rules = [
    "d /mnt/immich/im        0755 gmglbn_0 users -"
    "d /mnt/immich/im/upload 0755 gmglbn_0 users -"
    "d /mnt/immich/im/db     0755 gmglbn_0 users -"
  ];

  # State version
  system.stateVersion = "25.11";
}
