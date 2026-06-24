{ config, lib, pkgs, modulesPath, ... }:

{
  imports =
    [ (modulesPath + "/installer/scan/not-detected.nix")
    ];

  # Apple M1 — kernel modules handled by apple-silicon-support
  boot.initrd.availableKernelModules = [ "usb_storage" "usbhid" ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ ];
  boot.extraModulePackages = [ ];

  # ── Storage ──────────────────────────────────────────────────────────────
  fileSystems."/" =
    { device = "/dev/disk/by-uuid/d51565a4-6f15-419b-a222-3a51ce72ec00";
      fsType = "ext4";
    };

  fileSystems."/boot" =
    { device = "/dev/disk/by-uuid/E309-170F";
      fsType = "vfat";
      options = [ "fmask=0022" "dmask=0022" ];
    };

  # No swap — MacBook Air M1 has unified memory; swap is on-chip by design
  swapDevices = [ ];

  nixpkgs.hostPlatform = lib.mkDefault "aarch64-linux";
}
