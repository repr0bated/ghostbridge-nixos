{ config, pkgs, lib, ... }:

{
  services.dbus = {
    enable = true;
    packages = [
      (pkgs.writeTextDir "etc/dbus-1/system.d/org.freedesktop.opdbus.conf" ''
        <!DOCTYPE busconfig PUBLIC
         "-//freedesktop//DTD D-BUS Bus Configuration 1.0//EN"
         "http://www.freedesktop.org/standards/dbus/1.0/busconfig.dtd">
        <busconfig>
          <policy user="root">
            <allow own="org.freedesktop.opdbus"/>
            <allow send_destination="org.freedesktop.opdbus"/>
            <allow receive_sender="org.freedesktop.opdbus"/>
          </policy>
          
          <policy context="default">
            <allow send_destination="org.freedesktop.opdbus"/>
            <allow receive_sender="org.freedesktop.opdbus"/>
          </policy>
        </busconfig>
      '')
    ];
  };

  environment.systemPackages = with pkgs; [
    dbus
  ];

  systemd.services."op-dbus" = {
    description = "Operation D-Bus Orchestrator";
    after = [ "dbus.service" "systemd-networkd.service" ];
    wants = [ "dbus.service" ];
    wantedBy = [ "multi-user.target" ];
    
    environment = {
      RUST_LOG = "info";
      DBUS_SYSTEM_BUS_ADDRESS = "unix:path=/run/dbus/system_bus_socket";
    };
    
    serviceConfig = {
      Type = "simple";
      Restart = "always";
      RestartSec = "5s";
      ExecStart = "/usr/local/bin/op-dbus run";
      WorkingDirectory = "/var/lib/op-dbus";
      StateDirectory = "op-dbus";
      User = "root";
    };
  };

  systemd.services."dbus-mcp-server" = {
    description = "D-Bus MCP Server";
    after = [ "op-dbus.service" ];
    wants = [ "op-dbus.service" ];
    wantedBy = [ "multi-user.target" ];
    
    environment = {
      RUST_LOG = "info";
    };
    
    serviceConfig = {
      Type = "simple";
      Restart = "always";
      RestartSec = "5s";
      ExecStart = "/usr/local/bin/dbus-mcp";
      WorkingDirectory = "/var/lib/op-dbus";
      StateDirectory = "op-dbus";
      User = "root";
    };
  };

  systemd.services."dbus-mcp-web" = {
    description = "D-Bus MCP Web Interface";
    after = [ "dbus-mcp-server.service" ];
    wants = [ "dbus-mcp-server.service" ];
    wantedBy = [ "multi-user.target" ];
    
    serviceConfig = {
      Type = "simple";
      Restart = "always";
      RestartSec = "5s";
      ExecStart = "/usr/local/bin/dbus-mcp-web";
      WorkingDirectory = "/var/lib/op-dbus";
      User = "root";
    };
  };

  environment.etc."op-dbus/state.json" = {
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
                "priority=100,dl_dst=ff:ff:ff:ff:ff:ff,actions=drop"
                "priority=100,dl_dst=01:00:00:00:00:00/01:00:00:00:00:00,actions=drop"
                "priority=50,actions=normal"
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
                "priority=100,dl_dst=ff:ff:ff:ff:ff:ff,actions=drop"
                "priority=100,dl_dst=01:00:00:00:00:00/01:00:00:00:00:00,actions=drop"
                "priority=50,actions=normal"
              ];
            };
          }
        ];
      };
      blockchain = {
        timing_path = "/var/lib/blockchain-timing";
        vectors_path = "/var/lib/blockchain-vectors";
        snapshot_interval = 1;
      };
    };
  };

  environment.etc."ghostbridge/test-dbus.sh" = {
    text = ''
      #!/usr/bin/env bash
      echo "=== D-Bus System Services ==="
      
      echo ""
      echo "=== op-dbus Service Status ==="
      systemctl status op-dbus.service --no-pager
      
      echo ""
      echo "=== D-Bus Introspection ==="
    '';
    mode = "0755";
  };
}
