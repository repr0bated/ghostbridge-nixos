# OVSDB JSON-RPC Migration Plan

## Current State
Shell scripts in `modules/ghostbridge-ovs.nix` use `ovs-vsctl` commands:
- `ovs-bridge-setup.service` - creates bridges with shell commands
- `ovs-flow-rules.service` - applies OpenFlow rules with shell script

## Problem
- Shell commands are imperative (not declarative)
- Hard to test, debug, and maintain
- No idempotency guarantees
- NixOS vswitch module doesn't have declarative bridge config

## Solution Options

### Option 1: NixOS Declarative Module (NOT AVAILABLE)
NixOS `virtualisation.vswitch` module only provides:
```nix
virtualisation.vswitch = {
  enable = true;
  resetOnStart = false;
  ipsec = false;
  package = pkgs.openvswitch;
};
```
**No built-in options for bridges/ports.** Would require custom module development.

### Option 2: OVSDB JSON-RPC via op-dbus ✓ RECOMMENDED
Use existing `ovsdb_jsonrpc.rs` client in operation-dbus:
- Pure Rust implementation
- Direct OVSDB protocol communication
- Already has create_bridge, add_port, etc.
- Idempotent operations

### Option 3: Keep Shell Scripts (CURRENT)
Continue using ovs-vsctl commands in systemd services.

## Recommended Approach

**Migrate to OVSDB JSON-RPC** via op-dbus initialization:

1. Create `op-dbus-network-init.service` that runs before `systemd-networkd`
2. Use op-dbus to call OVSDB JSON-RPC methods:
   ```rust
   let client = OvsdbClient::new();
   client.create_bridge("ovsbr0").await?;
   client.add_port("ovsbr0", "ens1").await?;
   client.add_internal_port("ovsbr0", "ovsbr0-if").await?;
   ```
3. Remove shell-based `ovs-bridge-setup.service`
4. Keep `ovs-flow-rules.service` OR migrate to OpenFlow JSON-RPC

## Benefits
- ✓ Type-safe Rust code
- ✓ Better error handling
- ✓ Testable with unit tests
- ✓ Idempotent operations
- ✓ No shell script parsing/injection vulnerabilities
- ✓ Integrates with existing op-dbus architecture

## Next Steps
1. Add bridge initialization to op-dbus startup
2. Update systemd service dependencies
3. Test on VPS deployment
4. Document OVSDB JSON-RPC API usage

## Implementation Status: ✓ COMPLETED

### What Was Implemented
1. **Created `network_init.rs` module** in operation-dbus
   - Pure Rust OVSDB JSON-RPC client
   - Declarative bridge configuration
   - Idempotent operations (checks before creating)
   - Proper error handling with context

2. **Added `op-dbus init-network` command**
   - CLI command to initialize GhostBridge network
   - Accepts `--wan-interface` parameter (default: ens1)
   - Creates ovsbr0 (WAN bridge) and ovsbr1 (LAN bridge)
   - Adds physical and internal interfaces
   - Brings up all interfaces

3. **Updated NixOS configuration** (modules/ghostbridge-ovs.nix)
   - Replaced shell-based `ovs-bridge-setup` service
   - Now calls: `/usr/local/bin/op-dbus init-network --wan-interface ens1`
   - Removed all `ovs-vsctl` commands from bridge setup

### What Remains Shell-Based
- **OpenFlow rules** (`ovs-flow-rules.sh`) - still uses `ovs-ofctl` commands
  - Could be migrated to OpenFlow JSON-RPC in future
  - Current implementation is simple and works well
  
- **Status/monitoring** (`ovs-status.sh`) - uses `ovs-vsctl show` and `ovs-ofctl dump-flows`
  - These are read-only diagnostic commands
  - No need to replace

### Benefits Achieved
- ✓ No more shell script parsing vulnerabilities in bridge setup
- ✓ Type-safe Rust code with proper error handling
- ✓ Idempotent operations (safe to run multiple times)
- ✓ Better logging with tracing framework
- ✓ Testable code (can unit test OVSDB operations)
- ✓ Integrates with existing op-dbus architecture

### Files Modified
- **operation-dbus/**
  - `src/network_init.rs` - NEW: network initialization module
  - `src/ovsdb_jsonrpc.rs` - moved to src/, made `find_bridge_uuid` public
  - `src/main.rs` - added `InitNetwork` command and handler
  
- **ghostbridge-nixos/**
  - `modules/ghostbridge-ovs.nix` - replaced shell script with op-dbus command
  - `modules/ghostbridge-ovs.nix.shell-backup` - backup of old shell-based version

### Deployment Notes
- op-dbus binary must be installed to `/usr/local/bin/op-dbus` on target system
- Binary size: ~14MB (statically linked Rust binary)
- Requires vswitchd.service to be running first
- Gracefully handles OVSDB connection retries (30 second timeout)

### Testing
```bash
# Test the command locally (requires OVSDB running)
sudo ./target/release/op-dbus init-network --wan-interface ens1

# Check logs
journalctl -u ovs-bridge-setup -f

# Verify bridges were created
sudo ovs-vsctl show
sudo ip -br addr
```
