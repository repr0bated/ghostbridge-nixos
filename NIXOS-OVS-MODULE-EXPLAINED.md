# NixOS Open vSwitch Module - Proper Usage

## The Problem

Your current configuration **manually creates bridges** using shell scripts:
```nix
systemd.services."ovs-bridge-setup" = {
  script = ''
    ovs-vsctl --may-exist add-br ovsbr0
    ovs-vsctl --may-exist add-port ovsbr0 ens1
    # ... manual commands
  '';
};
```

**This is WRONG for NixOS!** This is why it "keeps getting back in" - you're fighting against the declarative model.

---

## The NixOS Way: virtualisation.vswitch

NixOS provides **virtualisation.vswitch** module that declaratively manages OVS bridges.

### Current Configuration (modules/ghostbridge-ovs.nix)

You already have the basic setup:
```nix
virtualisation.vswitch = {
  enable = true;
  resetOnStart = false;
};
```

But this only enables the daemon - **it doesn't create any bridges!**

---

## Proper NixOS OVS Bridge Configuration

### Option 1: Using systemd.network (RECOMMENDED)

NixOS can create OVS bridges through **systemd-networkd** configuration:

```nix
{ config, pkgs, lib, ... }:

{
  # Enable OVS
  virtualisation.vswitch = {
    enable = true;
    resetOnStart = false;
  };

  # Let systemd-networkd manage everything
  systemd.network = {
    enable = true;
    wait-online.anyInterface = true;

    # Create OVS bridge ovsbr0
    netdevs."10-ovsbr0" = {
      netdevConfig = {
        Kind = "openvswitch";
        Name = "ovsbr0";
      };
    };

    # Attach ens1 to ovsbr0
    networks."10-ens1" = {
      matchConfig.Name = "ens1";
      networkConfig.Bridge = "ovsbr0";
      linkConfig.RequiredForOnline = "enslaved";
    };

    # Configure ovsbr0 network
    networks."20-ovsbr0" = {
      matchConfig.Name = "ovsbr0";
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

    # Create OVS bridge ovsbr1
    netdevs."11-ovsbr1" = {
      netdevConfig = {
        Kind = "openvswitch";
        Name = "ovsbr1";
      };
    };

    # Configure ovsbr1 network
    networks."21-ovsbr1" = {
      matchConfig.Name = "ovsbr1";
      address = [ "10.0.1.1/24" ];
      networkConfig = {
        DHCP = "no";
        IPv6AcceptRA = false;
        IPForward = true;
      };
      linkConfig.RequiredForOnline = "no";
    };
  };

  # Disable NIC offload (still needed for Hetzner)
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
      echo "Disabling hardware offload on ens1..."
      ethtool -K ens1 gso off || true
      ethtool -K ens1 tso off || true
      ethtool -K ens1 gro off || true
      ethtool -K ens1 lro off || true
    '';
  };

  # NO MORE ovs-bridge-setup service needed!
  # systemd-networkd creates the bridges automatically
}
```

**Benefits:**
- ✅ Declarative - bridges defined in config, not scripts
- ✅ Automatic - systemd-networkd creates them on boot
- ✅ Idempotent - running nixos-rebuild multiple times is safe
- ✅ No manual ovs-vsctl commands needed

---

## Option 2: Using networking.bridges (Simpler but less OVS-specific)

If you need simpler bridge management:

```nix
networking.bridges = {
  ovsbr0 = {
    interfaces = [ "ens1" ];
  };
  ovsbr1 = {
    interfaces = [ ];
  };
};

networking.interfaces.ovsbr0 = {
  useDHCP = true;
};

networking.interfaces.ovsbr1 = {
  ipv4.addresses = [{
    address = "10.0.1.1";
    prefixLength = 24;
  }];
};
```

**However**, this creates **Linux bridges**, not **OVS bridges**. For OpenFlow you need OVS, so use Option 1.

---

## Option 3: Manual but Declarative (What You Have Now - NOT RECOMMENDED)

Your current approach with `systemd.services."ovs-bridge-setup"` works, but it's:
- ❌ Not declarative (imperative shell commands)
- ❌ Hard to maintain
- ❌ Doesn't integrate with networkd
- ❌ Timing issues with networkd

---

## Why Your Current Code "Keeps Coming Back"

The issue isn't that the code keeps coming back - it's that **you're mixing imperative and declarative approaches**.

### The Conflict:

1. **NixOS expects**: Declare bridges in config → systemd-networkd creates them
2. **Your code does**: Manually run ovs-vsctl in a shell script
3. **What happens**:
   - systemd-networkd tries to manage network
   - Your script also tries to manage network
   - Race conditions, conflicts, timing issues

### The Fix:

**Remove the entire `ovs-bridge-setup` service** and use `systemd.network.netdevs` instead.

---

## Recommended Replacement

Replace your `modules/ghostbridge-ovs.nix` with:

```nix
{ config, pkgs, lib, ... }:

{
  virtualisation.vswitch = {
    enable = true;
    resetOnStart = false;
  };

  environment.systemPackages = with pkgs; [
    openvswitch
  ];

  # HARDWARE OFFLOAD DISABLE (keep this - it's important)
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
      echo "Disabling hardware offload on ens1..."
      ethtool -K ens1 gso off || true
      ethtool -K ens1 tso off || true
      ethtool -K ens1 gro off || true
      ethtool -K ens1 lro off || true
    '';
  };

  # DECLARATIVE BRIDGE CREATION
  systemd.network = {
    enable = true;
    wait-online.anyInterface = true;

    # Physical interface - just enslaved to bridge
    networks."10-ens1" = {
      matchConfig.Name = "ens1";
      linkConfig.RequiredForOnline = "no";
      networkConfig = {
        Bridge = "ovsbr0";  # This attaches ens1 to ovsbr0
      };
    };

    # OVS Bridge 0 (internet-facing)
    netdevs."10-ovsbr0" = {
      netdevConfig = {
        Kind = "openvswitch";
        Name = "ovsbr0";
      };
    };

    networks."20-ovsbr0" = {
      matchConfig.Name = "ovsbr0";
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

    # OVS Bridge 1 (internal)
    netdevs."11-ovsbr1" = {
      netdevConfig = {
        Kind = "openvswitch";
        Name = "ovsbr1";
      };
    };

    networks."21-ovsbr1" = {
      matchConfig.Name = "ovsbr1";
      address = [ "10.0.1.1/24" ];
      networkConfig = {
        DHCP = "no";
        IPv6AcceptRA = false;
        IPForward = true;
      };
      linkConfig.RequiredForOnline = "no";
    };
  };

  # OPENFLOW RULES (keep this)
  systemd.services."ovs-flow-rules" = {
    description = "Apply OpenFlow rules to OVS bridges";
    after = [ "systemd-networkd.service" "vswitchd.service" ];
    wants = [ "systemd-networkd.service" ];
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
```

---

## Key Changes

### ❌ Remove:
```nix
systemd.services."ovs-bridge-setup" = { ... };  # DELETE THIS ENTIRE SERVICE
```

### ✅ Add:
```nix
systemd.network.netdevs."10-ovsbr0" = { ... };  # Declarative bridge creation
systemd.network.netdevs."11-ovsbr1" = { ... };
```

---

## Testing the New Configuration

```bash
# Edit the config
sudo nano /etc/nixos/modules/ghostbridge-ovs.nix

# Test without activating
sudo nixos-rebuild test --flake /etc/nixos#ghostbridge

# Verify bridges exist
ovs-vsctl show
ip addr show ovsbr0
ip addr show ovsbr1

# If it works, make it permanent
sudo nixos-rebuild switch --flake /etc/nixos#ghostbridge
```

---

## Why This is Better

| Aspect | Old Way (Scripts) | New Way (Declarative) |
|--------|-------------------|----------------------|
| **Repeatability** | ❌ Timing issues | ✅ Always works |
| **Rollback** | ❌ Manual cleanup | ✅ Automatic |
| **Dependencies** | ❌ Race conditions | ✅ Proper ordering |
| **Integration** | ❌ Fights networkd | ✅ Works with networkd |
| **Debugging** | ❌ Check multiple services | ✅ Single point of truth |
| **NixOS Philosophy** | ❌ Imperative | ✅ Declarative |

---

## Documentation

NixOS systemd-networkd netdev options:
https://www.freedesktop.org/software/systemd/man/systemd.netdev.html

NixOS virtualisation.vswitch options:
https://search.nixos.org/options?query=virtualisation.vswitch

---

## Summary

**Stop fighting NixOS - embrace the declarative model:**

1. ❌ Delete the `ovs-bridge-setup` systemd service
2. ✅ Add `systemd.network.netdevs` for OVS bridges
3. ✅ Let systemd-networkd create and manage bridges
4. ✅ Keep OpenFlow rules service (that's fine)
5. ✅ Keep hardware offload disable (that's important)

This is the **NixOS way** - declare what you want, let the system figure out how to get there.
