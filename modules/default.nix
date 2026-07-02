{ config, lib, pkgs, ... }:

{
  imports = [
    ./quectel-modem-fix.nix
    ./services/nixos-autoupdate.nix
  ];
}
