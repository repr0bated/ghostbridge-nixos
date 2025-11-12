{ config, pkgs, lib, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ./modules/ghostbridge-ovs.nix
    ./modules/blockchain-storage.nix
    ./modules/dbus-orchestrator.nix
    ./modules/virtualization.nix
  ];

  nixpkgs.overlays = [
    (final: prev: {
      unstable = import (builtins.fetchTarball {
        url = "https://github.com/NixOS/nixpkgs/archive/nixos-unstable.tar.gz";
      }) {
        system = final.system;
        config.allowUnfree = true;
      };
    })
  ];

  nixpkgs.config.allowUnfree = true;

  boot.loader = {
    efi = {
      canTouchEfiVariables = true;
      efiSysMountPoint = "/boot";
    };
    systemd-boot = {
      enable = true;
      configurationLimit = 10;
      editor = false;
      consoleMode = "auto";
      memtest86.enable = true;
      netbootxyz.enable = true;
    };
    timeout = 5;
  };

    efi.canTouchEfiVariables = true;
  };

  boot.kernelPackages = pkgs.linuxPackages_latest;
  boot.kernelParams = [
    "intel_iommu=on"
    "iommu=pt"
    "transparent_hugepage=never"
  ];
  boot.kernelModules = [ "kvm-intel" "vfio-pci" "openvswitch" ];

  networking = {
    hostName = "ghostbridge";
    networkmanager.enable = false;
    useNetworkd = true;
    useDHCP = false;
    
    firewall = {
      enable = true;
      allowedTCPPorts = [ 22 6080 8096 8006 9090 3000 ];
      trustedInterfaces = [ "ovsbr0" "ovsbr1" ];
    };
  };

  time.timeZone = "America/New_York";

  i18n.defaultLocale = "en_US.UTF-8";
  i18n.extraLocaleSettings = {
    LC_ADDRESS = "en_US.UTF-8";
    LC_IDENTIFICATION = "en_US.UTF-8";
    LC_MEASUREMENT = "en_US.UTF-8";
    LC_MONETARY = "en_US.UTF-8";
    LC_NAME = "en_US.UTF-8";
    LC_NUMERIC = "en_US.UTF-8";
    LC_PAPER = "en_US.UTF-8";
    LC_TELEPHONE = "en_US.UTF-8";
    LC_TIME = "en_US.UTF-8";
  };

  users.users.jeremy = {
    isNormalUser = true;
    description = "Jeremy";
    extraGroups = [ "wheel" "docker" "libvirtd" "kvm" "lxd" "networkmanager" ];
    shell = pkgs.bash;
    openssh.authorizedKeys.keys = [
    ];
  };

  security.sudo.wheelNeedsPassword = false;

  environment.systemPackages = with pkgs; [
    vim
    git
    wget
    curl
    htop
    btop
    tmux
    screen
    
    btrfs-progs
    btrfs-snap
    compsize
    
    openvswitch
    bridge-utils
    iproute2
    ethtool
    tcpdump
    wireshark-cli
    
    busctl
    d-spy
    dfeet
    
    qemu_kvm
    libvirt
    virt-manager
    lxc
    lxd
    
    rustup
    gcc
    pkg-config
    openssl
    
    jq
    yq
    
    prometheus-node-exporter
    
    python3
    
    gptfdisk
    parted
  ];

  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "no";
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
    };
    hostKeys = [
      {
        path = "/etc/ssh/ssh_host_ed25519_key";
        type = "ed25519";
      }
      {
        path = "/etc/ssh/ssh_host_rsa_key";
        type = "rsa";
        bits = 4096;
      }
    ];
  };

  services.journald.extraConfig = ''
    SystemMaxUse=500M
    MaxRetentionSec=1month
  '';

  services.prometheus = {
    enable = true;
    port = 9090;
    exporters.node = {
      enable = true;
      enabledCollectors = [ "systemd" "btrfs" ];
      port = 9100;
    };
  };

  services.grafana = {
    enable = true;
    settings = {
      server = {
        http_addr = "0.0.0.0";
        http_port = 3000;
      };
    };
  };

  nix = {
    settings = {
      experimental-features = [ "nix-command" "flakes" ];
      auto-optimise-store = true;
    };
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 30d";
    };
  };

  hardware.cpu.intel.updateMicrocode = true;
  hardware.enableAllFirmware = true;
  hardware.graphics.enable = true;

  system.stateVersion = "24.11";
}
