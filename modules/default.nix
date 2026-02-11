{ config, lib, pkgs, ... }:

{
  imports = [
    ./quectel-modem-fix.nix
  ];
}
