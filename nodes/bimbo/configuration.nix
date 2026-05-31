{ config, pkgs, lib, inputs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../modules
  ];

  # Boot
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.kernelModules = [ "wl" ];
  boot.extraModulePackages = [ config.boot.kernelPackages.broadcom_sta ];
  
  # Allow unfree packages (like broadcom_sta)
  nixpkgs.config.allowUnfree = true;

  # Networking
  networking.networkmanager.enable = true;
  networking.firewall.enable = false;

  # Time & Locale
  time.timeZone = "Asia/Yerevan";
  i18n.defaultLocale = "en_US.UTF-8";

  # SSH
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      PermitRootLogin = "prohibit-password";
    };
  };

  # Power Management and Lid Switch
  powerManagement.enable = true;
  services.thermald.enable = true;
  services.upower.enable = true;
  # Disable sleep on lid close so it can operate as a closed headless server
  services.logind.settings.Login.HandleLidSwitch = "ignore";
  services.logind.settings.Login.HandleLidSwitchDocked = "ignore";

  # User (extends common)
  users.users.gmglbn_0 = {
    extraGroups = [ "wheel" "networkmanager" ];
    # packages = with pkgs; [];
  };

  # Hardware Acceleration for Wayland/Browser
  hardware.graphics.enable = true;

  environment.systemPackages = with pkgs; [
    wayvnc
  ];

  # Kiosk Mode using Sway and greetd
  programs.sway.enable = true;
  services.greetd = {
    enable = true;
    settings = {
      default_session = {
        command = "${pkgs.sway}/bin/sway --config ${pkgs.writeText "kiosk.conf" ''
          # Disable internal screen (MacBooks usually use LVDS-1 or eDP-1)
          output eDP-1 disable
          output LVDS-1 disable
          
          # Rotate any other connected screens 90 degrees CCW (270 clockwise)
          output * transform 90
          
          # Remove borders
          default_border none
          
          # Launch browser
          exec ${pkgs.chromium}/bin/chromium --kiosk --no-first-run http://eha.dipier.ro

          # Start VNC server on port 5900
          exec ${pkgs.wayvnc}/bin/wayvnc 0.0.0.0 5900
        ''}";
        user = "gmglbn_0";
      };
    };
  };

  nixpkgs.config.permittedInsecurePackages = [
    "broadcom-sta-6.30.223.271-59-6.18.24"
    "broadcom-sta-6.30.223.271-59-6.18.31"
  ];

  # Nix
  nix.settings.trusted-users = [ "root" "gmglbn_0" ];

  # State version
  system.stateVersion = "24.11";
}
