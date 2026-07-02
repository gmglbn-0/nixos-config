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
  };

  outputs = inputs @ { self, nixpkgs, nixos-hardware, lanzaboote, nix-cachyos-kernel, noctalia-shell, ... }:
    with builtins; let
      # Helper functions
      inherit (nixpkgs) lib;



      # Temporary fix: upstream 1password tarball hash changed (re-upload), nixpkgs hasn't caught up yet.
      # Remove this overlay once nixpkgs updates the hash for _1password 8.12.21.
      onepasswordHashFix = final: prev: {
        _1password-gui = prev._1password-gui.overrideAttrs (old: {
          src = prev.fetchurl {
            url = "https://downloads.1password.com/linux/tar/stable/x64/1password-8.12.21.x64.tar.gz";
            hash = "sha256-JwiMi2iozP6jWSIUtgXla86aSAhuUob7snqtUbeXPpI=";
          };
        });
        _1password = prev._1password.overrideAttrs (old: {
          src = prev.fetchurl {
            url = "https://downloads.1password.com/linux/tar/stable/x64/1password-8.12.21.x64.tar.gz";
            hash = "sha256-JwiMi2iozP6jWSIUtgXla86aSAhuUob7snqtUbeXPpI=";
          };
        });
      };

      # Temporary fix: tpm2-pytss 2.3.0 tests fail with Python 3.13 (abstract class TypeError).
      # Remove this overlay once nixpkgs fixes tpm2-pytss compatibility.
      tpm2PytssFix = final: prev: {
        python3Packages = prev.python3Packages // {
          tpm2-pytss = prev.python3Packages.tpm2-pytss.overrideAttrs (old: {
            doCheck = false;
          });
        };
        python313Packages = prev.python313Packages // {
          tpm2-pytss = prev.python313Packages.tpm2-pytss.overrideAttrs (old: {
            doCheck = false;
          });
        };
      };

      buildSystem = hostname: system: modules:
        nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = {
            inherit inputs;
            prelude = import ./common/prelude.nix;
          };
          modules = [
            ./common/configuration.nix

            ./modules/default.nix

            ./nodes/${hostname}/configuration.nix

            ./nodes/${hostname}/hardware-configuration.nix

            ({ lib, ... }: { networking.hostName = hostname; })

            { nixpkgs.overlays = [ noctalia-shell.overlays.default onepasswordHashFix tpm2PytssFix nix-cachyos-kernel.overlays.default ]; }
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

      # Development shell with useful tools
      devShells = nixpkgs.lib.genAttrs [ "x86_64-linux" "aarch64-linux" ] (system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        pkgs.mkShell {
          nativeBuildInputs = with pkgs; [
            nixpkgs-fmt  # Nix formatter
            nil          # Nix LSP
            git
          ];
        }
      );
    };
}
