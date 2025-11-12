# GhostBridge NixOS Installation Guide

Complete installation guide for deploying GhostBridge on bare metal or Hetzner dedicated servers.

## Prerequisites

- NixOS installation media (USB or ISO)
- Intel CPU with KVM support
- NVMe storage (at least 100GB recommended)
- Network interface (will be configured as ens1)
- UEFI boot support

## Installation Steps

### Step 1: Boot NixOS Installer

Boot from NixOS installation media and connect to network:

```bash
# If using WiFi
sudo systemctl start wpa_supplicant
wpa_cli

# If using Ethernet (DHCP)
sudo systemctl start dhcpcd
```

### Step 2: Partition Disks

```bash
# Identify disk (usually nvme1n1)
lsblk

# Launch gdisk
gdisk /dev/nvme1n1

# Create EFI partition
Command: n
Partition number: 1
First sector: <default>
Last sector: +512M
Hex code: ef00

# Create main BTRFS partition
Command: n
Partition number: 2
First sector: <default>
Last sector: <default>
Hex code: 8300

# Write changes
Command: w
```

### Step 3: Format Partitions

```bash
# Format EFI partition
mkfs.vfat -F32 -n BOOT /dev/nvme1n1p1

# Format BTRFS partition
mkfs.btrfs -L nixos /dev/nvme1n1p2
```

### Step 4: Create BTRFS Subvolumes

```bash
# Mount root BTRFS volume
mount /dev/nvme1n1p2 /mnt

# Create subvolumes
btrfs subvolume create /mnt/@
btrfs subvolume create /mnt/@home
btrfs subvolume create /mnt/@overlay
btrfs subvolume create /mnt/@blockchain-timing
btrfs subvolume create /mnt/@blockchain-vectors
btrfs subvolume create /mnt/@work

# Unmount
umount /mnt
```

### Step 5: Mount Filesystem Hierarchy

```bash
# Mount root subvolume
mount -o subvol=@,compress=zstd:3,noatime,space_cache=v2,ssd,discard=async /dev/nvme1n1p2 /mnt

# Create mount points
mkdir -p /mnt/{home,overlay,boot,var/lib/blockchain-timing,var/lib/blockchain-vectors,work}

# Mount other subvolumes
mount -o subvol=@home,compress=zstd:3,noatime,space_cache=v2,ssd,discard=async /dev/nvme1n1p2 /mnt/home
mount -o subvol=@overlay,compress=zstd:3,noatime,space_cache=v2,ssd /dev/nvme1n1p2 /mnt/overlay
mount -o subvol=@blockchain-timing,compress=zstd:9,noatime,space_cache=v2 /dev/nvme1n1p2 /mnt/var/lib/blockchain-timing
mount -o subvol=@blockchain-vectors,compress=zstd:3,noatime,space_cache=v2 /dev/nvme1n1p2 /mnt/var/lib/blockchain-vectors
mount -o subvol=@work,noatime,nodatacow,space_cache=v2,ssd /dev/nvme1n1p2 /mnt/work

# Mount boot partition
mount /dev/nvme1n1p1 /mnt/boot
```

### Step 6: Copy Configuration Files

```bash
# If installing from another system, transfer files
# Option 1: Using git
cd /tmp
git clone https://github.com/yourusername/operation-dbus.git
cd operation-dbus

# Option 2: Using rsync over SSH
rsync -avz user@buildserver:/path/to/operation-dbus/nix/ghostbridge/ /tmp/ghostbridge/

# Copy to target
mkdir -p /mnt/etc/nixos/modules/scripts
cp -r /tmp/ghostbridge/* /mnt/etc/nixos/

# OR if building from local source
cp -r nix/ghostbridge/* /mnt/etc/nixos/

# Make scripts executable
chmod +x /mnt/etc/nixos/modules/scripts/*.sh
```

### Step 7: Generate Hardware Configuration

```bash
# Generate hardware-configuration.nix (optional - we already have one)
# This will detect your specific hardware
nixos-generate-config --root /mnt

# IMPORTANT: Our provided hardware-configuration.nix already has correct
# BTRFS mount options. Only regenerate if you need hardware-specific tweaks.
```

### Step 8: Customize Configuration

Edit `/mnt/etc/nixos/configuration.nix` to add your SSH keys:

```bash
nano /mnt/etc/nixos/configuration.nix

# Find this section:
users.users.jeremy = {
  openssh.authorizedKeys.keys = [
    # Add your SSH public key here
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAA... user@hostname"
  ];
};
```

### Step 9: Install NixOS

```bash
# Install using flakes
nixos-install --flake /mnt/etc/nixos#ghostbridge

# Set root password when prompted

# Installation will take 15-30 minutes depending on internet speed
```

### Step 10: First Boot

```bash
# Reboot into new system
reboot

# After reboot, login as root or jeremy (if you configured SSH keys)
```

### Step 11: Verify Installation

```bash
# Check OVS bridges
sudo /etc/ghostbridge/ovs-status.sh

# Expected output:
# - ovsbr0 with ens1 attached and ovsbr0-if with DHCP address
# - ovsbr1 with ovsbr1-if at 10.0.1.1/24

# Check BTRFS subvolumes
sudo btrfs subvolume list /

# Check services
sudo systemctl status ovs-bridge-setup.service
sudo systemctl status btrfs-snapshot.service
sudo systemctl status qdrant.service
```

### Step 12: Build and Install op-dbus

```bash
# Clone repository
cd ~
git clone https://github.com/yourusername/operation-dbus.git
cd operation-dbus

# Build all binaries
cargo build --release --all-features

# Install binaries
sudo cp target/release/op-dbus /usr/local/bin/
sudo cp target/release/dbus-mcp /usr/local/bin/
sudo cp target/release/dbus-mcp-web /usr/local/bin/
sudo cp target/release/dbus-orchestrator /usr/local/bin/

# Restart services
sudo systemctl restart op-dbus.service
sudo systemctl restart dbus-mcp-server.service
sudo systemctl restart dbus-mcp-web.service

# Check status
sudo systemctl status op-dbus.service
```

### Step 13: Test System

```bash
# Test D-Bus
sudo /etc/ghostbridge/test-dbus.sh

# Test blockchain
sudo /etc/ghostbridge/query-blockchain.sh

# Access web interfaces
# - Grafana: http://YOUR_IP:3000
# - Prometheus: http://YOUR_IP:9090
# - NoVNC: http://YOUR_IP:6080
# - MCP Web: http://YOUR_IP:8096
# - Qdrant: http://YOUR_IP:6333/dashboard
```

## Hetzner-Specific Configuration

If deploying on Hetzner dedicated server:

### Network Configuration

Hetzner assigns a single public IP via DHCP. The OVS bridge configuration automatically handles this:

```bash
# Verify you received IP from Hetzner
ip addr show ovsbr0-if

# Should show DHCP-assigned public IP
```

### Firewall Rules

Update firewall ports in `/etc/nixos/configuration.nix`:

```nix
networking.firewall = {
  allowedTCPPorts = [ 
    22     # SSH
    6080   # NoVNC
    8096   # MCP Web
    3000   # Grafana
    9090   # Prometheus
  ];
};
```

Then rebuild:

```bash
sudo nixos-rebuild switch --flake /etc/nixos#ghostbridge
```

### Prevent Malformed Packet Shutdowns

**CRITICAL**: Hetzner will shut down your server if malformed packets are detected. Our configuration already disables hardware offload, but verify:

```bash
# Check offload settings on ens1
ethtool -k ens1 | grep -E "(tcp-segmentation-offload|generic-segmentation-offload|generic-receive-offload|large-receive-offload)"

# All should show "off"
```

## Rollback Procedure

If something goes wrong:

```bash
# At boot, select previous generation from systemd-boot menu
# OR from command line:
sudo nixos-rebuild switch --rollback --flake /etc/nixos#ghostbridge
```

## Backup Configuration

```bash
# Backup entire NixOS configuration
sudo tar czf nixos-config-backup-$(date +%Y%m%d).tar.gz /etc/nixos/

# Transfer to safe location
scp nixos-config-backup-*.tar.gz user@backup-server:/backups/
```

## Common Issues

### Issue: OVS bridges not getting IP

**Solution**: Check systemd-networkd status

```bash
sudo systemctl status systemd-networkd.service
sudo networkctl status
sudo journalctl -u systemd-networkd -f
```

### Issue: BTRFS snapshots filling disk

**Solution**: Snapshots are automatically cleaned up after 1 minute. Check:

```bash
sudo btrfs filesystem usage /var/lib/blockchain-timing
sudo ls -la /var/lib/blockchain-timing/snapshots/
```

### Issue: Qdrant not syncing

**Solution**: Check both services

```bash
sudo systemctl status btrfs-vector-sync.service
sudo systemctl status qdrant.service
sudo journalctl -u btrfs-vector-sync -f
```

### Issue: Services failing to start

**Solution**: Check dependencies

```bash
# Services have strict ordering:
# 0. disable-nic-offload.service (CRITICAL for Hetzner - runs first!)
# 1. vswitchd.service (OpenVSwitch daemon)
# 2. ovs-bridge-setup.service
# 3. systemd-networkd.service
# 4. op-dbus.service
# 5. btrfs-snapshot.service
# 6. qdrant.service
# 7. btrfs-vector-sync.service

# Check which failed first
sudo systemctl list-units --failed
sudo journalctl -xe
```

## Next Steps

- Configure VMs/containers to use OVS bridges
- Set up monitoring dashboards in Grafana
- Configure MCP agents for system orchestration
- Implement backup strategy for blockchain data
- Test disaster recovery procedures

## Support

See main repository README for support channels.

## Bootloader Configuration

The system uses **systemd-boot** with the following features enabled:

### Features
- **EFI Support**: Full UEFI boot with EFI variables management
- **netboot.xyz**: Network boot capabilities for rescue and installation
- **memtest86**: Memory diagnostics tool in boot menu
- **Security**: Boot editor disabled to prevent unauthorized modifications
- **Auto-cleanup**: Only keeps last 10 configurations to prevent /boot partition fill

### Boot Options
When the system boots, you'll see:
1. NixOS configurations (current + 9 previous generations)
2. netboot.xyz entry - for network booting and rescue operations
3. memtest86 entry - for RAM testing

### Boot Timeout
The bootloader waits **5 seconds** before auto-booting the default entry.

### EFI Mount Point
The EFI system partition is mounted at `/boot` with the label `BOOT`.

