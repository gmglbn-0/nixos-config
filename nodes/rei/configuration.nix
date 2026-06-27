{ config, pkgs, lib, inputs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    inputs.apple-silicon.nixosModules.apple-silicon-support
  ];

  # ── Boot ─────────────────────────────────────────────────────────────────
  # Apple Silicon uses an EFI stub via m1n1 + U-Boot; systemd-boot works fine
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = false; # Apple firmware manages EFI vars

  # ── Networking ───────────────────────────────────────────────────────────
  networking.networkmanager.enable = true;
  networking.firewall.enable = true;

  # ── Time & Locale ────────────────────────────────────────────────────────
  time.timeZone = "Asia/Yerevan";
  i18n.defaultLocale = "en_US.UTF-8";

  # ── Audio ────────────────────────────────────────────────────────────────
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = false; # aarch64 — no 32-bit layer
    pulse.enable = true;
  };

  # ── Bluetooth ────────────────────────────────────────────────────────────
  hardware.bluetooth.enable = true;
  hardware.bluetooth.powerOnBoot = true;

  # ── Hardware acceleration ────────────────────────────────────────────────
  hardware.graphics.enable = true;

  # ── Apple Silicon firmware ───────────────────────────────────────────────
  # Peripheral firmware is committed to the repo at nodes/rei/firmware/
  hardware.asahi.peripheralFirmwareDirectory = ./firmware;

  # ── Power management ─────────────────────────────────────────────────────
  # M1 has its own power management; just let the kernel handle it
  powerManagement.enable = true;

  # Disable sleep on lid close so it can operate as a closed headless server
  services.logind.settings.Login = {
    HandleLidSwitch = "ignore";
    HandleLidSwitchDocked = "ignore";
    HandleLidSwitchExternalPower = "ignore";
  };

  # Turn off internal screen brightness on startup
  systemd.services.turn-off-backlight = {
    description = "Turn off internal screen backlight on startup";
    wantedBy = [ "multi-user.target" ];
    after = [ "systemd-backlight@backlight:apple-panel-bl.service" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.bash}/bin/bash -c 'if [ -f /sys/class/backlight/apple-panel-bl/brightness ]; then echo 0 > /sys/class/backlight/apple-panel-bl/brightness; fi'";
      RemainAfterExit = true;
    };
  };

  # ── Docker ───────────────────────────────────────────────────────────────
  virtualisation.docker = {
    enable = true;
    daemon.settings = {
      data-root = "/data/docker";
    };
  };

  # ── kaas-bot ─────────────────────────────────────────────────────────────
  virtualisation.oci-containers.containers.kaas-bot = {
    image = "kaas-bot";
    ports = [ "3005:3000" ];
    volumes = [ "/data/kaas-bot/data:/app/data" ];
    environmentFiles = [ "/data/kaas-bot/.env" ];
  };

  systemd.tmpfiles.rules = [
    "d /data 0755 root root -"
    "d /data/kaas-bot 0755 gmglbn_0 users -"
    "d /data/kaas-bot/data 0755 gmglbn_0 users -"
  ];

  # OpenSpeedTest

  virtualisation.oci-containers.containers.openspeedtest = {
    image = "openspeedtest/latest";
    ports = [
      "3000:3000"
      "3001:3001"
    ];
  };
  
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

  # ── Programs ─────────────────────────────────────────────────────────────
  programs.zsh.enable = true;
  programs.zsh.ohMyZsh = {
    enable = true;
    plugins = [ "git" "sudo" ];
  };
  users.defaultUserShell = pkgs.zsh;
  environment.systemPackages = [ 
    pkgs.hdparm 
    pkgs.lm_sensors 
    pkgs.smartmontools 
    pkgs.hddtemp 
    ];

  # ── User ─────────────────────────────────────────────────────────────────
  users.users.gmglbn_0 = {
    extraGroups = [ "docker" ];
    packages = with pkgs; [
      alacritty
      fastfetch
      htop
    ];
  };

  networking.firewall.allowedTCPPorts = [ 3005 ];

  # ── Sudo ─────────────────────────────────────────────────────────────────
  # Headless server — passwordless sudo so nixos-rebuild --sudo works remotely
  security.sudo.wheelNeedsPassword = false;

  # ── Nix ──────────────────────────────────────────────────────────────────
  nix.settings.trusted-users = [ "root" "gmglbn_0" ];

  # ── State version ────────────────────────────────────────────────────────
  system.stateVersion = "25.11";
}
