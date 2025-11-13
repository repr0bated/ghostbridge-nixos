{ config, pkgs, lib, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ./modules/ghostbridge-ovs.nix
    ./modules/blockchain-storage.nix
    ./modules/dbus-orchestrator.nix
    ./modules/virtualization.nix
  ];

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
    extraGroups = [ "wheel" "docker" "libvirtd" "kvm" "lxd-lts" "networkmanager" ];
    shell = pkgs.bash;
    initialHashedPassword = "$6$2WpW4Hcgv2FL0FYi$Q2Yj6jicSmpp3Em4OaKOegDLiXc6sUdwgdVQyMq3dRaBi/uDbjQBqDta4VWYRtDCi53Kbkh3sY0sY1iYQYGls0";
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKqUqS3MZfw/CGGU2hYz/LzS+umOgLahNtxPQe7AVShK root@vps-privacy-router"
    ];
  };

  users.users.root.initialHashedPassword = "$6$YTrODDcTakPHfb4a$ocaGONhjAMXiRwRysu5aaPxPbDwhA24NTO7satPkLZoLbVdNENhGcGHz8NVp3ucw8QVMJaPLtVbYZJFrNK.771";

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
    
    
    qemu_kvm
    libvirt
    virt-manager
    lxc
    lxd-lts
    
    rustup
    gcc
    pkg-config
    openssl
    
    jq
    yq
    
    prometheus-node-exporter
    
    python3
    claude-code
    
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
  nixpkgs.overlays = [
    (final: prev: {
      unstable = import (builtins.fetchTarball {
        url = "https://github.com/NixOS/nixpkgs/archive/nixos-unstable.tar.gz";
        sha256 = "04h7cq8rp8815xb4zglkah4w6p2r5lqp7xanv89yxzbmnv29np2a";
      }) {
        system = final.system;
        config.allowUnfree = true;
      };
    })
  ];

  nixpkgs.config.allowUnfree = true;

  system.stateVersion = "25.05";
}
