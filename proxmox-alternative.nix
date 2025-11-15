{ config, pkgs, lib, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ./modules/ghostbridge-ovs.nix
    ./modules/virtualization.nix
    ./modules/blockchain-storage.nix
    ./modules/dbus-orchestrator.nix
  ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  boot.kernelPackages = pkgs.linuxPackages_latest;
  boot.kernelParams = [
    "intel_iommu=on"
    "iommu=pt"
  ];
  boot.kernelModules = [ "kvm-intel" "vfio-pci" "openvswitch" ];

  networking.hostName = "proxmox-nixos";
  networking.useDHCP = true;
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [
      22      # SSH
      6080    # NoVNC
      8006    # Proxmox-like web UI (Cockpit)
      9090    # Cockpit alternative port
    ];
  };

  # Cockpit - Web-based management interface (Proxmox alternative)
  services.cockpit = {
    enable = true;
    port = 8006;  # Use Proxmox's port
    settings = {
      WebService = {
        AllowUnencrypted = true;
        ProtocolHeader = "X-Forwarded-Proto";
      };
    };
  };

  # Enable Cockpit modules for VM/container management
  environment.systemPackages = with pkgs; [
    cockpit
    cockpit-machines    # Virtual machine management
    cockpit-podman      # Container management

    # Virtualization tools
    virt-manager
    virt-viewer
    libvirt
    qemu_kvm

    # Container tools
    lxc
    lxd
    docker

    # Network tools
    openvswitch
    bridge-utils

    # Monitoring
    htop
    btop

    # Basic tools
    vim
    git
    curl
    wget
  ];

  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "yes";  # For Proxmox-like experience
      PasswordAuthentication = true;  # Change after setup
    };
  };

  users.users.root.initialPassword = "proxmox";  # Change immediately!

  users.users.admin = {
    isNormalUser = true;
    extraGroups = [ "wheel" "libvirtd" "docker" "lxd" ];
    initialPassword = "proxmox";  # Change immediately!
  };

  security.sudo.wheelNeedsPassword = false;

  system.stateVersion = "24.11";
}
