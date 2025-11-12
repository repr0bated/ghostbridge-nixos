# OpenFlow D-Bus Manager

Rust implementation of OpenFlow rule management for Open vSwitch via D-Bus interface.

## Features

- **D-Bus Interface**: Exposes OpenFlow management via `org.freedesktop.opdbus.Network.OpenFlow`
- **JSON-RPC Ready**: Works with dbus-mcp for JSON-RPC access
- **Type-Safe**: Written in Rust with comprehensive error handling
- **Async**: Built on Tokio for high performance
- **Tested**: Includes unit and integration tests

## Building

```bash
cd rust-modules/openflow
cargo build --release
```

## Installation

```bash
# Copy binary to system location
sudo cp target/release/openflow-dbus /usr/local/bin/

# Or integrate into op-dbus as a module
```

## Integration with op-dbus

This module is designed to be integrated into the `operation-dbus` project:

### Option 1: Standalone Service

Run as a separate D-Bus service:

```bash
# Create systemd service
sudo systemctl edit --full --force openflow-dbus.service
```

```ini
[Unit]
Description=OpenFlow D-Bus Service
After=dbus.service openvswitch.service
Requires=dbus.service openvswitch.service

[Service]
Type=simple
ExecStart=/usr/local/bin/openflow-dbus
Environment=RUST_LOG=info
Environment=OPENFLOW_CONFIG=/etc/op-dbus/state.json
Restart=always

[Install]
WantedBy=multi-user.target
```

### Option 2: Integrate into op-dbus

1. Copy this module to `operation-dbus/crates/openflow/`
2. Add to `operation-dbus/Cargo.toml`:

```toml
[workspace]
members = ["crates/openflow"]

[dependencies]
openflow-dbus = { path = "crates/openflow" }
```

3. In `operation-dbus/src/main.rs`:

```rust
use openflow_dbus::OpenFlowManager;

#[tokio::main]
async fn main() {
    // Load config
    let manager = OpenFlowManager::from_file("/etc/op-dbus/state.json")
        .await
        .expect("Failed to load config");

    // Start OpenFlow D-Bus interface
    tokio::spawn(async move {
        openflow_dbus::dbus::start_dbus_service(manager)
            .await
            .expect("OpenFlow D-Bus service failed");
    });

    // ... rest of op-dbus initialization
}
```

## D-Bus Methods

### ApplyDefaultRules
```bash
busctl call org.freedesktop.opdbus \
  /org/freedesktop/opdbus/network/openflow \
  org.freedesktop.opdbus.Network.OpenFlow \
  ApplyDefaultRules s "ovsbr0"
```

### AddFlowRule
```bash
busctl call org.freedesktop.opdbus \
  /org/freedesktop/opdbus/network/openflow \
  org.freedesktop.opdbus.Network.OpenFlow \
  AddFlowRule ss "ovsbr0" "priority=200,in_port=1,actions=drop"
```

### DumpFlows
```bash
busctl call org.freedesktop.opdbus \
  /org/freedesktop/opdbus/network/openflow \
  org.freedesktop.opdbus.Network.OpenFlow \
  DumpFlows s "ovsbr0"
```

### ApplyAllDefaultRules
```bash
busctl call org.freedesktop.opdbus \
  /org/freedesktop/opdbus/network/openflow \
  org.freedesktop.opdbus.Network.OpenFlow \
  ApplyAllDefaultRules
```

## JSON-RPC Usage

Via dbus-mcp server:

```bash
curl -X POST http://localhost:8096/jsonrpc \
  -H "Content-Type: application/json" \
  -d '{
    "jsonrpc": "2.0",
    "method": "openflow.apply_default_rules",
    "params": {"bridge": "ovsbr0"},
    "id": 1
  }'
```

## Testing

```bash
# Run unit tests
cargo test

# Run with logging
RUST_LOG=debug cargo test -- --nocapture

# Build and test
cargo build && cargo test
```

## Configuration

The manager reads configuration from `/etc/op-dbus/state.json`:

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
      }
    ]
  }
}
```

## Error Handling

All methods return proper D-Bus errors:

- `BridgeNotFound`: Bridge doesn't exist in configuration
- `InvalidFlowRule`: Flow rule syntax is invalid
- `OvsOfctlError`: ovs-ofctl command failed
- `PermissionDenied`: Insufficient permissions

## Logging

Set the `RUST_LOG` environment variable:

```bash
RUST_LOG=debug /usr/local/bin/openflow-dbus
RUST_LOG=openflow_dbus=trace /usr/local/bin/openflow-dbus
```

## License

See parent repository for license information.
