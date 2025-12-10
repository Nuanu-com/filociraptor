#!/usr/bin/env bash
set -euo pipefail

# ==========================================
# Consul Installation + ACL Bootstrap Script
# ==========================================

CONSUL_VERSION="1.18.1"
CONSUL_USER="consul"
CONSUL_BIN="/usr/local/bin/consul"
CONSUL_CONF_DIR="/etc/consul.d"
CONSUL_DATA_DIR="/opt/consul"
SYSTEMD_UNIT="/etc/systemd/system/consul.service"

echo "=== Installing dependencies ==="
apt update -y
apt install -y unzip curl jq

# --- DOWNLOAD CONSUL ---
echo "=== Downloading Consul ${CONSUL_VERSION} ==="
cd /tmp
curl -fSL "https://releases.hashicorp.com/consul/${CONSUL_VERSION}/consul_${CONSUL_VERSION}_linux_amd64.zip" -o consul.zip
unzip -o consul.zip
mv consul /usr/local/bin/
chmod 755 /usr/local/bin/consul

# --- USER + DIRECTORIES ---
echo "=== Creating consul user ==="
id -u $CONSUL_USER >/dev/null 2>&1 || useradd --system --home "$CONSUL_CONF_DIR" --shell /bin/false $CONSUL_USER

mkdir -p "$CONSUL_CONF_DIR" "$CONSUL_DATA_DIR"
chown -R consul:consul "$CONSUL_CONF_DIR" "$CONSUL_DATA_DIR"
chmod -R 750 "$CONSUL_CONF_DIR" "$CONSUL_DATA_DIR"

# --- BASE CONFIG ---
echo "=== Creating base config ==="
cat > "$CONSUL_CONF_DIR/consul.hcl" <<EOF
server = true
bootstrap_expect = 1
data_dir = "$CONSUL_DATA_DIR"
bind_addr = "0.0.0.0"
client_addr = "0.0.0.0"
ui = true
EOF

# --- ACL CONFIG ---
echo "=== Enabling ACL ==="
cat > "$CONSUL_CONF_DIR/acl.hcl" <<EOF
acl {
  enabled = true
  default_policy = "deny"
  down_policy = "allow"
  enable_token_persistence = true
}
EOF

chown -R consul:consul "$CONSUL_CONF_DIR"

# --- SYSTEMD SERVICE ---
echo "=== Creating systemd service ==="
cat > "$SYSTEMD_UNIT" <<EOF
[Unit]
Description=HashiCorp Consul Agent
Requires=network-online.target
After=network-online.target

[Service]
User=consul
Group=consul
ExecStart=$CONSUL_BIN agent -config-dir=$CONSUL_CONF_DIR
ExecReload=/bin/kill -HUP \$MAINPID
KillMode=process
Restart=on-failure
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable consul
systemctl restart consul

echo "=== Waiting for consul to start ==="
sleep 5

# --- ACL BOOTSTRAP ---
echo "=== Bootstrapping ACL ==="
if ! consul acl token list --http-addr=http://127.0.0.1:8500 >/dev/null 2>&1; then
    BOOTSTRAP=$(consul acl bootstrap --http-addr=http://127.0.0.1:8500)
    echo "$BOOTSTRAP"

    MASTER_TOKEN=$(echo "$BOOTSTRAP" | awk -F': ' '/SecretID/ {print $2}')
    echo "=== Saving master token to /root/consul_master_token.txt ==="
    echo "$MASTER_TOKEN" > /root/consul_master_token.txt
    chmod 600 /root/consul_master_token.txt

    echo "Master Token: $MASTER_TOKEN"
else
    echo "ACL already bootstrapped."
fi

echo "=== INSTALLATION COMPLETE ==="
echo "Master token saved in: /root/consul_master_token.txt"
