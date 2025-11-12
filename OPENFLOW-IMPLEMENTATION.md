# OpenFlow D-Bus Implementation Guide

## Current Status

**Current**: OpenFlow rules are managed by a bash script (`modules/scripts/ovs-flow-rules.sh`) that runs at boot.

**Target**: OpenFlow rules managed through `op-dbus` D-Bus interface with JSON-RPC API.

## Implementation Location

The OpenFlow management functionality should be implemented in the **operation-dbus** repository, not in this NixOS configuration repository.

## What Needs to Be Done

### 1. In operation-dbus Repository

Add OpenFlow management module to op-dbus:

```
operation-dbus/
├── src/
│   ├── network/
│   │   ├── mod.rs
│   │   └── openflow.rs    ← NEW: OpenFlow management
│   └── dbus/
│       └── interface.rs    ← UPDATE: Add OpenFlow interface
```

Key files to create/modify:
- `src/network/openflow.rs` - Core OpenFlow logic
- `src/dbus/interface.rs` - Expose D-Bus methods
- Update `Cargo.toml` with any new dependencies

### 2. Implementation Checklist

- [ ] Create `OpenFlowManager` struct in `src/network/openflow.rs`
- [ ] Implement methods:
  - [ ] `apply_default_rules(bridge: &str) -> Result<bool>`
  - [ ] `add_flow_rule(bridge: &str, rule: &str) -> Result<bool>`
  - [ ] `remove_flow_rule(bridge: &str, spec: &str) -> Result<bool>`
  - [ ] `dump_flows(bridge: &str) -> Result<Vec<String>>`
  - [ ] `clear_flows(bridge: &str) -> Result<bool>`
  - [ ] `apply_all_default_rules() -> Result<bool>`
- [ ] Add D-Bus interface at `/org/freedesktop/opdbus/network/openflow`
- [ ] Expose methods via JSON-RPC in dbus-mcp
- [ ] Read OpenFlow config from `state.json`
- [ ] Add error handling for ovs-ofctl failures
- [ ] Add logging for rule changes
- [ ] Write unit tests
- [ ] Write integration tests

### 3. Testing the Implementation

After implementation in operation-dbus:

```bash
# Build updated op-dbus
cd operation-dbus
cargo build --release --all-features

# Install new binary
sudo cp target/release/op-dbus /usr/local/bin/

# Restart service
sudo systemctl restart op-dbus.service

# Test D-Bus interface
busctl call org.freedesktop.opdbus \
  /org/freedesktop/opdbus/network/openflow \
  org.freedesktop.opdbus.Network.OpenFlow \
  ApplyDefaultRules s "ovsbr0"

# Verify rules were applied
sudo ovs-ofctl dump-flows ovsbr0
```

### 4. Update NixOS Configuration

Once op-dbus implements the OpenFlow interface, update this repository:

**Option A**: Keep bash script as fallback
```nix
systemd.services."ovs-flow-rules" = {
  script = ''
    # Try D-Bus first, fallback to bash script
    if busctl status org.freedesktop.opdbus >/dev/null 2>&1; then
      busctl call org.freedesktop.opdbus \
        /org/freedesktop/opdbus/network/openflow \
        org.freedesktop.opdbus.Network.OpenFlow \
        ApplyAllDefaultRules || ${pkgs.bash}/bin/bash ${./scripts/ovs-flow-rules.sh}
    else
      ${pkgs.bash}/bin/bash ${./scripts/ovs-flow-rules.sh}
    fi
  '';
};
```

**Option B**: Full migration to D-Bus (after validation)
```nix
systemd.services."ovs-flow-rules" = {
  description = "Apply OpenFlow rules via op-dbus";
  after = [ "op-dbus.service" "ovs-bridge-setup.service" ];
  requires = [ "op-dbus.service" ];

  script = ''
    until busctl status org.freedesktop.opdbus >/dev/null 2>&1; do
      sleep 1
    done

    busctl call org.freedesktop.opdbus \
      /org/freedesktop/opdbus/network/openflow \
      org.freedesktop.opdbus.Network.OpenFlow \
      ApplyAllDefaultRules
  '';
};
```

## Dependencies

The op-dbus implementation will need:

```toml
[dependencies]
zbus = "4.0"                    # D-Bus interface
tokio = "1.0"                   # Async runtime
serde = { version = "1.0", features = ["derive"] }
serde_json = "1.0"
anyhow = "1.0"                  # Error handling
tracing = "0.1"                 # Logging
```

## Example Rust Code Structure

```rust
// src/network/openflow.rs
use anyhow::{Context, Result};
use tokio::process::Command;
use tracing::{info, error};

pub struct OpenFlowManager {
    bridges: Vec<BridgeConfig>,
}

impl OpenFlowManager {
    pub async fn apply_default_rules(&self, bridge: &str) -> Result<bool> {
        info!("Applying default OpenFlow rules to {}", bridge);

        // Clear existing flows
        self.clear_flows(bridge).await?;

        // Get default rules from config
        let rules = self.get_default_rules(bridge)?;

        // Apply each rule
        for rule in rules {
            self.add_flow_internal(bridge, &rule).await?;
        }

        Ok(true)
    }

    async fn add_flow_internal(&self, bridge: &str, rule: &str) -> Result<()> {
        let output = Command::new("ovs-ofctl")
            .arg("add-flow")
            .arg(bridge)
            .arg(rule)
            .output()
            .await
            .context("Failed to execute ovs-ofctl")?;

        if !output.status.success() {
            let stderr = String::from_utf8_lossy(&output.stderr);
            error!("Failed to add flow rule: {}", stderr);
            anyhow::bail!("ovs-ofctl failed: {}", stderr);
        }

        info!("Added flow rule to {}: {}", bridge, rule);
        Ok(())
    }
}

// D-Bus interface
#[zbus::dbus_interface(name = "org.freedesktop.opdbus.Network.OpenFlow")]
impl OpenFlowManager {
    async fn apply_default_rules(&self, bridge_name: String) -> Result<bool> {
        self.apply_default_rules(&bridge_name).await
    }

    async fn dump_flows(&self, bridge_name: String) -> Result<Vec<String>> {
        // Implementation...
    }
}
```

## Benefits of D-Bus Approach

1. **Centralized**: All network operations through one service
2. **Type-Safe**: Rust implementation with compile-time checks
3. **Programmatic**: JSON-RPC API for automation/scripts
4. **Monitorable**: Can emit D-Bus signals for rule changes
5. **Testable**: Easier to unit test than bash scripts
6. **Maintainable**: Structured error handling and logging

## Timeline

1. **Week 1**: Implement core OpenFlow logic in operation-dbus
2. **Week 2**: Add D-Bus interface and testing
3. **Week 3**: Test with parallel bash script execution
4. **Week 4**: Full migration, remove bash script

## Questions?

See `OPENFLOW-DBUS-SPEC.md` for complete D-Bus interface specification.
