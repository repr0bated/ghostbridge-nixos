use crate::manager::OpenFlowManager;
use crate::error::Result;
use std::sync::Arc;
use tokio::sync::RwLock;
use zbus::interface;
use tracing::{info, error};

/// D-Bus interface for OpenFlow management
pub struct OpenFlowDBus {
    manager: Arc<RwLock<OpenFlowManager>>,
}

impl OpenFlowDBus {
    pub fn new(manager: OpenFlowManager) -> Self {
        Self {
            manager: Arc::new(RwLock::new(manager)),
        }
    }
}

#[interface(name = "org.freedesktop.opdbus.Network.OpenFlow")]
impl OpenFlowDBus {
    /// Apply default OpenFlow rules to a specific bridge
    ///
    /// # Arguments
    /// * `bridge_name` - Name of the OVS bridge (e.g., "ovsbr0")
    ///
    /// # Returns
    /// * `true` if rules were applied successfully
    ///
    /// # Errors
    /// * Bridge not found
    /// * OpenFlow configuration missing
    /// * ovs-ofctl command failed
    async fn apply_default_rules(&self, bridge_name: String) -> zbus::fdo::Result<bool> {
        info!("D-Bus call: ApplyDefaultRules({})", bridge_name);

        let manager = self.manager.read().await;
        manager
            .apply_default_rules(&bridge_name)
            .await
            .map_err(|e| {
                error!("ApplyDefaultRules failed: {}", e);
                zbus::fdo::Error::Failed(e.to_string())
            })
    }

    /// Add a custom OpenFlow rule to a bridge
    ///
    /// # Arguments
    /// * `bridge_name` - Name of the OVS bridge
    /// * `flow_rule` - OpenFlow rule in ovs-ofctl format (e.g., "priority=200,in_port=1,actions=drop")
    ///
    /// # Returns
    /// * `true` if rule was added successfully
    async fn add_flow_rule(
        &self,
        bridge_name: String,
        flow_rule: String,
    ) -> zbus::fdo::Result<bool> {
        info!("D-Bus call: AddFlowRule({}, {})", bridge_name, flow_rule);

        let manager = self.manager.read().await;
        manager
            .add_flow_rule(&bridge_name, &flow_rule)
            .await
            .map_err(|e| {
                error!("AddFlowRule failed: {}", e);
                zbus::fdo::Error::Failed(e.to_string())
            })
    }

    /// Remove a specific flow rule from a bridge
    ///
    /// # Arguments
    /// * `bridge_name` - Name of the OVS bridge
    /// * `flow_spec` - Flow match specification
    ///
    /// # Returns
    /// * `true` if rule was removed successfully
    async fn remove_flow_rule(
        &self,
        bridge_name: String,
        flow_spec: String,
    ) -> zbus::fdo::Result<bool> {
        info!("D-Bus call: RemoveFlowRule({}, {})", bridge_name, flow_spec);

        let manager = self.manager.read().await;
        manager
            .remove_flow_rule(&bridge_name, &flow_spec)
            .await
            .map_err(|e| {
                error!("RemoveFlowRule failed: {}", e);
                zbus::fdo::Error::Failed(e.to_string())
            })
    }

    /// Get all current OpenFlow rules for a bridge
    ///
    /// # Arguments
    /// * `bridge_name` - Name of the OVS bridge
    ///
    /// # Returns
    /// * Array of flow rule strings
    async fn dump_flows(&self, bridge_name: String) -> zbus::fdo::Result<Vec<String>> {
        info!("D-Bus call: DumpFlows({})", bridge_name);

        let manager = self.manager.read().await;
        manager.dump_flows(&bridge_name).await.map_err(|e| {
            error!("DumpFlows failed: {}", e);
            zbus::fdo::Error::Failed(e.to_string())
        })
    }

    /// Clear all OpenFlow rules from a bridge
    ///
    /// # Arguments
    /// * `bridge_name` - Name of the OVS bridge
    ///
    /// # Returns
    /// * `true` if flows were cleared successfully
    async fn clear_flows(&self, bridge_name: String) -> zbus::fdo::Result<bool> {
        info!("D-Bus call: ClearFlows({})", bridge_name);

        let manager = self.manager.read().await;
        manager.clear_flows(&bridge_name).await.map_err(|e| {
            error!("ClearFlows failed: {}", e);
            zbus::fdo::Error::Failed(e.to_string())
        })
    }

    /// Apply default rules to all configured OVS bridges
    ///
    /// # Returns
    /// * `true` if all bridges were configured successfully
    async fn apply_all_default_rules(&self) -> zbus::fdo::Result<bool> {
        info!("D-Bus call: ApplyAllDefaultRules()");

        let manager = self.manager.read().await;
        manager.apply_all_default_rules().await.map_err(|e| {
            error!("ApplyAllDefaultRules failed: {}", e);
            zbus::fdo::Error::Failed(e.to_string())
        })
    }

    /// List all configured bridges
    ///
    /// # Returns
    /// * Array of bridge names
    async fn list_bridges(&self) -> zbus::fdo::Result<Vec<String>> {
        info!("D-Bus call: ListBridges()");

        let manager = self.manager.read().await;
        let bridges: Vec<String> = manager
            .list_bridges()
            .iter()
            .map(|b| b.name.clone())
            .collect();

        Ok(bridges)
    }

    /// Get bridge configuration as JSON
    ///
    /// # Arguments
    /// * `bridge_name` - Name of the OVS bridge
    ///
    /// # Returns
    /// * JSON string containing bridge configuration
    async fn get_bridge_config(&self, bridge_name: String) -> zbus::fdo::Result<String> {
        info!("D-Bus call: GetBridgeConfig({})", bridge_name);

        let manager = self.manager.read().await;
        let config = manager
            .get_bridge_config(&bridge_name)
            .ok_or_else(|| zbus::fdo::Error::Failed(format!("Bridge not found: {}", bridge_name)))?;

        serde_json::to_string(config)
            .map_err(|e| zbus::fdo::Error::Failed(format!("JSON serialization error: {}", e)))
    }
}

/// Start the D-Bus service
pub async fn start_dbus_service(manager: OpenFlowManager) -> Result<()> {
    info!("Starting OpenFlow D-Bus service");

    let openflow_dbus = OpenFlowDBus::new(manager);

    let _connection = zbus::Connection::system().await?;

    let _object_server = _connection
        .object_server()
        .at("/org/freedesktop/opdbus/network/openflow", openflow_dbus)
        .await?;

    info!("OpenFlow D-Bus service started at /org/freedesktop/opdbus/network/openflow");

    // Keep the service running
    std::future::pending::<()>().await;

    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::manager::{StateConfig, NetworkConfig, BridgeConfig, OpenFlowConfig};

    fn create_test_manager() -> OpenFlowManager {
        let config = StateConfig {
            version: "1.0".to_string(),
            network: NetworkConfig {
                bridges: vec![BridgeConfig {
                    name: "test-bridge".to_string(),
                    bridge_type: "openvswitch".to_string(),
                    dhcp: true,
                    address: None,
                    openflow: Some(OpenFlowConfig {
                        auto_apply_defaults: true,
                        default_rules: vec!["priority=50,actions=normal".to_string()],
                    }),
                }],
            },
        };

        OpenFlowManager::new(config)
    }

    #[tokio::test]
    async fn test_dbus_list_bridges() {
        let manager = create_test_manager();
        let dbus = OpenFlowDBus::new(manager);

        let bridges = dbus.list_bridges().await.unwrap();
        assert_eq!(bridges.len(), 1);
        assert_eq!(bridges[0], "test-bridge");
    }

    #[tokio::test]
    async fn test_dbus_get_bridge_config() {
        let manager = create_test_manager();
        let dbus = OpenFlowDBus::new(manager);

        let config_json = dbus.get_bridge_config("test-bridge".to_string()).await.unwrap();
        assert!(config_json.contains("test-bridge"));
        assert!(config_json.contains("openvswitch"));
    }
}
