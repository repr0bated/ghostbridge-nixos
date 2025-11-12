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
        IPv4Forwarding = true;
        IPv6Forwarding = false;
      };
      linkConfig.RequiredForOnline = "no";
    };
  };

  systemd.services."ovs-bridge-setup" = {
    description = "Setup OVS Bridges for GhostBridge (OVSDB JSON-RPC)";
    after = [ "vswitchd.service" "network-pre.target" ];
    before = [ "network.target" "systemd-networkd.service" ];
    wants = [ "network-pre.target" ];
    wantedBy = [ "multi-user.target" ];
    requires = [ "vswitchd.service" ];
    
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "/usr/local/bin/op-dbus init-network --wan-interface ens1";
    };
  };

  systemd.services."ovs-flow-rules" = {
    description = "Apply OpenFlow rules to OVS bridges";
    after = [ "ovs-bridge-setup.service" "systemd-networkd.service" ];
    wants = [ "ovs-bridge-setup.service" ];
    wantedBy = [ "multi-user.target" ];
    requires = [ "vswitchd.service" ];

    path = with pkgs; [ openvswitch ];

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${pkgs.bash}/bin/bash ${./scripts/ovs-flow-rules.sh}";
    };
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
      echo ""
      echo "=== OpenFlow Rules (ovsbr0) ==="
      ovs-ofctl dump-flows ovsbr0
      echo ""
      echo "=== OpenFlow Rules (ovsbr1) ==="
      ovs-ofctl dump-flows ovsbr1
    '';
    mode = "0755";
  };
}
