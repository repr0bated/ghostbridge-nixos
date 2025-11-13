#!/usr/bin/env bash
echo "=== OVS Status Check (D-Bus/JSON-RPC Management) ==="
echo ""

echo "OVS Service:"
systemctl status vswitchd.service --no-pager -l | head -10
echo ""

echo "OpenFlow D-Bus Service:"
systemctl status openflow-dbus.service --no-pager -l | head -10
echo ""

echo "OpenFlow Setup Service:"
systemctl status ovs-openflow-setup.service --no-pager -l | head -10
echo ""

echo "Network Interfaces:"
ip -br addr | grep -E "(ovsbr|ens1)"
echo ""

echo "=== D-Bus/JSON-RPC Management ==="
echo "Available commands (no ovs-ofctl/ovs-vsctl needed):"
echo ""

echo "• Apply default rules:"
echo "  busctl call org.freedesktop.opdbus /org/freedesktop/opdbus/network/openflow org.freedesktop.opdbus.Network.OpenFlow ApplyDefaultRules s ovsbr0"
echo ""

echo "• Add custom rule:"
echo "  busctl call org.freedesktop.opdbus /org/freedesktop/opdbus/network/openflow org.freedesktop.opdbus.Network.OpenFlow AddFlowRule ss ovsbr0 'priority=200,tcp,tp_dst=80,actions=DROP'"
echo ""

echo "• View current rules:"
echo "  busctl call org.freedesktop.opdbus /org/freedesktop/opdbus/network/openflow org.freedesktop.opdbus.Network.OpenFlow DumpFlows s ovsbr0"
echo ""

echo "• Clear all rules:"
echo "  busctl call org.freedesktop.opdbus /org/freedesktop/opdbus/network/openflow org.freedesktop.opdbus.Network.OpenFlow ClearFlows s ovsbr0"
echo ""

echo "=== JSON-RPC Interface ==="
echo "Available via dbus-mcp server on port 8096 for programmatic access"
echo ""

echo "=== Current Configuration ==="
echo "• OVS bridges: ovsbr0 (external), ovsbr1 (internal 10.0.1.1/24)"
echo "• OpenFlow: Managed via Rust D-Bus service (uses ovs-ofctl internally)"
echo "• SSH traffic: Prioritized (port 22) for Cursor remote access"
echo "• Broadcast/multicast: Blocked to prevent network noise"
echo ""
