{ config, pkgs, lib, ... }:

{
  imports = [
    ./hardware-configuration.nix
  ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "nixos";
  networking.useDHCP = true;

  environment.systemPackages = with pkgs; [
    vim
    dhcpcd
  ];

  system.stateVersion = "24.11";
}
