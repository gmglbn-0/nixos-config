{ config, lib, pkgs, modulesPath, ... }:

{
  imports =
    [ (modulesPath + "/installer/scan/not-detected.nix")
    ];

  boot.initrd.availableKernelModules = [ "xhci_pci" "thunderbolt" "nvme" ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ "kvm-intel" ];
  boot.extraModulePackages = [ ];

  fileSystems."/" =
    { device = "/dev/mapper/cryptroot";
      fsType = "btrfs";
    };

  boot.initrd.luks.devices."cryptroot".device = "/dev/disk/by-uuid/b7352d0f-2cbb-4fc2-bab0-a050e76b80c2";

  fileSystems."/boot" =
    { device = "/dev/disk/by-uuid/E183-846F";
      fsType = "vfat";
      options = [ "fmask=0022" "dmask=0022" ];
    };

  swapDevices = [
    { device = "/dev/disk/by-uuid/58386007-c3e0-4968-862e-3e2f634ae206"; }
  ];

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
}
