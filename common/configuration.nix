{ config, lib, pkgs, ... }:

{
  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    trusted-users = [ "root" "@wheel" "gmglbn_0" ];
    extra-substituters = [
      "https://nix-community.cachix.org"
      "https://attic.xuyh0120.win/lantian"
      "https://nixos-apple-silicon.cachix.org"
    ];
    extra-trusted-public-keys = [
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      "lantian:EeAUQ+W+6r7EtwnmYjeVwx5kOGEBpjlBfPlzGlTNvHc="
      "nixos-apple-silicon.cachix.org-1:8psDu5SA5dAD7qA0zMy5UT292TxeEPzIz8VVEr2Js20="
    ];
  };

  nixpkgs.config.allowUnfree = true;

  boot.kernelPackages = lib.mkDefault pkgs.linuxPackages;
  environment.systemPackages = with pkgs; [
    vim
    wget
    git
    htop
    bottom
    tmux
    ncdu
    rsync
    unzip
    hyfetch
    fastfetch
    zsh-powerlevel10k
  ];

  services.openssh.enable = true;

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
