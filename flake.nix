{
  description = "gmglbn_0's NixOS configurations";

  nixConfig = {
    extra-substituters = [
      "https://nix-community.cachix.org"
      "https://cache.nixos.org"
      "https://attic.xuyh0120.win/lantian"
    ];
    trusted-public-keys = [
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "lantian:EeAUQ+W+6r7EtwnmYjeVwx5kOGEBpjlBfPlzGlTNvHc="
    ];
  };

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    nixos-hardware.url = "github:NixOS/nixos-hardware/master";

    lanzaboote = {
      url = "github:nix-community/lanzaboote/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-cachyos-kernel = {
      url = "github:xddxdd/nix-cachyos-kernel/release";
    };
  };

  outputs = inputs @ { self, nixpkgs, nixos-hardware, lanzaboote, nix-cachyos-kernel, ... }:
    with builtins; let
      # Helper functions
      inherit (nixpkgs) lib;

      gnomeCatppuccinOverlay = final: prev: {
        gnome-catppuccin =
          let
            src = prev.fetchFromGitHub {
              owner = "elisesouche";
              repo = "gnome-catppuccin";
              rev = "v1.0";
              hash = "sha256-R/pIVO8I3d5cAhgGSHthOpjHEo1Oxbaepb30raxWRnc=";
              fetchSubmodules = true;
            };
          in prev.callPackage "${src}" {};
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

            ./nodes/${hostname}/configuration.nix

            ./nodes/${hostname}/hardware-configuration.nix

            ({ lib, ... }: { networking.hostName = hostname; })

            { nixpkgs.overlays = [ gnomeCatppuccinOverlay nix-cachyos-kernel.overlays.default ]; }
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
