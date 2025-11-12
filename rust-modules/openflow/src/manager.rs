use crate::error::{Error, Result};
use serde::{Deserialize, Serialize};
use std::process::Stdio;
use tokio::process::Command;
use tracing::{debug, error, info, warn};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct BridgeConfig {
    pub name: String,
    #[serde(rename = "type")]
    pub bridge_type: String,
    #[serde(default)]
    pub dhcp: bool,
    pub address: Option<String>,
    pub openflow: Option<OpenFlowConfig>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct OpenFlowConfig {
    #[serde(default)]
    pub auto_apply_defaults: bool,
    #[serde(default)]
    pub default_rules: Vec<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct StateConfig {
    pub version: String,
    pub network: NetworkConfig,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct NetworkConfig {
    pub bridges: Vec<BridgeConfig>,
}

/// OpenFlow rule manager for OVS bridges
pub struct OpenFlowManager {
    config: StateConfig,
}

impl OpenFlowManager {
    /// Create a new OpenFlowManager from state configuration
    pub fn new(config: StateConfig) -> Self {
        Self { config }
    }

    /// Load configuration from state.json file
    pub async fn from_file(path: &str) -> Result<Self> {
        let content = tokio::fs::read_to_string(path).await?;
        let config: StateConfig = serde_json::from_str(&content)?;
        Ok(Self::new(config))
    }

    /// Apply default OpenFlow rules to a specific bridge
    pub async fn apply_default_rules(&self, bridge_name: &str) -> Result<bool> {
        info!("Applying default OpenFlow rules to bridge: {}", bridge_name);

        // Find bridge configuration
        let bridge = self
            .config
            .network
            .bridges
            .iter()
            .find(|b| b.name == bridge_name)
            .ok_or_else(|| Error::BridgeNotFound(bridge_name.to_string()))?;

        // Check if bridge has OpenFlow config
        let openflow_config = bridge
            .openflow
            .as_ref()
            .ok_or_else(|| Error::InvalidFlowRule("No OpenFlow config for bridge".to_string()))?;

        if !openflow_config.auto_apply_defaults {
            warn!("auto_apply_defaults is false for bridge: {}", bridge_name);
            return Ok(false);
        }

        // Clear existing flows first
        self.clear_flows(bridge_name).await?;

        // Apply each default rule
        for rule in &openflow_config.default_rules {
            self.add_flow_internal(bridge_name, rule).await?;
        }

        info!(
            "Successfully applied {} default rules to {}",
            openflow_config.default_rules.len(),
            bridge_name
        );
        Ok(true)
    }

    /// Add a custom flow rule to a bridge
    pub async fn add_flow_rule(&self, bridge_name: &str, flow_rule: &str) -> Result<bool> {
        info!("Adding flow rule to {}: {}", bridge_name, flow_rule);

        // Verify bridge exists
        self.verify_bridge_exists(bridge_name)?;

        // Add the flow rule
        self.add_flow_internal(bridge_name, flow_rule).await?;

        Ok(true)
    }

    /// Remove a specific flow rule from a bridge
    pub async fn remove_flow_rule(&self, bridge_name: &str, flow_spec: &str) -> Result<bool> {
        info!("Removing flow rule from {}: {}", bridge_name, flow_spec);

        // Verify bridge exists
        self.verify_bridge_exists(bridge_name)?;

        let output = Command::new("ovs-ofctl")
            .arg("del-flows")
            .arg(bridge_name)
            .arg(flow_spec)
            .stdout(Stdio::piped())
            .stderr(Stdio::piped())
            .output()
            .await?;

        if !output.status.success() {
            let stderr = String::from_utf8_lossy(&output.stderr);
            error!("Failed to remove flow rule: {}", stderr);
            return Err(Error::OvsOfctlError(stderr.to_string()));
        }

        info!("Successfully removed flow rule from {}", bridge_name);
        Ok(true)
    }

    /// Get all current flow rules for a bridge
    pub async fn dump_flows(&self, bridge_name: &str) -> Result<Vec<String>> {
        debug!("Dumping flows for bridge: {}", bridge_name);

        // Verify bridge exists
        self.verify_bridge_exists(bridge_name)?;

        let output = Command::new("ovs-ofctl")
            .arg("dump-flows")
            .arg(bridge_name)
            .stdout(Stdio::piped())
            .stderr(Stdio::piped())
            .output()
            .await?;

        if !output.status.success() {
            let stderr = String::from_utf8_lossy(&output.stderr);
            error!("Failed to dump flows: {}", stderr);
            return Err(Error::OvsOfctlError(stderr.to_string()));
        }

        let stdout = String::from_utf8_lossy(&output.stdout);
        let flows: Vec<String> = stdout
            .lines()
            .filter(|line| !line.starts_with("NXST_FLOW") && !line.trim().is_empty())
            .map(|s| s.trim().to_string())
            .collect();

        debug!("Found {} flows on {}", flows.len(), bridge_name);
        Ok(flows)
    }

    /// Clear all flow rules from a bridge
    pub async fn clear_flows(&self, bridge_name: &str) -> Result<bool> {
        info!("Clearing all flows from bridge: {}", bridge_name);

        // Verify bridge exists
        self.verify_bridge_exists(bridge_name)?;

        let output = Command::new("ovs-ofctl")
            .arg("del-flows")
            .arg(bridge_name)
            .stdout(Stdio::piped())
            .stderr(Stdio::piped())
            .output()
            .await?;

        if !output.status.success() {
            let stderr = String::from_utf8_lossy(&output.stderr);
            error!("Failed to clear flows: {}", stderr);
            return Err(Error::OvsOfctlError(stderr.to_string()));
        }

        info!("Successfully cleared all flows from {}", bridge_name);
        Ok(true)
    }

    /// Apply default rules to all configured bridges
    pub async fn apply_all_default_rules(&self) -> Result<bool> {
        info!("Applying default rules to all bridges");

        let mut success_count = 0;
        let mut error_count = 0;

        for bridge in &self.config.network.bridges {
            if bridge.bridge_type != "openvswitch" {
                debug!("Skipping non-OVS bridge: {}", bridge.name);
                continue;
            }

            match self.apply_default_rules(&bridge.name).await {
                Ok(applied) => {
                    if applied {
                        success_count += 1;
                    }
                }
                Err(e) => {
                    error!("Failed to apply rules to {}: {}", bridge.name, e);
                    error_count += 1;
                }
            }
        }

        info!(
            "Applied default rules: {} succeeded, {} failed",
            success_count, error_count
        );
        Ok(error_count == 0)
    }

    /// Internal method to add a flow rule
    async fn add_flow_internal(&self, bridge_name: &str, rule: &str) -> Result<()> {
        debug!("Adding flow to {}: {}", bridge_name, rule);

        let output = Command::new("ovs-ofctl")
            .arg("add-flow")
            .arg(bridge_name)
            .arg(rule)
            .stdout(Stdio::piped())
            .stderr(Stdio::piped())
            .output()
            .await?;

        if !output.status.success() {
            let stderr = String::from_utf8_lossy(&output.stderr);
            error!("Failed to add flow rule: {}", stderr);
            return Err(Error::OvsOfctlError(stderr.to_string()));
        }

        debug!("Successfully added flow rule to {}", bridge_name);
        Ok(())
    }

    /// Verify that a bridge exists in the configuration
    fn verify_bridge_exists(&self, bridge_name: &str) -> Result<()> {
        self.config
            .network
            .bridges
            .iter()
            .find(|b| b.name == bridge_name)
            .ok_or_else(|| Error::BridgeNotFound(bridge_name.to_string()))?;
        Ok(())
    }

    /// Get bridge configuration
    pub fn get_bridge_config(&self, bridge_name: &str) -> Option<&BridgeConfig> {
        self.config
            .network
            .bridges
            .iter()
            .find(|b| b.name == bridge_name)
    }

    /// List all configured bridges
    pub fn list_bridges(&self) -> Vec<&BridgeConfig> {
        self.config.network.bridges.iter().collect()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn create_test_config() -> StateConfig {
        StateConfig {
            version: "1.0".to_string(),
            network: NetworkConfig {
                bridges: vec![
                    BridgeConfig {
                        name: "ovsbr0".to_string(),
                        bridge_type: "openvswitch".to_string(),
                        dhcp: true,
                        address: None,
                        openflow: Some(OpenFlowConfig {
                            auto_apply_defaults: true,
                            default_rules: vec![
                                "priority=100,dl_dst=ff:ff:ff:ff:ff:ff,actions=drop".to_string(),
                                "priority=50,actions=normal".to_string(),
                            ],
                        }),
                    },
                    BridgeConfig {
                        name: "ovsbr1".to_string(),
                        bridge_type: "openvswitch".to_string(),
                        dhcp: false,
                        address: Some("10.0.1.1/24".to_string()),
                        openflow: Some(OpenFlowConfig {
                            auto_apply_defaults: true,
                            default_rules: vec!["priority=50,actions=normal".to_string()],
                        }),
                    },
                ],
            },
        }
    }

    #[test]
    fn test_new_manager() {
        let config = create_test_config();
        let manager = OpenFlowManager::new(config);
        assert_eq!(manager.list_bridges().len(), 2);
    }

    #[test]
    fn test_verify_bridge_exists() {
        let config = create_test_config();
        let manager = OpenFlowManager::new(config);

        assert!(manager.verify_bridge_exists("ovsbr0").is_ok());
        assert!(manager.verify_bridge_exists("ovsbr1").is_ok());
        assert!(manager.verify_bridge_exists("nonexistent").is_err());
    }

    #[test]
    fn test_get_bridge_config() {
        let config = create_test_config();
        let manager = OpenFlowManager::new(config);

        let bridge = manager.get_bridge_config("ovsbr0");
        assert!(bridge.is_some());
        assert_eq!(bridge.unwrap().name, "ovsbr0");

        let nonexistent = manager.get_bridge_config("nonexistent");
        assert!(nonexistent.is_none());
    }
}
