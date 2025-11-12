# GhostBridge Deployment Checklist

Use this checklist to ensure successful deployment of the GhostBridge infrastructure system.

## Pre-Deployment

- [ ] Verify hardware requirements
  - [ ] Intel CPU with KVM support (`grep -E "vmx|svm" /proc/cpuinfo`)
  - [ ] At least 100GB NVMe storage
  - [ ] Single network interface available
  - [ ] UEFI boot support

- [ ] Prepare installation media
  - [ ] Download NixOS ISO (24.11 or later)
  - [ ] Create bootable USB or load ISO on dedicated server

- [ ] Backup existing data
  - [ ] Backup @overlay subvolume if migrating from existing system
  - [ ] Export existing VM/container configurations

## Disk Setup

- [ ] Partition disks correctly
  - [ ] EFI partition: 512MB, type ef00
  - [ ] BTRFS partition: Remainder, type 8300

- [ ] Create all BTRFS subvolumes
  - [ ] @
  - [ ] @home
  - [ ] @overlay
  - [ ] @blockchain-timing
  - [ ] @blockchain-vectors
  - [ ] @work

- [ ] Mount with correct options
  - [ ] Root: compress=zstd:3, noatime, space_cache=v2, ssd
  - [ ] Blockchain timing: compress=zstd:9 (maximum compression)
  - [ ] Work: nodatacow (database performance)

## Configuration

- [ ] Copy all NixOS configuration files
  - [ ] flake.nix
  - [ ] configuration.nix
  - [ ] hardware-configuration.nix
  - [ ] modules/*.nix (4 files)
  - [ ] modules/scripts/*.sh (3 files)

- [ ] Customize configuration
  - [ ] Add SSH public keys to users.users.jeremy
  - [ ] Update networking.hostName if needed
  - [ ] Adjust firewall ports for your use case
  - [ ] Configure timezone if not America/New_York

- [ ] Make scripts executable
  - [ ] chmod +x modules/scripts/*.sh

## Installation

- [ ] Run NixOS installation
  - [ ] `nixos-install --flake /mnt/etc/nixos#ghostbridge`
  - [ ] Set root password
  - [ ] Wait for installation to complete (~15-30 minutes)

- [ ] First boot
  - [ ] System boots with systemd-boot
  - [ ] No boot errors in systemd-boot menu
  - [ ] Can login as root or via SSH

## Post-Installation Verification

### Network

- [ ] Physical interface is up
  - [ ] `ip link show ens1` shows UP

- [ ] OVS bridges created
  - [ ] ovsbr0 exists and is UP
  - [ ] ovsbr1 exists and is UP
  - [ ] ens1 is attached to ovsbr0

- [ ] Network connectivity
  - [ ] ovsbr0-if has DHCP address (or static if configured)
  - [ ] ovsbr1-if has 10.0.1.1/24
  - [ ] Can ping external hosts (8.8.8.8)
  - [ ] Can resolve DNS (nslookup google.com)

### Storage

- [ ] All subvolumes mounted
  - [ ] `mount | grep btrfs` shows all 6 subvolumes
  - [ ] Correct mount options applied

- [ ] Directories created
  - [ ] /var/lib/blockchain-timing exists
  - [ ] /var/lib/blockchain-timing/snapshots exists
  - [ ] /var/lib/blockchain-timing/events.db exists
  - [ ] /var/lib/blockchain-vectors exists
  - [ ] /work exists

### Services

- [ ] Core services running
  - [ ] `systemctl status openvswitch.service` - Active
  - [ ] `systemctl status ovs-bridge-setup.service` - Active
  - [ ] `systemctl status ovs-flow-rules.service` - Active
  - [ ] `systemctl status systemd-networkd.service` - Active

- [ ] Blockchain services running
  - [ ] `systemctl status blockchain-timing-db.service` - Active
  - [ ] `systemctl status btrfs-snapshot.service` - Active
  - [ ] `systemctl status qdrant.service` - Active
  - [ ] `systemctl status btrfs-vector-sync.service` - Active

- [ ] D-Bus services (will fail until op-dbus binaries are installed)
  - [ ] op-dbus.service status checked
  - [ ] dbus-mcp-server.service status checked
  - [ ] dbus-mcp-web.service status checked

### Build and Install Binaries

- [ ] Clone operation-dbus repository
  - [ ] `git clone` successful
  - [ ] Repository accessible

- [ ] Build Rust binaries
  - [ ] `cargo build --release --all-features` successful
  - [ ] Binaries created in target/release/

- [ ] Install binaries
  - [ ] op-dbus copied to /usr/local/bin/
  - [ ] dbus-mcp copied to /usr/local/bin/
  - [ ] dbus-mcp-web copied to /usr/local/bin/
  - [ ] dbus-orchestrator copied to /usr/local/bin/
  - [ ] All binaries executable

- [ ] Restart D-Bus services
  - [ ] `systemctl restart op-dbus.service` - Active
  - [ ] `systemctl restart dbus-mcp-server.service` - Active
  - [ ] `systemctl restart dbus-mcp-web.service` - Active

### Functionality Tests

- [ ] OVS status script works
  - [ ] `/etc/ghostbridge/ovs-status.sh` runs without errors
  - [ ] Shows both bridges and flow rules

- [ ] D-Bus test script works
  - [ ] `/etc/ghostbridge/test-dbus.sh` runs without errors
  - [ ] Shows network1 D-Bus service

- [ ] Blockchain query works
  - [ ] `/etc/ghostbridge/query-blockchain.sh` runs without errors
  - [ ] Shows snapshot events in database

- [ ] Snapshots being created
  - [ ] `ls -la /var/lib/blockchain-timing/snapshots/` shows recent snapshots
  - [ ] Snapshots auto-deleted after 1 minute
  - [ ] No disk space issues

- [ ] Qdrant accessible
  - [ ] `curl http://localhost:6333/collections` returns JSON
  - [ ] blockchain_events collection exists
  - [ ] Events being synced to Qdrant

### Virtualization

- [ ] KVM available
  - [ ] `lsmod | grep kvm` shows kvm_intel loaded

- [ ] libvirt running
  - [ ] `systemctl status libvirtd.service` - Active
  - [ ] `virsh net-list --all` shows ovsbr0 and ovsbr1 networks

- [ ] Docker working
  - [ ] `docker ps` runs without errors
  - [ ] Can pull images

### Monitoring

- [ ] Web interfaces accessible
  - [ ] Prometheus: http://YOUR_IP:9090
  - [ ] Grafana: http://YOUR_IP:3000
  - [ ] NoVNC: http://YOUR_IP:6080
  - [ ] MCP Web: http://YOUR_IP:8096
  - [ ] Qdrant: http://YOUR_IP:6333/dashboard

- [ ] Metrics collecting
  - [ ] Prometheus showing node_exporter metrics
  - [ ] BTRFS metrics available
  - [ ] systemd metrics available

## Hetzner-Specific Checks

If deploying on Hetzner:

- [ ] Public IP assigned via DHCP
  - [ ] `ip addr show ovsbr0-if` shows public IP

- [ ] No malformed packets
  - [ ] Hardware offload disabled on ens1
  - [ ] `ethtool -k ens1 | grep offload` shows all "off"

- [ ] Server not flagged
  - [ ] No abuse notifications from Hetzner
  - [ ] Server still accessible after 24 hours

## Security

- [ ] SSH hardened
  - [ ] Root login disabled
  - [ ] Password authentication disabled
  - [ ] Only Ed25519 keys enabled

- [ ] Firewall configured
  - [ ] Only required ports open
  - [ ] OVS bridges trusted

- [ ] Services secured
  - [ ] D-Bus permissions configured
  - [ ] Services running as appropriate users

## Documentation

- [ ] Configuration backed up
  - [ ] /etc/nixos/ tarball created
  - [ ] Stored off-server

- [ ] Credentials documented
  - [ ] SSH keys stored securely
  - [ ] Service passwords (if any) in password manager

- [ ] Network diagram updated
  - [ ] IP addresses documented
  - [ ] Bridge topology documented

## Final Validation

- [ ] System stable for 1 hour
  - [ ] No service restarts
  - [ ] No OOM conditions
  - [ ] Disk space not filling

- [ ] Reboot test
  - [ ] `sudo reboot`
  - [ ] System comes back up
  - [ ] All services start automatically
  - [ ] Network connectivity restored
  - [ ] OVS bridges functional

- [ ] Load test
  - [ ] Create a VM using OVS bridge
  - [ ] VM has network connectivity
  - [ ] Can ping VM from host and vice versa

## Deployment Complete

✅ All checks passed - GhostBridge infrastructure is operational!

## Next Steps

- [ ] Configure automated backups
- [ ] Set up monitoring alerts
- [ ] Deploy production workloads
- [ ] Document custom configurations
- [ ] Schedule maintenance windows
