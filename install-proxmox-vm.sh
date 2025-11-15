#!/usr/bin/env bash
set -euo pipefail

echo "=== Installing Proxmox VE 8.2 in VM on NixOS ==="

# Configuration
VM_NAME="proxmox-ve"
VM_DISK="/var/lib/libvirt/images/${VM_NAME}.qcow2"
VM_DISK_SIZE="100G"
VM_RAM="8192"
VM_CPUS="4"
ISO_URL="https://enterprise.proxmox.com/iso/proxmox-ve_8.2-1.iso"
ISO_PATH="/var/lib/libvirt/images/proxmox-ve-8.2.iso"

# Download Proxmox ISO
if [ ! -f "$ISO_PATH" ]; then
    echo "Downloading Proxmox VE 8.2 ISO..."
    sudo curl -L "$ISO_URL" -o "$ISO_PATH"
fi

# Create VM disk
echo "Creating VM disk ($VM_DISK_SIZE)..."
sudo qemu-img create -f qcow2 "$VM_DISK" "$VM_DISK_SIZE"

# Create VM with virt-install
echo "Creating Proxmox VE VM..."
sudo virt-install \
    --name "$VM_NAME" \
    --ram "$VM_RAM" \
    --vcpus "$VM_CPUS" \
    --disk path="$VM_DISK",format=qcow2,bus=virtio \
    --cdrom "$ISO_PATH" \
    --network bridge=ovsbr0,model=virtio \
    --graphics vnc,listen=0.0.0.0,port=5900 \
    --os-variant debian11 \
    --boot uefi \
    --virt-type kvm \
    --cpu host-passthrough \
    --features kvm_hidden=on \
    --noautoconsole

echo ""
echo "=== Proxmox VE VM Created ==="
echo "Connect to VNC console: http://your-ip:6080"
echo "Or use: virt-manager"
echo ""
echo "After installation, access Proxmox at: https://VM-IP:8006"
echo ""
echo "Enable nested virtualization in Proxmox:"
echo "  echo 'options kvm-intel nested=1' | sudo tee /etc/modprobe.d/kvm-intel.conf"
