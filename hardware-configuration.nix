{ config, lib, pkgs, modulesPath, ... }:

{
  imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];

  boot.initrd.availableKernelModules = [ "xhci_pci" "ahci" "nvme" "usbhid" "sd_mod" ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ "kvm-intel" ];
  boot.extraModulePackages = [ ];

  fileSystems."/" = {
    device = "/dev/disk/by-label/nixos";
    fsType = "btrfs";
    options = [ 
      "subvol=@"
      "compress=zstd:3"
      "noatime"
      "space_cache=v2"
      "ssd"
      "discard=async"
    ];
  };

  fileSystems."/home" = {
    device = "/dev/disk/by-label/nixos";
    fsType = "btrfs";
    options = [ 
      "subvol=@home"
      "compress=zstd:3"
      "noatime"
      "space_cache=v2"
      "ssd"
      "discard=async"
    ];
  };

  fileSystems."/overlay" = {
    device = "/dev/disk/by-label/nixos";
    fsType = "btrfs";
    options = [ 
      "subvol=@overlay"
      "compress=zstd:3"
      "noatime"
      "space_cache=v2"
      "ssd"
    ];
  };

  fileSystems."/var/lib/blockchain-timing" = {
    device = "/dev/disk/by-label/nixos";
    fsType = "btrfs";
    options = [ 
      "subvol=@blockchain-timing"
      "compress=zstd:9"
      "noatime"
      "space_cache=v2"
    ];
  };

  fileSystems."/var/lib/blockchain-vectors" = {
    device = "/dev/disk/by-label/nixos";
    fsType = "btrfs";
    options = [ 
      "subvol=@blockchain-vectors"
      "compress=zstd:3"
      "noatime"
      "space_cache=v2"
    ];
  };

  fileSystems."/work" = {
    device = "/dev/disk/by-label/nixos";
    fsType = "btrfs";
    options = [ 
      "subvol=@work"
      "noatime"
      "nodatacow"
      "space_cache=v2"
      "ssd"
    ];
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-label/BOOT";
    fsType = "vfat";
  };

  swapDevices = [ ];

  networking.useDHCP = lib.mkDefault false;

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
}
