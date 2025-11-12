{ config, pkgs, lib, ... }:

{

  virtualisation.vswitch = {
    enable = true;
    resetOnStart = false;
  };

  environment.systemPackages = with pkgs; [
    openvswitch
  ];



  systemd.services."disable-nic-offload" = {
    description = "Disable NIC hardware offload (CRITICAL for Hetzner)";
    after = [ "network-pre.target" ];
    before = [ "network.target" "systemd-networkd.service" ];
    wantedBy = [ "multi-user.target" ];
    
    path = with pkgs; [ ethtool ];
    
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    
    script = ''
      echo "Disabling hardware offload on ens1 (prevents Hetzner DPU issues)..."
      ethtool -K ens1 gso off || true
      ethtool -K ens1 tso off || true
      ethtool -K ens1 gro off || true
      ethtool -K ens1 lro off || true
      echo "Hardware offload disabled successfully"
    '';
  };

  systemd.network = {
    enable = true;
    wait-online.anyInterface = true;

    networks."10-ens1" = {
      matchConfig.Name = "ens1";
      linkConfig = {
        RequiredForOnline = "no";
      };
      networkConfig = {
        DHCP = "no";
        IPv6AcceptRA = false;
      };
    };

    networks."20-ovsbr0" = {
      matchConfig.Name = "ovsbr0-if";
      networkConfig = {
        DHCP = "yes";
        IPv6AcceptRA = false;
      };
      dhcpV4Config = {
        UseDNS = true;
        UseRoutes = true;
        UseGateway = true;
      };
      linkConfig.RequiredForOnline = "routable";
    };

    networks."21-ovsbr1" = {
      matchConfig.Name = "ovsbr1-if";
      address = [ "10.0.1.1/24" ];
      networkConfig = {
        DHCP = "no";
        IPv6AcceptRA = false;
        IPForward = true;
      };
      linkConfig.RequiredForOnline = "no";
    };
  };

  systemd.services."ovs-bridge-setup" = {
    description = "Setup OVS Bridges for GhostBridge";
    after = [ "vswitchd.service" "network-pre.target" ];
    before = [ "network.target" "systemd-networkd.service" ];
    wants = [ "network-pre.target" ];
    wantedBy = [ "multi-user.target" ];
    requires = [ "vswitchd.service" ];
    
    path = with pkgs; [ openvswitch iproute2 ];
    
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };

    script = ''
      set -euo pipefail

      echo "Waiting for openvswitch to be ready..."
      until ovs-vsctl --timeout=10 show &>/dev/null; do
        echo "Waiting for OVS..."
        sleep 1
      done

      echo "Creating OVS bridge: ovsbr0"
      ovs-vsctl --may-exist add-br ovsbr0
      
      echo "Adding physical interface ens1 to ovsbr0"
      ovs-vsctl --may-exist add-port ovsbr0 ens1
      
      echo "Creating internal interface for ovsbr0"
      ovs-vsctl --may-exist add-port ovsbr0 ovsbr0-if -- set interface ovsbr0-if type=internal
      
      echo "Bringing up ovsbr0 interfaces"
      ip link set ovsbr0 up
      ip link set ovsbr0-if up
      ip link set ens1 up

      echo "Creating OVS bridge: ovsbr1"
      ovs-vsctl --may-exist add-br ovsbr1
      
      echo "Creating internal interface for ovsbr1"
      ovs-vsctl --may-exist add-port ovsbr1 ovsbr1-if -- set interface ovsbr1-if type=internal
      
      echo "Bringing up ovsbr1 interfaces"
      ip link set ovsbr1 up
      ip link set ovsbr1-if up

      echo "OVS bridge setup complete"
    '';
  };


  boot.kernel.sysctl = {
    "net.ipv4.ip_forward" = 1;
    "net.ipv6.conf.all.forwarding" = 1;
    "net.bridge.bridge-nf-call-iptables" = 0;
    "net.bridge.bridge-nf-call-ip6tables" = 0;
  };

  environment.etc."ghostbridge/ovs-status.sh" = {
    text = ''
      #!/usr/bin/env bash
      echo "=== OVS Service Status ==="
      systemctl status vswitchd.service --no-pager
      echo ""
      echo "=== OVS Bridge Status ==="
      ovs-vsctl show
      echo ""
      echo "=== Network Interfaces ==="
      ip -br addr
    '';
    mode = "0755";
  };
}
