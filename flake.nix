{
  description = "gmglbn_0's NixOS configurations";

  nixConfig = {
    extra-substituters = [
      "https://nix-community.cachix.org"
      "https://cache.nixos.org"
      "https://attic.xuyh0120.win/lantian"
      "https://nixos-apple-silicon.cachix.org"
    ];
    trusted-public-keys = [
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "lantian:EeAUQ+W+6r7EtwnmYjeVwx5kOGEBpjlBfPlzGlTNvHc="
      "nixos-apple-silicon.cachix.org-1:8psDu5SA5dAD7qA0zMy5UT292TxeEPzIz8VVEr2Js20="
    ];
  };

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-26.05";
    helium = {
      url = "github:AlvaroParker/helium-nix";
      inputs.nixpkgs.follows = "nixpkgs";
      };
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";

    apple-silicon = {
      url = "github:tpwrules/nixos-apple-silicon";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    lanzaboote = {
      url = "github:nix-community/lanzaboote/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-cachyos-kernel = {
      url = "github:xddxdd/nix-cachyos-kernel/release";
    };

    noctalia-shell = {
      url = "github:noctalia-dev/noctalia-shell";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    antigravity-nix.url = "github:jacopone/antigravity-nix";
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs @ { self, nixpkgs, nixos-hardware, lanzaboote, nix-cachyos-kernel, noctalia-shell, disko, ... }:
    with builtins; let
    
      inherit (nixpkgs) lib;

      buildSystem = hostname: system: modules:
        nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = {
            inherit inputs;
            prelude = import ./common/prelude.nix;
          };
          modules = [
            disko.nixosModules.disko

            ./common/configuration.nix

            ./modules/default.nix

            ./nodes/${hostname}/configuration.nix

            ./nodes/${hostname}/hardware-configuration.nix

            ({ lib, ... }: { networking.hostName = hostname; })

            { nixpkgs.overlays = [ noctalia-shell.overlays.default nix-cachyos-kernel.overlays.default inputs.antigravity-nix.overlays.default ]; }
          ] ++ modules;
        };

      hosts = attrNames (readDir ./nodes);

      getHostMeta = hostname: import (./nodes/${hostname}/host-metadata.nix);

      mkHostConfigs = listToAttrs (map (hostname:
        let
          meta = getHostMeta hostname;
          extraModules = [];
        in {
          name = hostname;
          value = buildSystem hostname meta.arch extraModules;
        }
      ) hosts);
    in
    {
      nixosConfigurations = mkHostConfigs;
    };
}
