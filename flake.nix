{
  description = "gmglbn_0's NixOS configurations";
  
  nixConfig = {
    extra-substituters = [
      "https://nix-community.cachix.org"
      "https://cache.nixos.org"
    ];
    trusted-public-keys = [
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
    ];
  };

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";
    
    lanzaboote = {
      url = "github:nix-community/lanzaboote/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs @ { self, nixpkgs, nixos-hardware, lanzaboote, ... }:
    with builtins; let
      # Helper functions
      inherit (nixpkgs) lib;
      
      # Function to build a NixOS system configuration
      buildSystem = hostname: system: modules:
        nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = { 
            inherit inputs; 
            prelude = import ./common/prelude.nix;
          };
          modules = [
            # Common configuration for all hosts
            ./common/configuration.nix
            
            # Host-specific configuration
            ./nodes/${hostname}/configuration.nix
            
            # Hardware configuration
            ./nodes/${hostname}/hardware-configuration.nix
            
            # Set hostname
            ({ lib, ... }: { networking.hostName = hostname; })
          ] ++ modules;
        };
      
      # Automatically discover all hosts in ./nodes
      hosts = attrNames (readDir ./nodes);
      
      # Helper to get host metadata
      getHostMeta = hostname: import (./nodes/${hostname}/host-metadata.nix);
      
      # Build all host configurations
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
