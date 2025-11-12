#!/usr/bin/env bash

set -euo pipefail

echo "Applying OpenFlow rules to OVS bridges..."

for bridge in ovsbr0 ovsbr1; do
    echo "Configuring $bridge..."
    
    ovs-ofctl del-flows $bridge || true
    
    ovs-ofctl add-flow $bridge "priority=100,dl_dst=ff:ff:ff:ff:ff:ff,actions=drop"
    
    ovs-ofctl add-flow $bridge "priority=100,dl_dst=01:00:00:00:00:00/01:00:00:00:00:00,actions=drop"
    
    ovs-ofctl add-flow $bridge "priority=50,actions=normal"
    
    echo "$bridge configured with anti-broadcast rules"
done

echo "OpenFlow rules applied successfully"

echo ""
echo "Current flow rules:"
ovs-ofctl dump-flows ovsbr0
echo ""
ovs-ofctl dump-flows ovsbr1
