#!/bin/bash

set -e

echo "=== Ubuntu Basic Server Bootstrap ==="

# -----------------------------
# Variables
# -----------------------------
USERNAME="${SUDO_USER:-$(whoami)}"
USER_HOME=$(eval echo "~$USERNAME")
SSH_DIR="$USER_HOME/.ssh"
AUTHORIZED_KEYS="$SSH_DIR/authorized_keys"

SSH_PUBLIC_KEY="ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDEJ3xjcjJ7EPgOVd5OZ4Yo/ey43wSwYxEreE63U1eBJC2AxJswNbcVibS+a6Hg+PJO+1cDsmkkRH4aKCy8Rw9N3NW+P+22lJlp8HGdMDB1neq10/5NM/ikT4OHpYrd6BT7DlIAo+ZtywH4Zyv9ta6WUusx1GYPzN7uABH1fqenCY6Lt5A3fq5vqIehVzm2ymABew2vsThuOwGuYuvCfXTNyUVnYYEEub9T0qtb4BRUaRHvKvGG+HGcuWnYsVQJ8En/dPkfw+qNaTILAoT0BBVMu/Tf2si2/p67kPeOCZoKC/lNidXTVxg4TwOsPUwIr+n6fqMPrNlQzvpvwVYrHLJ5kHQmj94xwqp7+VxGqBV35DxbX3dCfMto6rd+OI4IjiCPuwUWvn2mdBHlK21dcp7zHxz67vGH0QufDjua4MHqZkMrmgmoXNy7riX/6ICvT9ipOyDThZzFequkwSMfRHKAVb7RHYhfurniXt2H4EZAdAfO0F3XdUhrQJXZ/U0yWcs= yogadarmabendesa@Macbook-Yoga.local"

# -----------------------------
# System Update
# -----------------------------
echo "Updating system..."
apt update && apt upgrade -y

# -----------------------------
# Base Utilities (netstat + git)
# -----------------------------
echo "Installing base utilities (net-tools, git)..."
apt install -y \
  net-tools \
  git \
  curl \
  ca-certificates \
  gnupg \
  lsb-release

# -----------------------------
# Install Docker
# -----------------------------
echo "Installing Docker..."
curl -fsSL https://get.docker.com | bash

systemctl enable docker
systemctl start docker

# Add user to docker group
usermod -aG docker "$USERNAME"

# -----------------------------
# Install Docker Compose (plugin)
# -----------------------------
echo "Installing Docker Compose plugin..."
mkdir -p /usr/local/lib/docker/cli-plugins

curl -SL https://github.com/docker/compose/releases/download/v2.27.0/docker-compose-linux-x86_64 \
  -o /usr/local/lib/docker/cli-plugins/docker-compose

chmod +x /usr/local/lib/docker/cli-plugins/docker-compose

# -----------------------------
# Install k9s
# -----------------------------
echo "Installing k9s..."
K9S_VERSION=$(curl -s https://api.github.com/repos/derailed/k9s/releases/latest | grep tag_name | cut -d '"' -f 4)

curl -LO "https://github.com/derailed/k9s/releases/download/${K9S_VERSION}/k9s_Linux_amd64.tar.gz"
tar -xzf k9s_Linux_amd64.tar.gz
mv k9s /usr/local/bin/
chmod +x /usr/local/bin/k9s
rm -f k9s_Linux_amd64.tar.gz LICENSE README.md

# -----------------------------
# Setup SSH Authorized Keys
# -----------------------------
echo "Configuring SSH authorized_keys..."

mkdir -p "$SSH_DIR"
chmod 700 "$SSH_DIR"
touch "$AUTHORIZED_KEYS"
chmod 600 "$AUTHORIZED_KEYS"

grep -qxF "$SSH_PUBLIC_KEY" "$AUTHORIZED_KEYS" || echo "$SSH_PUBLIC_KEY" >> "$AUTHORIZED_KEYS"

chown -R "$USERNAME:$USERNAME" "$SSH_DIR"

# -----------------------------
# Done
# -----------------------------
echo "===================================="
echo " Bootstrap completed successfully!"
echo " Installed:"
echo "  - netstat (net-tools)"
echo "  - git"
echo "  - Docker"
echo "  - Docker Compose"
echo "  - k9s"
echo " SSH key added for user: $USERNAME"
echo ""
echo " IMPORTANT:"
echo "  - Log out and log back in to use Docker without sudo"
echo "===================================="
