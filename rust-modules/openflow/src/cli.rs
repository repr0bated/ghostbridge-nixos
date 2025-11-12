use clap::{Parser, Subcommand};
use colored::*;

/// OpenFlow D-Bus Manager - Manage OpenFlow rules for Open vSwitch bridges
#[derive(Parser)]
#[command(author, version, about, long_about = None)]
#[command(propagate_version = true)]
pub struct Cli {
    /// Path to state configuration file
    #[arg(short, long, default_value = "/etc/op-dbus/state.json")]
    pub config: String,

    /// Enable verbose logging
    #[arg(short, long)]
    pub verbose: bool,

    #[command(subcommand)]
    pub command: Commands,
}

#[derive(Subcommand)]
pub enum Commands {
    /// Start the D-Bus service daemon
    ///
    /// Starts the OpenFlow management D-Bus service that exposes methods
    /// for managing OpenFlow rules on OVS bridges. The service runs continuously
    /// and responds to D-Bus method calls.
    ///
    /// Examples:
    ///   # Start with default config
    ///   openflow-dbus daemon
    ///
    ///   # Start with custom config
    ///   openflow-dbus --config /path/to/config.json daemon
    ///
    ///   # Start with verbose logging
    ///   openflow-dbus -v daemon
    Daemon,

    /// Apply default OpenFlow rules to a bridge
    ///
    /// Applies the default anti-broadcast and anti-multicast rules configured
    /// in state.json to the specified bridge. This will:
    ///   1. Clear all existing flows on the bridge
    ///   2. Add priority=100 rule to drop broadcast packets (ff:ff:ff:ff:ff:ff)
    ///   3. Add priority=100 rule to drop multicast packets
    ///   4. Add priority=50 rule for normal forwarding
    ///
    /// Examples:
    ///   # Apply default rules to ovsbr0
    ///   openflow-dbus apply-defaults ovsbr0
    ///
    ///   # Apply to ovsbr1 with verbose output
    ///   openflow-dbus -v apply-defaults ovsbr1
    ///
    /// Equivalent D-Bus call:
    ///   busctl call org.freedesktop.opdbus \
    ///     /org/freedesktop/opdbus/network/openflow \
    ///     org.freedesktop.opdbus.Network.OpenFlow \
    ///     ApplyDefaultRules s "ovsbr0"
    ApplyDefaults {
        /// Name of the OVS bridge (e.g., ovsbr0, ovsbr1)
        bridge: String,
    },

    /// Apply default rules to all configured bridges
    ///
    /// Iterates through all bridges configured in state.json and applies
    /// default OpenFlow rules to each OVS bridge that has auto_apply_defaults
    /// enabled in its configuration.
    ///
    /// Examples:
    ///   # Apply to all bridges
    ///   openflow-dbus apply-all
    ///
    /// Equivalent D-Bus call:
    ///   busctl call org.freedesktop.opdbus \
    ///     /org/freedesktop/opdbus/network/openflow \
    ///     org.freedesktop.opdbus.Network.OpenFlow \
    ///     ApplyAllDefaultRules
    ApplyAll,

    /// Add a custom OpenFlow rule to a bridge
    ///
    /// Adds a custom flow rule using ovs-ofctl syntax. The rule is added
    /// in addition to existing rules (does not clear existing flows).
    ///
    /// Examples:
    ///   # Drop packets from specific port
    ///   openflow-dbus add-flow ovsbr0 "priority=200,in_port=1,actions=drop"
    ///
    ///   # Allow SSH traffic with high priority
    ///   openflow-dbus add-flow ovsbr0 "priority=150,tcp,tp_dst=22,actions=NORMAL"
    ///
    ///   # Drop all ICMP packets
    ///   openflow-dbus add-flow ovsbr1 "priority=100,icmp,actions=drop"
    ///
    ///   # Forward IPv4 traffic normally
    ///   openflow-dbus add-flow ovsbr0 "priority=10,ip,actions=NORMAL"
    ///
    /// Equivalent D-Bus call:
    ///   busctl call org.freedesktop.opdbus \
    ///     /org/freedesktop/opdbus/network/openflow \
    ///     org.freedesktop.opdbus.Network.OpenFlow \
    ///     AddFlowRule ss "ovsbr0" "priority=200,in_port=1,actions=drop"
    AddFlow {
        /// Name of the OVS bridge
        bridge: String,
        /// OpenFlow rule in ovs-ofctl format
        rule: String,
    },

    /// Remove a specific flow rule from a bridge
    ///
    /// Removes flow rules matching the specified criteria. Uses ovs-ofctl
    /// del-flows syntax to match and remove flows.
    ///
    /// Examples:
    ///   # Remove flows matching specific priority
    ///   openflow-dbus remove-flow ovsbr0 "priority=200"
    ///
    ///   # Remove flows from specific input port
    ///   openflow-dbus remove-flow ovsbr0 "in_port=1"
    ///
    ///   # Remove all ICMP flows
    ///   openflow-dbus remove-flow ovsbr1 "icmp"
    ///
    /// Equivalent D-Bus call:
    ///   busctl call org.freedesktop.opdbus \
    ///     /org/freedesktop/opdbus/network/openflow \
    ///     org.freedesktop.opdbus.Network.OpenFlow \
    ///     RemoveFlowRule ss "ovsbr0" "priority=200"
    RemoveFlow {
        /// Name of the OVS bridge
        bridge: String,
        /// Flow match specification
        spec: String,
    },

    /// Show all OpenFlow rules for a bridge
    ///
    /// Displays all currently configured OpenFlow rules on the specified
    /// bridge. Output is similar to 'ovs-ofctl dump-flows' but formatted
    /// for better readability.
    ///
    /// Examples:
    ///   # Show flows on ovsbr0
    ///   openflow-dbus show-flows ovsbr0
    ///
    ///   # Show flows on ovsbr1
    ///   openflow-dbus show-flows ovsbr1
    ///
    ///   # Show with verbose details
    ///   openflow-dbus -v show-flows ovsbr0
    ///
    /// Equivalent D-Bus call:
    ///   busctl call org.freedesktop.opdbus \
    ///     /org/freedesktop/opdbus/network/openflow \
    ///     org.freedesktop.opdbus.Network.OpenFlow \
    ///     DumpFlows s "ovsbr0"
    ShowFlows {
        /// Name of the OVS bridge
        bridge: String,
    },

    /// Clear all OpenFlow rules from a bridge
    ///
    /// Removes all flow rules from the specified bridge. Use with caution
    /// as this will delete ALL flows including the default normal forwarding
    /// rule, which may break connectivity.
    ///
    /// Examples:
    ///   # Clear all flows from ovsbr0
    ///   openflow-dbus clear-flows ovsbr0
    ///
    ///   # Clear and then reapply defaults
    ///   openflow-dbus clear-flows ovsbr0 && openflow-dbus apply-defaults ovsbr0
    ///
    /// Equivalent D-Bus call:
    ///   busctl call org.freedesktop.opdbus \
    ///     /org/freedesktop/opdbus/network/openflow \
    ///     org.freedesktop.opdbus.Network.OpenFlow \
    ///     ClearFlows s "ovsbr0"
    ClearFlows {
        /// Name of the OVS bridge
        bridge: String,
    },

    /// List all configured bridges
    ///
    /// Shows all bridges configured in the state.json file, including
    /// their type, addressing, and OpenFlow configuration status.
    ///
    /// Examples:
    ///   # List all bridges
    ///   openflow-dbus list-bridges
    ///
    ///   # List with verbose details
    ///   openflow-dbus -v list-bridges
    ///
    /// Equivalent D-Bus call:
    ///   busctl call org.freedesktop.opdbus \
    ///     /org/freedesktop/opdbus/network/openflow \
    ///     org.freedesktop.opdbus.Network.OpenFlow \
    ///     ListBridges
    ListBridges,

    /// Show configuration for a specific bridge
    ///
    /// Displays the complete configuration for a bridge in JSON format,
    /// including network settings, OpenFlow rules, and other options.
    ///
    /// Examples:
    ///   # Show ovsbr0 configuration
    ///   openflow-dbus show-config ovsbr0
    ///
    ///   # Show ovsbr1 configuration with pretty print
    ///   openflow-dbus show-config ovsbr1 | jq
    ///
    /// Equivalent D-Bus call:
    ///   busctl call org.freedesktop.opdbus \
    ///     /org/freedesktop/opdbus/network/openflow \
    ///     org.freedesktop.opdbus.Network.OpenFlow \
    ///     GetBridgeConfig s "ovsbr0"
    ShowConfig {
        /// Name of the OVS bridge
        bridge: String,
    },

    /// Test connectivity to D-Bus service
    ///
    /// Tests whether the OpenFlow D-Bus service is running and responsive.
    /// Useful for troubleshooting and service health checks.
    ///
    /// Examples:
    ///   # Test D-Bus connectivity
    ///   openflow-dbus test-dbus
    ///
    ///   # Test and show verbose details
    ///   openflow-dbus -v test-dbus
    ///
    /// Equivalent D-Bus call:
    ///   busctl status org.freedesktop.opdbus
    TestDbus,

    /// Show comprehensive usage examples
    ///
    /// Displays detailed examples for common use cases and scenarios.
    Examples,
}

pub fn print_examples() {
    println!("{}", "\n=== OpenFlow D-Bus Manager - Usage Examples ===\n".bold().cyan());

    println!("{}", "1. Starting the D-Bus Service".bold().yellow());
    println!("   {}", "openflow-dbus daemon".green());
    println!("   {}", "# Starts the background service that handles D-Bus requests\n".dimmed());

    println!("{}", "2. Basic Bridge Management".bold().yellow());
    println!("   {}", "# List all configured bridges".dimmed());
    println!("   {}", "openflow-dbus list-bridges\n".green());

    println!("   {}", "# Show configuration for a specific bridge".dimmed());
    println!("   {}", "openflow-dbus show-config ovsbr0\n".green());

    println!("{}", "3. Applying Default Rules".bold().yellow());
    println!("   {}", "# Apply default anti-broadcast/multicast rules to one bridge".dimmed());
    println!("   {}", "openflow-dbus apply-defaults ovsbr0\n".green());

    println!("   {}", "# Apply default rules to all configured bridges".dimmed());
    println!("   {}", "openflow-dbus apply-all\n".green());

    println!("{}", "4. Managing Custom Flow Rules".bold().yellow());
    println!("   {}", "# Add a rule to drop traffic from port 1".dimmed());
    println!("   {}", "openflow-dbus add-flow ovsbr0 \"priority=200,in_port=1,actions=drop\"\n".green());

    println!("   {}", "# Add a rule to allow SSH traffic with high priority".dimmed());
    println!("   {}", "openflow-dbus add-flow ovsbr0 \"priority=150,tcp,tp_dst=22,actions=NORMAL\"\n".green());

    println!("   {}", "# Add rule to drop all broadcast packets".dimmed());
    println!("   {}", "openflow-dbus add-flow ovsbr0 \"priority=100,dl_dst=ff:ff:ff:ff:ff:ff,actions=drop\"\n".green());

    println!("{}", "5. Viewing Flow Rules".bold().yellow());
    println!("   {}", "# Show all flows on a bridge".dimmed());
    println!("   {}", "openflow-dbus show-flows ovsbr0\n".green());

    println!("   {}", "# Show flows with verbose output".dimmed());
    println!("   {}", "openflow-dbus -v show-flows ovsbr0\n".green());

    println!("{}", "6. Removing Flow Rules".bold().yellow());
    println!("   {}", "# Remove flows matching specific priority".dimmed());
    println!("   {}", "openflow-dbus remove-flow ovsbr0 \"priority=200\"\n".green());

    println!("   {}", "# Remove all ICMP flows".dimmed());
    println!("   {}", "openflow-dbus remove-flow ovsbr0 \"icmp\"\n".green());

    println!("   {}", "# Clear ALL flows (use with caution!)".dimmed());
    println!("   {}", "openflow-dbus clear-flows ovsbr0\n".green());

    println!("{}", "7. Using with systemd".bold().yellow());
    println!("   {}", "# Start service at boot".dimmed());
    println!("   {}", "sudo systemctl enable --now openflow-dbus.service\n".green());

    println!("   {}", "# Check service status".dimmed());
    println!("   {}", "sudo systemctl status openflow-dbus.service\n".green());

    println!("   {}", "# View service logs".dimmed());
    println!("   {}", "sudo journalctl -u openflow-dbus.service -f\n".green());

    println!("{}", "8. Direct D-Bus Usage".bold().yellow());
    println!("   {}", "# Call via busctl".dimmed());
    println!("   {}", "busctl call org.freedesktop.opdbus \\".green());
    println!("   {}", "  /org/freedesktop/opdbus/network/openflow \\".green());
    println!("   {}", "  org.freedesktop.opdbus.Network.OpenFlow \\".green());
    println!("   {}", "  ApplyDefaultRules s \"ovsbr0\"\n".green());

    println!("{}", "9. JSON-RPC via dbus-mcp".bold().yellow());
    println!("   {}", "curl -X POST http://localhost:8096/jsonrpc \\".green());
    println!("   {}", "  -H \"Content-Type: application/json\" \\".green());
    println!("   {}", "  -d '{{".green());
    println!("   {}", "    \"jsonrpc\": \"2.0\",".green());
    println!("   {}", "    \"method\": \"openflow.apply_default_rules\",".green());
    println!("   {}", "    \"params\": {{\"bridge\": \"ovsbr0\"}},".green());
    println!("   {}", "    \"id\": 1".green());
    println!("   {}", "  }}'\n".green());

    println!("{}", "10. Common Workflows".bold().yellow());
    println!("   {}", "# Reset bridge to defaults".dimmed());
    println!("   {}", "openflow-dbus clear-flows ovsbr0 && \\".green());
    println!("   {}", "openflow-dbus apply-defaults ovsbr0\n".green());

    println!("   {}", "# Add custom rule and verify".dimmed());
    println!("   {}", "openflow-dbus add-flow ovsbr0 \"priority=150,tcp,tp_dst=22,actions=NORMAL\" && \\".green());
    println!("   {}", "openflow-dbus show-flows ovsbr0\n".green());

    println!("{}", "For more information, see:".bold().white());
    println!("  - {}", "openflow-dbus --help".cyan());
    println!("  - {}", "openflow-dbus <command> --help".cyan());
    println!("  - {}", "/home/user/ghostbridge-nixos/OPENFLOW-DBUS-SPEC.md".cyan());
    println!();
}
