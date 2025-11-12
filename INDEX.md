# GhostBridge NixOS Configuration - Complete Index

**Production-ready NixOS configuration for GhostBridge infrastructure system**

Version: 1.0  
Created: November 2024  
Based on: Comprehensive requirements from all conversation history

---

## 📋 Table of Contents

1. [Quick Start](#quick-start)
2. [File Structure](#file-structure)
3. [Configuration Files](#configuration-files)
4. [Module Documentation](#module-documentation)
5. [Scripts](#scripts)
6. [Documentation](#documentation)
7. [Installation Workflow](#installation-workflow)
8. [Post-Installation](#post-installation)
9. [Troubleshooting](#troubleshooting)

---

## Quick Start

### For First-Time Installation

1. **Read first**: [INSTALL.md](./INSTALL.md)
2. **Follow checklist**: [DEPLOYMENT-CHECKLIST.md](./DEPLOYMENT-CHECKLIST.md)
3. **Keep handy**: [QUICK-REFERENCE.md](./QUICK-REFERENCE.md)

### For Configuration Updates

```bash
cd /etc/nixos
sudo vim configuration.nix
sudo nixos-rebuild switch --flake .#ghostbridge
```

---

## File Structure

```
nix/ghostbridge/
├── Core Configuration
│   ├── flake.nix                      # Flake entry point
│   ├── configuration.nix              # Main system config
│   └── hardware-configuration.nix     # Hardware detection
│
├── Modules (modular functionality)
│   ├── ghostbridge-ovs.nix           # OVS network setup
│   ├── blockchain-storage.nix        # BTRFS + blockchain
│   ├── dbus-orchestrator.nix         # D-Bus services
│   ├── virtualization.nix            # KVM/LXC/Docker
│   └── scripts/
│       ├── btrfs-snapshot.sh         # Snapshot service
│       └── btrfs-vector-sync.sh      # Qdrant sync
│
└── Documentation
    ├── INDEX.md                       # This file
    ├── README.md                      # System overview
    ├── INSTALL.md                     # Installation guide
    ├── DEPLOYMENT-CHECKLIST.md        # Verification checklist
    ├── QUICK-REFERENCE.md             # Common commands
    └── SUMMARY.md                     # Feature summary
```

---

## Configuration Files

### flake.nix
**Purpose**: Modern NixOS flake entry point  
**Key Features**:
- Defines `nixosConfigurations.ghostbridge`
- Imports all modules
- Provides unstable packages overlay

**When to edit**: 
- Adding new input sources
- Changing NixOS version
- Adding system modules

### configuration.nix
**Purpose**: Main system configuration  
**Key Features**:
- Boot configuration (systemd-boot)
- Kernel parameters and modules
- Network settings (systemd-networkd)
- User accounts
- System packages
- Services (SSH, Prometheus, Grafana)
- Nix settings (flakes, GC)

**When to edit**:
- Adding users
- Changing SSH keys
- Adding system packages
- Adjusting firewall rules
- Changing timezone/locale

**Line count**: 155 lines

### hardware-configuration.nix
**Purpose**: Hardware detection and filesystem mounts  
**Key Features**:
- BTRFS subvolume definitions
- Mount options for each subvolume
- EFI boot partition
- Kernel modules

**When to edit**:
- After `nixos-generate-config`
- Changing disk layout
- Adjusting BTRFS mount options

**Line count**: 67 lines

---

## Module Documentation

### modules/ghostbridge-ovs.nix
**Purpose**: Open vSwitch network configuration
**Manages**:
- OVS bridge creation (ovsbr0, ovsbr1)
- systemd-networkd configuration
- Hardware offload disabling (CRITICAL)
- Network diagnostics

**Services created**:
- `ovs-bridge-setup.service` - Creates OVS bridges

**Files created**:
- `/etc/ghostbridge/ovs-status.sh` - Diagnostic script

**Line count**: 103 lines

**Critical**: Hardware offload MUST be disabled to prevent Hetzner shutdowns

### modules/blockchain-storage.nix
**Purpose**: BTRFS snapshot and blockchain storage  
**Manages**:
- BTRFS snapshot service
- Blockchain timing database
- Qdrant vector database
- Vector sync service

**Services created**:
- `btrfs-snapshot.service` - Creates snapshots every 1 second
- `btrfs-vector-sync.service` - Syncs to Qdrant every 1 second
- `qdrant.service` - Vector database server
- `blockchain-timing-db.service` - SQLite initialization

**Files created**:
- `/etc/qdrant/config.yaml` - Qdrant configuration
- `/etc/ghostbridge/query-blockchain.sh` - Query script

**Line count**: 139 lines

### modules/dbus-orchestrator.nix
**Purpose**: D-Bus service configuration  
**Manages**:
- op-dbus daemon
- MCP server
- MCP web interface
- D-Bus policy

**Services created**:
- `op-dbus.service` - Main orchestrator daemon
- `dbus-mcp-server.service` - MCP server
- `dbus-mcp-web.service` - Web interface

**Files created**:
- `/etc/dbus-1/system.d/org.freedesktop.opdbus.conf` - D-Bus policy
- `/etc/op-dbus/state.json` - Configuration template
- `/etc/ghostbridge/test-dbus.sh` - Test script

**Line count**: 105 lines

**Note**: Requires op-dbus binaries to be built and installed separately

### modules/virtualization.nix
**Purpose**: Virtualization stack (KVM/LXC/Docker)  
**Manages**:
- libvirt/QEMU
- LXC/LXD
- Docker
- OVS network integration for VMs
- NoVNC console

**Services created**:
- `libvirt-ovs-network.service` - Configures libvirt networks
- `novnc-server.service` - Web console on port 6080

**Line count**: 101 lines

---

## Scripts

### modules/scripts/ovs-flow-rules.sh
**Purpose**: Apply OpenFlow rules to OVS bridges  
**Functionality**:
- Drops broadcast packets (ff:ff:ff:ff:ff:ff)
- Drops multicast packets (01:00:00:00:00:00/...)
- Allows normal forwarding for everything else

**Called by**: `ovs-flow-rules.service`  
**Line count**: 26 lines  
**Critical**: Prevents malformed DPU packets

### modules/scripts/btrfs-snapshot.sh
**Purpose**: Create BTRFS snapshots every 1 second  
**Functionality**:
- Creates read-only snapshots
- Calculates SHA-256 blockchain hash
- Links to previous snapshot
- Stores events in SQLite
- Auto-deletes snapshots older than 1 minute

**Called by**: `btrfs-snapshot.service`  
**Line count**: 60 lines

### modules/scripts/btrfs-vector-sync.sh
**Purpose**: Sync blockchain events to Qdrant  
**Functionality**:
- Queries SQLite for new events
- Creates vector embeddings
- Uploads to Qdrant
- Batch processing (100 events/iteration)

**Called by**: `btrfs-vector-sync.service`  
**Line count**: 84 lines

---

## Documentation

### README.md
**Audience**: System administrators  
**Content**:
- Architecture overview
- File structure
- Quick start guide
- Troubleshooting
- Monitoring endpoints

**When to read**: Before deployment, for system overview

### INSTALL.md
**Audience**: Deploying engineers  
**Content**:
- Step-by-step installation
- Disk partitioning
- BTRFS setup
- Configuration copying
- Post-installation verification
- Hetzner-specific instructions

**When to read**: During installation process

### DEPLOYMENT-CHECKLIST.md
**Audience**: Deployment team  
**Content**:
- Pre-deployment checks
- Installation verification
- Service validation
- Functionality tests
- Security hardening
- Final validation

**When to use**: During and after deployment

### QUICK-REFERENCE.md
**Audience**: Day-to-day operators  
**Content**:
- Common commands
- Service management
- Troubleshooting steps
- Monitoring commands

**When to use**: Daily operations, troubleshooting

### SUMMARY.md
**Audience**: Technical decision makers  
**Content**:
- Complete feature list
- Line counts
- Critical success factors
- Deployment time estimates

**When to read**: For project overview, planning

---

## Installation Workflow

```
┌─────────────────────────────────────┐
│ 1. Boot NixOS Installer             │
└──────────────┬──────────────────────┘
               │
               ▼
┌─────────────────────────────────────┐
│ 2. Partition Disks                  │
│    - EFI: 512MB (ef00)              │
│    - BTRFS: Remainder (8300)        │
└──────────────┬──────────────────────┘
               │
               ▼
┌─────────────────────────────────────┐
│ 3. Format & Create Subvolumes       │
│    - @, @home, @overlay             │
│    - @blockchain-timing             │
│    - @blockchain-vectors, @work     │
└──────────────┬──────────────────────┘
               │
               ▼
┌─────────────────────────────────────┐
│ 4. Mount Filesystem Hierarchy       │
│    - Root with correct options      │
│    - All subvolumes mounted         │
│    - Boot partition mounted         │
└──────────────┬──────────────────────┘
               │
               ▼
┌─────────────────────────────────────┐
│ 5. Copy Configuration Files         │
│    - Copy all .nix files            │
│    - Copy modules/                  │
│    - Make scripts executable        │
└──────────────┬──────────────────────┘
               │
               ▼
┌─────────────────────────────────────┐
│ 6. Customize Configuration          │
│    - Add SSH keys                   │
│    - Adjust hostname, firewall      │
└──────────────┬──────────────────────┘
               │
               ▼
┌─────────────────────────────────────┐
│ 7. nixos-install                    │
│    (15-30 minutes)                  │
└──────────────┬──────────────────────┘
               │
               ▼
┌─────────────────────────────────────┐
│ 8. First Boot & Verification        │
│    - OVS bridges check              │
│    - Services check                 │
└──────────────┬──────────────────────┘
               │
               ▼
┌─────────────────────────────────────┐
│ 9. Build & Install op-dbus          │
│    - cargo build                    │
│    - Copy binaries                  │
│    - Restart services               │
└──────────────┬──────────────────────┘
               │
               ▼
┌─────────────────────────────────────┐
│ 10. Final Testing                   │
│     - All services running          │
│     - Network functional            │
│     - Blockchain recording          │
│     - Ready for production!         │
└─────────────────────────────────────┘
```

---

## Post-Installation

### Immediately After Install

1. **Verify OVS bridges**: `/etc/ghostbridge/ovs-status.sh`
2. **Check services**: `systemctl --failed`
3. **Test network**: `ping 8.8.8.8`
4. **Check BTRFS**: `btrfs subvolume list /`

### Within First Hour

1. **Build op-dbus**: `cargo build --release --all-features`
2. **Install binaries**: Copy to `/usr/local/bin/`
3. **Restart D-Bus services**: `systemctl restart op-dbus`
4. **Test D-Bus**: `/etc/ghostbridge/test-dbus.sh`

### Within First Day

1. **Deploy first VM**: Test OVS bridge connectivity
2. **Configure monitoring**: Set up Grafana dashboards
3. **Test backups**: Verify BTRFS send/receive
4. **Document customizations**: Update configuration notes

### Ongoing

- **Daily**: Check `/etc/ghostbridge/*.sh` diagnostic scripts
- **Weekly**: Review service logs
- **Monthly**: Review and clean old generations
- **Quarterly**: Update NixOS packages

---

## Troubleshooting

### Quick Diagnostics

```bash
# Run all diagnostic scripts
/etc/ghostbridge/ovs-status.sh
/etc/ghostbridge/test-dbus.sh
/etc/ghostbridge/query-blockchain.sh

# Check all service statuses
systemctl --failed
systemctl status ovs-bridge-setup.service
systemctl status btrfs-snapshot.service
systemctl status qdrant.service
```

### Common Issues

| Issue | Diagnostic | Solution |
|-------|-----------|----------|
| OVS bridges not up | `ovs-vsctl show` | `systemctl restart ovs-bridge-setup` |
| No internet | `networkctl status` | `systemctl restart systemd-networkd` |
| Snapshots failing | `journalctl -u btrfs-snapshot -f` | Check disk space |
| Qdrant not syncing | `curl localhost:6333/collections` | `systemctl restart qdrant` |
| D-Bus services failing | `busctl list` | Install op-dbus binaries |

### Emergency Procedures

**System Won't Boot**:
1. Boot from previous generation (systemd-boot menu)
2. Or rollback: `nixos-rebuild switch --rollback`

**Network Completely Down**:
1. Switch to console: Ctrl+Alt+F1
2. Restart services: `systemctl restart openvswitch systemd-networkd`
3. Check logs: `journalctl -xe`

**Disk Full**:
1. Delete old snapshots: `find /var/lib/blockchain-timing/snapshots -mmin +5 -delete`
2. Clean Nix store: `nix-collect-garbage -d`
3. Check BTRFS usage: `btrfs filesystem usage /`

---

## Support Resources

### Documentation Files
- **System Overview**: [README.md](./README.md)
- **Installation**: [INSTALL.md](./INSTALL.md)
- **Checklist**: [DEPLOYMENT-CHECKLIST.md](./DEPLOYMENT-CHECKLIST.md)
- **Commands**: [QUICK-REFERENCE.md](./QUICK-REFERENCE.md)
- **Features**: [SUMMARY.md](./SUMMARY.md)

### Online Resources
- NixOS Manual: https://nixos.org/manual/nixos/stable/
- Open vSwitch: https://www.openvswitch.org/
- BTRFS Wiki: https://btrfs.wiki.kernel.org/
- Qdrant Docs: https://qdrant.tech/documentation/

### Diagnostic Scripts
- `/etc/ghostbridge/ovs-status.sh` - Network status
- `/etc/ghostbridge/test-dbus.sh` - D-Bus services
- `/etc/ghostbridge/query-blockchain.sh` - Blockchain events

---

## Version History

**v1.0 - November 2024**
- Initial production-ready release
- Complete NixOS configuration
- All modules implemented
- Full documentation suite

---

**Complete NixOS configuration for GhostBridge infrastructure system - Ready for production deployment!**
