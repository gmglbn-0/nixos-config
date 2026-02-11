{ config, lib, pkgs, ... }:

with lib;

{
  options.services.quectel-modem-fix = {
    enable = mkEnableOption "Quectel EM061K modem radio state fix";
    
    device = mkOption {
      type = types.str;
      default = "/dev/cdc-wdm0";
      description = "MBIM device path for the Quectel modem";
    };
  };

  config = mkIf config.services.quectel-modem-fix.enable {
    # Systemd service to enable Quectel modem radio after ModemManager starts
    systemd.services.quectel-modem-fix = {
      description = "Enable Quectel EM061K radio state";
      after = [ "ModemManager.service" ];
      wants = [ "ModemManager.service" ];
      wantedBy = [ "multi-user.target" ];
      
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = pkgs.writeShellScript "quectel-modem-fix" ''
          ${pkgs.systemd}/bin/systemctl stop ModemManager
          sleep 2
          ${pkgs.libmbim}/bin/mbimcli -p -d ${config.services.quectel-modem-fix.device} --quectel-set-radio-state=on
          ${pkgs.libmbim}/bin/mbimcli -p -d ${config.services.quectel-modem-fix.device} --quectel-query-radio-state
          ${pkgs.systemd}/bin/systemctl start ModemManager
        '';
      };
    };
  };
}
