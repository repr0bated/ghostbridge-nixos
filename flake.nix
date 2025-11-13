{
  description = "GhostBridge Infrastructure System - Complete NixOS Configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
    claude-code.url = "github:repr0bated/claude-code-nix";
    claude-code.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, nixpkgs-unstable, claude-code }:
  let
    system = "x86_64-linux";
    pkgs = nixpkgs.legacyPackages.${system};
  in {
    packages.${system} = {
      openflow-dbus = pkgs.callPackage ./rust-modules/openflow { };
    };

    nixosConfigurations.ghostbridge = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        ./configuration.nix
        ./hardware-configuration.nix
        ./modules/ghostbridge-ovs.nix
        ./modules/blockchain-storage.nix
        ./modules/dbus-orchestrator.nix
        ./modules/virtualization.nix
        ({ pkgs, ... }: {
          nixpkgs.overlays = [
            (final: prev: {
              unstable = import nixpkgs-unstable {
                system = "x86_64-linux";
                config.allowUnfree = true;
              };
            })
            claude-code.overlays.default
            (final: prev: {
              openflow-dbus = self.packages.${system}.openflow-dbus;
            })
          ];
        })
      ];
    };
  };
}
