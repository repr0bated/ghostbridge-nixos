#!/usr/bin/env bash
#
# SSH Passwordless Key Setup Script
# This script sets up SSH key-based authentication
#

set -euo pipefail

echo "=== SSH Passwordless Key Setup ==="
echo ""

# Configuration
SSH_DIR="$HOME/.ssh"
KEY_TYPE="ed25519"
KEY_FILE="$SSH_DIR/id_$KEY_TYPE"
AUTHORIZED_KEYS="$SSH_DIR/authorized_keys"

# Create .ssh directory if it doesn't exist
if [ ! -d "$SSH_DIR" ]; then
    echo "Creating $SSH_DIR..."
    mkdir -p "$SSH_DIR"
    chmod 700 "$SSH_DIR"
fi

# Generate SSH key if it doesn't exist
if [ ! -f "$KEY_FILE" ]; then
    echo "Generating new $KEY_TYPE SSH key pair..."
    echo "Press Enter when prompted for passphrase (leave empty for passwordless)"
    ssh-keygen -t "$KEY_TYPE" -f "$KEY_FILE" -C "$(whoami)@$(hostname)"
    echo "✓ Key generated: $KEY_FILE"
else
    echo "✓ SSH key already exists: $KEY_FILE"
fi

# Set proper permissions
chmod 600 "$KEY_FILE"
chmod 644 "$KEY_FILE.pub"

# Create authorized_keys if it doesn't exist
if [ ! -f "$AUTHORIZED_KEYS" ]; then
    touch "$AUTHORIZED_KEYS"
    chmod 600 "$AUTHORIZED_KEYS"
fi

# Ask if user wants to add key to authorized_keys (for local login)
echo ""
read -p "Add public key to authorized_keys for local passwordless login? (y/n): " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Yy]$ ]]; then
    if ! grep -q "$(cat $KEY_FILE.pub)" "$AUTHORIZED_KEYS" 2>/dev/null; then
        cat "$KEY_FILE.pub" >> "$AUTHORIZED_KEYS"
        echo "✓ Public key added to $AUTHORIZED_KEYS"
    else
        echo "✓ Public key already in authorized_keys"
    fi
fi

# Display the public key
echo ""
echo "=== Your Public Key ==="
echo "Copy this key to remote servers' ~/.ssh/authorized_keys:"
echo ""
cat "$KEY_FILE.pub"
echo ""

# Create/update SSH config for better defaults
SSH_CONFIG="$SSH_DIR/config"
if [ ! -f "$SSH_CONFIG" ]; then
    echo "Creating SSH config with secure defaults..."
    cat > "$SSH_CONFIG" <<EOF
# SSH Client Configuration
Host *
    IdentityFile $KEY_FILE
    AddKeysToAgent yes
    ForwardAgent no
    ServerAliveInterval 60
    ServerAliveCountMax 3
    HashKnownHosts yes
    PasswordAuthentication no
    ChallengeResponseAuthentication no
    PubkeyAuthentication yes
EOF
    chmod 600 "$SSH_CONFIG"
    echo "✓ Created $SSH_CONFIG"
else
    echo "✓ SSH config already exists: $SSH_CONFIG"
fi

# Start ssh-agent if not running
if [ -z "${SSH_AUTH_SOCK:-}" ]; then
    echo ""
    echo "Starting ssh-agent..."
    eval "$(ssh-agent -s)"
    ssh-add "$KEY_FILE"
    echo "✓ SSH key added to agent"
    echo ""
    echo "Note: Add the following to your ~/.bashrc or ~/.zshrc:"
    echo "  eval \"\$(ssh-agent -s)\" 2>/dev/null"
    echo "  ssh-add $KEY_FILE 2>/dev/null"
fi

echo ""
echo "=== Setup Complete ==="
echo ""
echo "Next steps:"
echo "1. Copy the public key above to remote servers:"
echo "   ssh-copy-id -i $KEY_FILE.pub user@remote-host"
echo ""
echo "2. Or manually append to remote ~/.ssh/authorized_keys:"
echo "   cat $KEY_FILE.pub | ssh user@remote 'cat >> ~/.ssh/authorized_keys'"
echo ""
echo "3. Test connection:"
echo "   ssh -i $KEY_FILE user@remote-host"
echo ""
echo "Files created:"
echo "  - Private key: $KEY_FILE"
echo "  - Public key:  $KEY_FILE.pub"
echo "  - SSH config:  $SSH_CONFIG"
echo ""
