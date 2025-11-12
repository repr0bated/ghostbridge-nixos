# GhostBridge Complete NixOS Configuration

Production-ready NixOS configuration for the GhostBridge infrastructure system, featuring:

- **GhostBridge**: Privacy router with OVS bridge network isolation
- **Immutable Audit Trail**: Blockchain-based logging with vector database integration  
- **MCP D-Bus Orchestrator**: AI-powered Linux system management

## Architecture

### Network (OVS Bridges)
- **ovsbr0**: Internet-facing bridge connected to physical NIC (ens1)
- **ovsbr1**: Internal network bridge (10.0.1.0/24)
- Hardware offload disabled to prevent DPU packet issues

### Storage (BTRFS)
- **@**: Root filesystem (zstd:3 compression)
- **@home**: User home directories
- **@overlay**: 140GB consolidated backups from previous systems
- **@blockchain-timing**: Immutable blockchain event storage (zstd:9)
- **@blockchain-vectors**: Qdrant vector database storage
- **@work**: High-performance ephemeral workspace (nodatacow)

### Services
- **btrfs-snapshot**: Creates read-only snapshots every 1 second
- **btrfs-vector-sync**: Syncs blockchain events to Qdrant every 1 second
- **qdrant**: Vector database for semantic search of infrastructure events
- **op-dbus**: D-Bus orchestration daemon
- **dbus-mcp-server**: MCP server exposing D-Bus APIs
- **dbus-mcp-web**: Web interface on port 8096

### Virtualization
- **KVM/QEMU**: Virtual machine support with OVS bridge integration
- **LXC/LXD**: Container runtime
- **Docker**: Container platform
- **NoVNC**: Web console on port 6080

## File Structure

```
nix/ghostbridge/
├── flake.nix                          # Flake entry point
├── configuration.nix                  # Main system configuration
├── hardware-configuration.nix         # Hardware detection template
├── modules/
│   ├── ghostbridge-ovs.nix           # OVS network setup
│   ├── blockchain-storage.nix        # BTRFS + blockchain + Qdrant
│   ├── dbus-orchestrator.nix         # D-Bus services
│   ├── virtualization.nix            # KVM/LXC/Docker
│   └── scripts/
│       ├── btrfs-snapshot.sh         # Snapshot orchestrator
│       └── btrfs-vector-sync.sh      # Qdrant sync
├── README.md                          # This file
└── INSTALL.md                         # Installation guide
```

## Quick Start

### 1. Partition Drives

```bash
# Create EFI boot partition (512MB)
gdisk /dev/nvme1n1
# n, 1, default, +512M, ef00

# Create main BTRFS partition (remainder)
# n, 2, default, default, 8300

# Write changes: w
```

### 2. Format and Create BTRFS Subvolumes

```bash
# Format EFI partition
mkfs.vfat -F32 -n BOOT /dev/nvme1n1p1

# Format BTRFS partition
mkfs.btrfs -L nixos /dev/nvme1n1p2

# Mount and create subvolumes
mount /dev/nvme1n1p2 /mnt
cd /mnt
btrfs subvolume create @
btrfs subvolume create @home
btrfs subvolume create @overlay
btrfs subvolume create @blockchain-timing
btrfs subvolume create @blockchain-vectors
btrfs subvolume create @work
cd /
umount /mnt
```

### 3. Mount Subvolumes

```bash
# Mount root
mount -o subvol=@,compress=zstd:3,noatime,space_cache=v2,ssd /dev/nvme1n1p2 /mnt

# Create mount points
mkdir -p /mnt/{home,overlay,boot,var/lib/blockchain-timing,var/lib/blockchain-vectors,work}

# Mount other subvolumes
mount -o subvol=@home,compress=zstd:3,noatime,space_cache=v2,ssd /dev/nvme1n1p2 /mnt/home
mount -o subvol=@overlay,compress=zstd:3,noatime,space_cache=v2,ssd /dev/nvme1n1p2 /mnt/overlay
mount -o subvol=@blockchain-timing,compress=zstd:9,noatime,space_cache=v2 /dev/nvme1n1p2 /mnt/var/lib/blockchain-timing
mount -o subvol=@blockchain-vectors,compress=zstd:3,noatime,space_cache=v2 /dev/nvme1n1p2 /mnt/var/lib/blockchain-vectors
mount -o subvol=@work,noatime,nodatacow,space_cache=v2,ssd /dev/nvme1n1p2 /mnt/work

# Mount boot
mount /dev/nvme1n1p1 /mnt/boot
```

### 4. Copy Configuration Files

```bash
# Copy all files to /mnt/etc/nixos/
mkdir -p /mnt/etc/nixos/modules/scripts
cp -r nix/ghostbridge/* /mnt/etc/nixos/

# Make scripts executable
chmod +x /mnt/etc/nixos/modules/scripts/*.sh
```

### 5. Install NixOS

```bash
# Install with flakes
nixos-install --flake /mnt/etc/nixos#ghostbridge

# Set root password when prompted
# Reboot
reboot
```

### 6. Post-Installation

```bash
# After reboot, verify OVS bridges
/etc/ghostbridge/ovs-status.sh

# Check D-Bus services
/etc/ghostbridge/test-dbus.sh

# Query blockchain events
/etc/ghostbridge/query-blockchain.sh

# Build op-dbus binaries
cd /path/to/operation-dbus
cargo build --release --all-features

# Install binaries
sudo cp target/release/op-dbus /usr/local/bin/
sudo cp target/release/dbus-mcp /usr/local/bin/
sudo cp target/release/dbus-mcp-web /usr/local/bin/

# Restart services
sudo systemctl restart op-dbus dbus-mcp-server dbus-mcp-web
```

## Configuration Updates

```bash
# Edit configuration
sudo vim /etc/nixos/configuration.nix

# Test configuration (doesn't activate)
sudo nixos-rebuild test --flake /etc/nixos#ghostbridge

# Build and activate
sudo nixos-rebuild switch --flake /etc/nixos#ghostbridge

# Or build for next boot
sudo nixos-rebuild boot --flake /etc/nixos#ghostbridge
```

## Monitoring

- **Prometheus**: http://localhost:9090
- **Grafana**: http://localhost:3000
- **NoVNC Console**: http://localhost:6080
- **MCP Web UI**: http://localhost:8096
- **Qdrant**: http://localhost:6333/dashboard

## Troubleshooting

### OVS Bridges Not Coming Up

```bash
# Check OVS service
sudo systemctl status openvswitch.service
sudo systemctl status ovs-bridge-setup.service

# Manually recreate bridges
sudo systemctl restart ovs-bridge-setup.service
```

### BTRFS Snapshots Not Working

```bash
# Check snapshot service
sudo systemctl status btrfs-snapshot.service
sudo journalctl -u btrfs-snapshot.service -f

# Check disk space
sudo btrfs filesystem usage /var/lib/blockchain-timing
```

### D-Bus Services Failing

```bash
# Check service status
sudo systemctl status op-dbus.service
sudo systemctl status dbus-mcp-server.service

# Check D-Bus configuration
busctl list | grep opdbus

# Test D-Bus introspection
busctl introspect org.freedesktop.opdbus /org/freedesktop/opdbus
```

## Critical Success Factors

✅ OVS bridges come up cleanly on boot  
✅ No malformed DPU packets (hardware offload disabled)  
✅ BTRFS snapshots run every 1 second without accumulation  
✅ Qdrant syncs every 1 second via BTRFS send/receive  
✅ D-Bus APIs accessible for orchestration  
✅ VMs/containers can connect to OVS bridges  
✅ Boot with systemd-boot (not GRUB)  
✅ Use Ed25519 SSH keys (not DSA)  
✅ systemd-networkd (not NetworkManager)  
✅ All configuration declarative in .nix files  

## License

See parent repository for license information.
