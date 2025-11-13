{ config, lib, ... }:

{
  # Official NixOS Open vSwitch configuration (Normal Bridge Mode)
  virtualisation.vswitch = {
    enable = true;
    resetOnStart = false;
  };

  environment.systemPackages = with config.virtualisation.vswitch.package; [
    openvswitch
    config.openflow-dbus
  ];

  systemd.services."disable-nic-offload" = {
    description = "Disable NIC hardware offload (CRITICAL for Hetzner)";
    after = [ "network-pre.target" ];
    before = [ "network.target" "systemd-networkd.service" ];
    wantedBy = [ "multi-user.target" ];

    path = [ config.virtualisation.vswitch.package.ethtool ];

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

    # OVS bridge network configurations (using internal interfaces)
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

  # OpenFlow D-Bus service (Rust implementation)
  systemd.services."openflow-dbus" = {
    description = "OpenFlow D-Bus Manager for OVS bridges";
    after = [ "dbus.service" "vswitchd.service" ];
    wants = [ "dbus.service" "vswitchd.service" ];
    wantedBy = [ "multi-user.target" ];
    requires = [ "vswitchd.service" ];

    environment = {
      RUST_LOG = "info";
    };

    serviceConfig = {
      Type = "simple";
      Restart = "always";
      RestartSec = "5s";
      ExecStart = "${config.openflow-dbus}/bin/openflow-dbus daemon";
      WorkingDirectory = "/var/lib/openflow-dbus";
      StateDirectory = "openflow-dbus";
      User = "root";
    };
  };

  # Apply default OpenFlow rules via D-Bus
  systemd.services."ovs-openflow-setup" = {
    description = "Apply default OpenFlow rules via D-Bus";
    after = [ "openflow-dbus.service" "vswitchd.service" ];
    wants = [ "openflow-dbus.service" ];
    wantedBy = [ "multi-user.target" ];
    requires = [ "openflow-dbus.service" "vswitchd.service" ];

    path = with config.virtualisation.vswitch.package; [ openvswitch ];

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };

    script = ''
      echo "Applying default OpenFlow rules via D-Bus..."

      # Wait for D-Bus service to be ready
      for i in {1..30}; do
        if busctl status org.freedesktop.opdbus >/dev/null 2>&1; then
          break
        fi
        echo "Waiting for openflow-dbus service... ($i/30)"
        sleep 1
      done

      # Apply default rules to both bridges via D-Bus
      echo "Applying rules to ovsbr0..."
      busctl call org.freedesktop.opdbus \
        /org/freedesktop/opdbus/network/openflow \
        org.freedesktop.opdbus.Network.OpenFlow \
        ApplyDefaultRules s "ovsbr0" || echo "Failed to apply rules to ovsbr0"

      echo "Applying rules to ovsbr1..."
      busctl call org.freedesktop.opdbus \
        /org/freedesktop/opdbus/network/openflow \
        org.freedesktop.opdbus.Network.OpenFlow \
        ApplyDefaultRules s "ovsbr1" || echo "Failed to apply rules to ovsbr1"

      echo "OpenFlow rules applied via D-Bus"
    '';
  };

  boot.kernel.sysctl = {
    "net.ipv4.ip_forward" = 1;
    "net.ipv6.conf.all.forwarding" = 1;
    "net.bridge.bridge-nf-call-iptables" = 0;
    "net.bridge.bridge-nf-call-ip6tables" = 0;
  };

  # OpenFlow D-Bus configuration
  environment.etc."openflow-dbus/state.json" = {
    text = builtins.toJSON {
      version = "1.0";
      network = {
        bridges = [
          {
            name = "ovsbr0";
            type = "openvswitch";
            dhcp = true;
            openflow = {
              auto_apply_defaults = true;
              default_rules = [
                "priority=150,tcp,tp_dst=22,actions=NORMAL"
                "priority=100,dl_dst=ff:ff:ff:ff:ff:ff,actions=DROP"
                "priority=100,dl_dst=01:00:00:00:00:00/01:00:00:00:00:00,actions=DROP"
                "priority=50,actions=NORMAL"
              ];
            };
          }
          {
            name = "ovsbr1";
            type = "openvswitch";
            address = "10.0.1.1/24";
            openflow = {
              auto_apply_defaults = true;
              default_rules = [
                "priority=150,tcp,tp_dst=22,actions=NORMAL"
                "priority=100,dl_dst=ff:ff:ff:ff:ff:ff,actions=DROP"
                "priority=100,dl_dst=01:00:00:00:00:00/01:00:00:00:00:00,actions=DROP"
                "priority=50,actions=NORMAL"
              ];
            };
          }
        ];
      };
    };
    mode = "0644";
  };

  environment.etc."ovs-status.sh" = {
    text = ''
      #!/usr/bin/env bash
      echo "=== OVS Service Status ==="
      systemctl status vswitchd.service --no-pager -l | head -10
      echo ""
      echo "=== OpenFlow D-Bus Service Status ==="
      systemctl status openflow-dbus.service --no-pager -l | head -10
      echo ""
      echo "=== OpenFlow Setup Status ==="
      systemctl status ovs-openflow-setup.service --no-pager -l | head -10
      echo ""
      echo "=== Network Interfaces ==="
      ip -br addr | grep -E "(ovsbr|ens1)"
      echo ""
      echo "=== D-Bus Service Check ==="
      busctl status org.freedesktop.opdbus 2>/dev/null && echo "✓ D-Bus service available" || echo "✗ D-Bus service not available"
      echo ""
      echo "=== Bridge Configuration ==="
      echo "OVS with OpenFlow rules managed via D-Bus/JSON-RPC"
      echo "Bridges: ovsbr0 (external), ovsbr1 (internal 10.0.1.1/24)"
      echo "SSH traffic: Prioritized (port 22) for Cursor remote access"
      echo "Broadcast/multicast: Blocked to prevent network noise"
    '';
    mode = "0755";
  };
}
