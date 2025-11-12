# GhostBridge Quick Reference

Common commands and operations for managing your GhostBridge NixOS system.

## System Management

### Rebuild System Configuration

```bash
# Test configuration without activating
sudo nixos-rebuild test --flake /etc/nixos#ghostbridge

# Build and activate immediately
sudo nixos-rebuild switch --flake /etc/nixos#ghostbridge

# Build for next boot (activate after reboot)
sudo nixos-rebuild boot --flake /etc/nixos#ghostbridge

# Rollback to previous generation
sudo nixos-rebuild switch --rollback --flake /etc/nixos#ghostbridge
```

### List System Generations

```bash
# List all generations
sudo nix-env --list-generations --profile /nix/var/nix/profiles/system

# Delete old generations
sudo nix-collect-garbage --delete-older-than 30d

# Delete all old generations
sudo nix-collect-garbage -d
```

### Boot Manager

```bash
# systemd-boot menu shows generations at boot
# Press space during boot to see menu
# Or hold Shift during boot

# Manually set default boot entry
sudo bootctl set-default <generation>.conf
```

## Network Management

### Check OVS Bridges

```bash
# Quick status
/etc/ghostbridge/ovs-status.sh

# Show OVS configuration
sudo ovs-vsctl show

# Show bridge ports
sudo ovs-vsctl list-ports ovsbr0
sudo ovs-vsctl list-ports ovsbr1

# Show network interfaces
ip addr show
ip link show
```

### Restart OVS Bridges

```bash
# Restart OVS service
sudo systemctl restart openvswitch.service

# Recreate bridges
sudo systemctl restart ovs-bridge-setup.service

# Restart networkd
sudo systemctl restart systemd-networkd.service
```

### Check Network Connectivity

```bash
# Show systemd-networkd status
networkctl status

# Show specific interface
networkctl status ovsbr0-if

# Test internet connectivity
ping -c 3 8.8.8.8

# Test DNS
nslookup google.com
```

## BTRFS Operations

### Check Subvolumes

```bash
# List all subvolumes
sudo btrfs subvolume list /

# Show subvolume info
sudo btrfs subvolume show /var/lib/blockchain-timing

# Check disk usage
sudo btrfs filesystem usage /
sudo btrfs filesystem usage /var/lib/blockchain-timing
```

### Manage Snapshots

```bash
# List snapshots
ls -la /var/lib/blockchain-timing/snapshots/

# Check snapshot service
sudo systemctl status btrfs-snapshot.service
sudo journalctl -u btrfs-snapshot.service -f

# Manually create snapshot
sudo btrfs subvolume snapshot -r /var/lib/blockchain-timing /var/lib/blockchain-timing/snapshots/manual_$(date +%s%N)

# Delete old snapshot
sudo btrfs subvolume delete /var/lib/blockchain-timing/snapshots/snapshot_*
```

### Check BTRFS Health

```bash
# Check filesystem
sudo btrfs check --readonly /dev/nvme1n1p2

# Show device stats
sudo btrfs device stats /

# Scrub filesystem (check for errors)
sudo btrfs scrub start /
sudo btrfs scrub status /
```

## Blockchain Storage

### Query Blockchain Database

```bash
# Quick query
/etc/ghostbridge/query-blockchain.sh

# Direct SQLite access
sudo sqlite3 /var/lib/blockchain-timing/events.db "SELECT * FROM events ORDER BY id DESC LIMIT 10;"

# Count events
sudo sqlite3 /var/lib/blockchain-timing/events.db "SELECT COUNT(*) FROM events;"

# Events by type
sudo sqlite3 /var/lib/blockchain-timing/events.db "SELECT event_type, COUNT(*) FROM events GROUP BY event_type;"
```

### Qdrant Operations

```bash
# Check Qdrant service
sudo systemctl status qdrant.service

# Check collection
curl http://localhost:6333/collections/blockchain_events

# Count vectors
curl http://localhost:6333/collections/blockchain_events

# Search vectors
curl -X POST http://localhost:6333/collections/blockchain_events/points/search \
  -H 'Content-Type: application/json' \
  -d '{"vector": [0,1,2,...], "limit": 5}'

# Access Qdrant dashboard
xdg-open http://localhost:6333/dashboard
```

### Vector Sync

```bash
# Check sync service
sudo systemctl status btrfs-vector-sync.service
sudo journalctl -u btrfs-vector-sync.service -f

# Manually trigger sync (restart service)
sudo systemctl restart btrfs-vector-sync.service
```

## D-Bus Operations

### Check D-Bus Services

```bash
# Quick check
/etc/ghostbridge/test-dbus.sh

# List D-Bus services
busctl list | grep -E "(network|opdbus)"

# Show service details
busctl status org.freedesktop.network1
busctl status org.freedesktop.opdbus

# Introspect service
busctl introspect org.freedesktop.network1 /org/freedesktop/network1
```

### op-dbus Management

```bash
# Check services
sudo systemctl status op-dbus.service
sudo systemctl status dbus-mcp-server.service
sudo systemctl status dbus-mcp-web.service

# View logs
sudo journalctl -u op-dbus.service -f
sudo journalctl -u dbus-mcp-server.service -f
sudo journalctl -u dbus-mcp-web.service -f

# Restart services
sudo systemctl restart op-dbus.service
sudo systemctl restart dbus-mcp-server.service
sudo systemctl restart dbus-mcp-web.service
```

## Virtualization

### KVM/libvirt

```bash
# List VMs
virsh list --all

# List networks
virsh net-list --all

# Show OVS networks
virsh net-info ovsbr0
virsh net-info ovsbr1

# Start VM
virsh start <vm-name>

# Connect to VM console
virsh console <vm-name>

# Access NoVNC
xdg-open http://localhost:6080
```

### Docker

```bash
# List containers
docker ps -a

# Check Docker service
sudo systemctl status docker.service

# View Docker logs
sudo journalctl -u docker.service -f

# Prune old images
docker system prune -a
```

### LXC/LXD

```bash
# List containers
lxc list

# Launch container
lxc launch ubuntu:22.04 test-container

# Execute command in container
lxc exec test-container -- bash

# Check LXD service
sudo systemctl status lxd.service
```

## Monitoring

### Check All Services

```bash
# List all services
systemctl list-units --type=service --state=running

# List failed services
systemctl list-units --failed

# Check specific service
sudo systemctl status <service-name>
```

### View Logs

```bash
# Follow system log
sudo journalctl -f

# Filter by service
sudo journalctl -u <service-name> -f

# Show errors only
sudo journalctl -p err -f

# Show logs since boot
sudo journalctl -b
```

### Prometheus & Grafana

```bash
# Access Prometheus
xdg-open http://localhost:9090

# Access Grafana
xdg-open http://localhost:3000

# Check exporters
curl http://localhost:9100/metrics  # node_exporter
```

## System Health

### Check Disk Space

```bash
# Overall disk usage
df -h

# BTRFS specific
sudo btrfs filesystem usage /
sudo btrfs filesystem df /
```

### Check Memory

```bash
# Quick memory stats
free -h

# Detailed memory
cat /proc/meminfo

# Top memory consumers
ps aux --sort=-%mem | head -n 10
```

### Check CPU

```bash
# CPU info
lscpu

# Load average
uptime

# Top CPU consumers
ps aux --sort=-%cpu | head -n 10
```

### Check Hardware

```bash
# PCI devices
lspci

# USB devices
lsusb

# Block devices
lsblk

# Hardware sensors
sensors
```

## Troubleshooting

### Emergency Console

```bash
# Switch to console
Ctrl+Alt+F1

# Switch back to GUI (if running)
Ctrl+Alt+F7
```

### Safe Mode Boot

```bash
# At systemd-boot menu, select generation
# Edit kernel parameters (press 'e')
# Add: systemd.unit=rescue.target
# Boot
```

### Diagnose Boot Issues

```bash
# Check boot messages
dmesg | less

# Check systemd analyze
systemd-analyze blame
systemd-analyze critical-chain

# Check failed units
systemctl --failed
```

### Network Troubleshooting

```bash
# Restart all network services
sudo systemctl restart openvswitch.service
sudo systemctl restart ovs-bridge-setup.service
sudo systemctl restart systemd-networkd.service

# Check for errors
sudo journalctl -u systemd-networkd.service -n 50
```

## Update System

### Update NixOS

```bash
# Update flake inputs
sudo nix flake update /etc/nixos

# Rebuild with updated packages
sudo nixos-rebuild switch --flake /etc/nixos#ghostbridge

# Update and upgrade (from unstable)
sudo nix-channel --update
sudo nixos-rebuild switch --upgrade --flake /etc/nixos#ghostbridge
```

## Backup & Restore

### Backup Configuration

```bash
# Backup /etc/nixos
sudo tar czf ~/nixos-backup-$(date +%Y%m%d).tar.gz /etc/nixos/

# Backup to remote
rsync -avz /etc/nixos/ user@backup-server:/backups/nixos/
```

### Backup BTRFS

```bash
# Send snapshot to file
sudo btrfs send /var/lib/blockchain-timing/snapshots/snapshot_* | gzip > blockchain-backup.gz

# Send to remote
sudo btrfs send /var/lib/blockchain-timing/snapshots/snapshot_* | ssh user@backup-server "cat > /backups/blockchain.btrfs"
```

## Performance Tuning

### Check BTRFS Compression

```bash
# Check compression ratio
sudo compsize /var/lib/blockchain-timing
```

### Optimize Nix Store

```bash
# Optimize Nix store (deduplicate)
sudo nix-store --optimise

# Verify Nix store
sudo nix-store --verify --check-contents
```

---

**Tip**: Add commonly used commands to your `.bashrc` as aliases!
