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

  # ── Power management ─────────────────────────────────────────────────────
  # M1 has its own power management; just let the kernel handle it
  powerManagement.enable = true;

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

  # ── User ─────────────────────────────────────────────────────────────────
  users.users.gmglbn_0 = {
    packages = with pkgs; [
      alacritty
      fastfetch
      htop
    ];
  };

  # ── Nix ──────────────────────────────────────────────────────────────────
  nix.settings.trusted-users = [ "root" "gmglbn_0" ];

  # ── State version ────────────────────────────────────────────────────────
  system.stateVersion = "25.11";
}
