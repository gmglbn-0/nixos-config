{ config, lib, pkgs, ... }:

{
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  
  nixpkgs.config.allowUnfree = true;

  environment.systemPackages = with pkgs; [
    vim
    wget
    git
    htop
    tmux
    ncdu
    rsync
    unzip
    hyfetch
    fastfetch
    zsh-powerlevel10k
  ];

  services.openssh.enable = true;

  nix.gc = {
    automatic = true;
    dates = "daily";
    options = "--delete-older-than 7d";
  };

  nix.settings.auto-optimise-store = true;

  programs.mtr.enable = true;
  programs.zsh.enable = true;
  programs.zsh.ohMyZsh = {
    enable = true;
    plugins = [ "git" "sudo" "docker" "kubectl" ];
  };
  users.defaultUserShell = pkgs.zsh;

  # User
  users.users.gmglbn_0 = {
    isNormalUser = true;
    description = "Kita Lembrik";
    extraGroups = [ "networkmanager" "wheel" ];
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPwrKg5K7ntD1x1WuVIl23zsTdppkd3gGfFsP24bUTkA"
    ];
  };
}
