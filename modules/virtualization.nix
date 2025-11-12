{ config, pkgs, lib, ... }:

{
  virtualisation.libvirtd = {
    enable = true;
    qemu = {
      package = pkgs.qemu_kvm;
      runAsRoot = true;
      swtpm.enable = true;
      ovmf = {
        enable = true;
        packages = [ pkgs.OVMFFull.fd ];
      };
    };
    onBoot = "ignore";
    onShutdown = "shutdown";
  };

  virtualisation.lxc = {
    enable = true;
    lxcfs.enable = true;
  };

  virtualisation.lxd = {
    enable = true;
    recommendedSysctlSettings = true;
  };

  virtualisation.docker = {
    enable = true;
    autoPrune = {
      enable = true;
      dates = "weekly";
    };
  };

  environment.systemPackages = with pkgs; [
    virt-manager
    virt-viewer
    libguestfs
    libvirt
    qemu_kvm
    OVMF
    
    lxc
    lxd
    
    docker
    docker-compose
    
    bridge-utils
    dnsmasq
    
    tigervnc
    novnc
  ];

  systemd.services."libvirt-ovs-network" = {
    description = "Configure libvirt to use OVS bridges";
    after = [ "libvirtd.service" "ovs-bridge-setup.service" ];
    wants = [ "libvirtd.service" "ovs-bridge-setup.service" ];
    wantedBy = [ "multi-user.target" ];
    
    path = with pkgs; [ libvirt ];
    
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };

    script = ''
      cat > /tmp/ovsbr0-network.xml <<XML
      <network>
        <name>ovsbr0</name>
        <forward mode='bridge'/>
        <bridge name='ovsbr0'/>
        <virtualport type='openvswitch'/>
      </network>
      XML

      cat > /tmp/ovsbr1-network.xml <<XML
      <network>
        <name>ovsbr1</name>
        <forward mode='bridge'/>
        <bridge name='ovsbr1'/>
        <virtualport type='openvswitch'/>
      </network>
      XML

      virsh net-define /tmp/ovsbr0-network.xml || true
      virsh net-start ovsbr0 || true
      virsh net-autostart ovsbr0 || true

      virsh net-define /tmp/ovsbr1-network.xml || true
      virsh net-start ovsbr1 || true
      virsh net-autostart ovsbr1 || true

      rm -f /tmp/ovsbr0-network.xml /tmp/ovsbr1-network.xml
    '';
  };

  systemd.services."novnc-server" = {
    description = "NoVNC Web Console for VMs";
    after = [ "network.target" "libvirtd.service" ];
    wantedBy = [ "multi-user.target" ];
    
    serviceConfig = {
      Type = "simple";
      Restart = "always";
      RestartSec = "5s";
      ExecStart = "${pkgs.novnc}/bin/novnc --listen 6080 --vnc localhost:5900";
      User = "nobody";
      Group = "nogroup";
    };
  };

  networking.bridges = {
    virbr0.interfaces = [ ];
  };

  boot.kernelModules = [ "vhost_net" "tun" "kvm-intel" ];

  users.groups.libvirtd.members = [ "jeremy" ];
  users.groups.docker.members = [ "jeremy" ];
  users.groups.lxd.members = [ "jeremy" ];
}
