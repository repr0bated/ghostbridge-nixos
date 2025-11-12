# OpenFlow Management D-Bus Interface Specification

## Overview

This specification defines the D-Bus interface for OpenFlow rule management to be implemented in `op-dbus`. This will replace the current bash script approach with a proper zbus-based JSON-RPC implementation.

## D-Bus Interface

**Service Name**: `org.freedesktop.opdbus`
**Object Path**: `/org/freedesktop/opdbus/network/openflow`
**Interface**: `org.freedesktop.opdbus.Network.OpenFlow`

## Methods

### ApplyDefaultRules

Apply default anti-broadcast/multicast rules to specified bridge.

**Signature**: `s -> b`

**Parameters**:
- `bridge_name` (string): Bridge name (e.g., "ovsbr0", "ovsbr1")

**Returns**:
- `success` (boolean): True if rules applied successfully

**Behavior**:
1. Clear existing flows on the bridge
2. Add priority=100 rule to drop broadcast packets (ff:ff:ff:ff:ff:ff)
3. Add priority=100 rule to drop multicast packets (01:00:00:00:00:00/01:00:00:00:00:00)
4. Add priority=50 rule for normal forwarding

**Example Call**:
```bash
busctl call org.freedesktop.opdbus \
  /org/freedesktop/opdbus/network/openflow \
  org.freedesktop.opdbus.Network.OpenFlow \
  ApplyDefaultRules s "ovsbr0"
```

### AddFlowRule

Add a custom OpenFlow rule to a bridge.

**Signature**: `ss -> b`

**Parameters**:
- `bridge_name` (string): Bridge name
- `flow_rule` (string): OpenFlow rule specification (ovs-ofctl format)

**Returns**:
- `success` (boolean): True if rule added successfully

**Example**:
```bash
busctl call org.freedesktop.opdbus \
  /org/freedesktop/opdbus/network/openflow \
  org.freedesktop.opdbus.Network.OpenFlow \
  AddFlowRule ss "ovsbr0" "priority=200,in_port=1,actions=drop"
```

### RemoveFlowRule

Remove a specific flow rule from a bridge.

**Signature**: `ss -> b`

**Parameters**:
- `bridge_name` (string): Bridge name
- `flow_spec` (string): Flow match specification

**Returns**:
- `success` (boolean): True if rule removed successfully

### DumpFlows

Get all current OpenFlow rules for a bridge.

**Signature**: `s -> as`

**Parameters**:
- `bridge_name` (string): Bridge name

**Returns**:
- `flows` (array of strings): List of flow rules

**Example**:
```bash
busctl call org.freedesktop.opdbus \
  /org/freedesktop/opdbus/network/openflow \
  org.freedesktop.opdbus.Network.OpenFlow \
  DumpFlows s "ovsbr0"
```

### ClearFlows

Clear all OpenFlow rules from a bridge.

**Signature**: `s -> b`

**Parameters**:
- `bridge_name` (string): Bridge name

**Returns**:
- `success` (boolean): True if flows cleared successfully

### ApplyAllDefaultRules

Apply default rules to all configured OVS bridges.

**Signature**: `-> b`

**Parameters**: None

**Returns**:
- `success` (boolean): True if rules applied to all bridges

**Behavior**:
- Reads bridge configuration from state.json
- Applies default rules to each bridge of type "openvswitch"

## JSON-RPC Interface

All methods are also exposed via JSON-RPC through the `dbus-mcp` server.

### Apply Default Rules

**Request**:
```json
{
  "jsonrpc": "2.0",
  "method": "openflow.apply_default_rules",
  "params": {
    "bridge": "ovsbr0"
  },
  "id": 1
}
```

**Response**:
```json
{
  "jsonrpc": "2.0",
  "result": {
    "success": true,
    "rules_applied": 3
  },
  "id": 1
}
```

### Add Flow Rule

**Request**:
```json
{
  "jsonrpc": "2.0",
  "method": "openflow.add_flow",
  "params": {
    "bridge": "ovsbr0",
    "rule": "priority=200,in_port=1,actions=drop"
  },
  "id": 2
}
```

### Dump Flows

**Request**:
```json
{
  "jsonrpc": "2.0",
  "method": "openflow.dump_flows",
  "params": {
    "bridge": "ovsbr0"
  },
  "id": 3
}
```

**Response**:
```json
{
  "jsonrpc": "2.0",
  "result": {
    "bridge": "ovsbr0",
    "flows": [
      "priority=100,dl_dst=ff:ff:ff:ff:ff:ff actions=drop",
      "priority=100,dl_dst=01:00:00:00:00:00/01:00:00:00:00:00 actions=drop",
      "priority=50 actions=NORMAL"
    ]
  },
  "id": 3
}
```

## Implementation Details

### Rust Dependencies

Add to `Cargo.toml`:
```toml
[dependencies]
zbus = "4.0"
tokio = { version = "1.0", features = ["full"] }
serde = { version = "1.0", features = ["derive"] }
serde_json = "1.0"
```

### Command Execution

The implementation should call `ovs-ofctl` using `tokio::process::Command`:

```rust
use tokio::process::Command;

async fn apply_flow_rule(bridge: &str, rule: &str) -> Result<(), Error> {
    let output = Command::new("ovs-ofctl")
        .arg("add-flow")
        .arg(bridge)
        .arg(rule)
        .output()
        .await?;

    if !output.status.success() {
        return Err(Error::CommandFailed(
            String::from_utf8_lossy(&output.stderr).to_string()
        ));
    }

    Ok(())
}
```

### Error Handling

Return D-Bus errors for:
- Bridge not found
- Invalid flow rule syntax
- ovs-ofctl command failure
- Permission denied

## State Configuration

Update `/etc/op-dbus/state.json` to include OpenFlow settings:

```json
{
  "version": "1.0",
  "network": {
    "bridges": [
      {
        "name": "ovsbr0",
        "type": "openvswitch",
        "dhcp": true,
        "openflow": {
          "auto_apply_defaults": true,
          "default_rules": [
            "priority=100,dl_dst=ff:ff:ff:ff:ff:ff,actions=drop",
            "priority=100,dl_dst=01:00:00:00:00:00/01:00:00:00:00:00,actions=drop",
            "priority=50,actions=normal"
          ]
        }
      },
      {
        "name": "ovsbr1",
        "type": "openvswitch",
        "address": "10.0.1.1/24",
        "openflow": {
          "auto_apply_defaults": true,
          "default_rules": [
            "priority=100,dl_dst=ff:ff:ff:ff:ff:ff,actions=drop",
            "priority=100,dl_dst=01:00:00:00:00:00/01:00:00:00:00:00,actions=drop",
            "priority=50,actions=normal"
          ]
        }
      }
    ]
  }
}
```

## Integration with NixOS

The `ovs-flow-rules.service` will be updated to call op-dbus instead of running a bash script:

```nix
systemd.services."ovs-flow-rules" = {
  description = "Apply OpenFlow rules via op-dbus";
  after = [ "op-dbus.service" "ovs-bridge-setup.service" ];
  wants = [ "op-dbus.service" ];
  wantedBy = [ "multi-user.target" ];

  serviceConfig = {
    Type = "oneshot";
    RemainAfterExit = true;
  };

  script = ''
    # Wait for op-dbus to be ready
    until busctl status org.freedesktop.opdbus >/dev/null 2>&1; do
      sleep 1
    done

    # Apply default rules via D-Bus
    busctl call org.freedesktop.opdbus \
      /org/freedesktop/opdbus/network/openflow \
      org.freedesktop.opdbus.Network.OpenFlow \
      ApplyAllDefaultRules
  '';
};
```

## Testing

### Manual Testing

```bash
# Apply default rules
busctl call org.freedesktop.opdbus \
  /org/freedesktop/opdbus/network/openflow \
  org.freedesktop.opdbus.Network.OpenFlow \
  ApplyDefaultRules s "ovsbr0"

# Verify rules
busctl call org.freedesktop.opdbus \
  /org/freedesktop/opdbus/network/openflow \
  org.freedesktop.opdbus.Network.OpenFlow \
  DumpFlows s "ovsbr0"

# Add custom rule
busctl call org.freedesktop.opdbus \
  /org/freedesktop/opdbus/network/openflow \
  org.freedesktop.opdbus.Network.OpenFlow \
  AddFlowRule ss "ovsbr0" "priority=150,tcp,tp_dst=22,actions=NORMAL"
```

### JSON-RPC Testing

```bash
curl -X POST http://localhost:8096/jsonrpc \
  -H "Content-Type: application/json" \
  -d '{
    "jsonrpc": "2.0",
    "method": "openflow.dump_flows",
    "params": {"bridge": "ovsbr0"},
    "id": 1
  }'
```

## Benefits

1. **Centralized Management**: All network operations through op-dbus
2. **Programmatic Access**: JSON-RPC API for automation
3. **Better Error Handling**: Structured errors instead of bash exit codes
4. **Type Safety**: Rust implementation with compile-time guarantees
5. **Monitoring**: D-Bus signals for flow rule changes
6. **Integration**: Works with existing MCP infrastructure

## Migration Path

1. Implement the D-Bus interface in op-dbus
2. Test with both bash script and D-Bus calls running in parallel
3. Update NixOS configuration to use D-Bus calls
4. Remove bash script after validation
5. Update documentation to reference D-Bus methods

## Future Enhancements

- D-Bus signals for flow rule changes
- Persistent rule storage and restoration
- Flow statistics via D-Bus
- Integration with network monitoring (Prometheus)
- Support for OpenFlow 1.3+ features
