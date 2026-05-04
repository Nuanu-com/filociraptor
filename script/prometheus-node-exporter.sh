#!/bin/bash
set -e

PROM_VERSION="2.54.1"
NODE_EXPORTER_VERSION="1.8.2"

echo "Creating users..."
sudo useradd --no-create-home --shell /bin/false prometheus 2>/dev/null || true
sudo useradd --no-create-home --shell /bin/false node_exporter 2>/dev/null || true

echo "Creating directories..."
sudo mkdir -p /etc/prometheus /var/lib/prometheus
sudo chown prometheus:prometheus /etc/prometheus /var/lib/prometheus

cd /tmp

echo "Installing Prometheus..."
wget -q https://github.com/prometheus/prometheus/releases/download/v${PROM_VERSION}/prometheus-${PROM_VERSION}.linux-amd64.tar.gz
tar xzf prometheus-${PROM_VERSION}.linux-amd64.tar.gz

sudo cp prometheus-${PROM_VERSION}.linux-amd64/prometheus /usr/local/bin/
sudo cp prometheus-${PROM_VERSION}.linux-amd64/promtool /usr/local/bin/
sudo cp -r prometheus-${PROM_VERSION}.linux-amd64/consoles /etc/prometheus
sudo cp -r prometheus-${PROM_VERSION}.linux-amd64/console_libraries /etc/prometheus

sudo chown prometheus:prometheus /usr/local/bin/prometheus /usr/local/bin/promtool
sudo chown -R prometheus:prometheus /etc/prometheus

echo "Installing node_exporter..."
wget -q https://github.com/prometheus/node_exporter/releases/download/v${NODE_EXPORTER_VERSION}/node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64.tar.gz
tar xzf node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64.tar.gz

sudo cp node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64/node_exporter /usr/local/bin/
sudo chown node_exporter:node_exporter /usr/local/bin/node_exporter

echo "Creating Prometheus config..."
sudo tee /etc/prometheus/prometheus.yml > /dev/null <<EOF
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: "nodeexporter"
    static_configs:
      - targets:
          - "localhost:9100"
EOF

sudo chown prometheus:prometheus /etc/prometheus/prometheus.yml

echo "Creating node_exporter service..."
sudo tee /etc/systemd/system/node_exporter.service > /dev/null <<EOF
[Unit]
Description=Node Exporter
Wants=network-online.target
After=network-online.target

[Service]
User=node_exporter
Group=node_exporter
Type=simple
ExecStart=/usr/local/bin/node_exporter --web.listen-address=:9100

[Install]
WantedBy=multi-user.target
EOF

echo "Creating Prometheus service..."
sudo tee /etc/systemd/system/prometheus.service > /dev/null <<EOF
[Unit]
Description=Prometheus
Wants=network-online.target
After=network-online.target

[Service]
User=prometheus
Group=prometheus
Type=simple
ExecStart=/usr/local/bin/prometheus \\
  --config.file=/etc/prometheus/prometheus.yml \\
  --storage.tsdb.path=/var/lib/prometheus \\
  --web.console.templates=/etc/prometheus/consoles \\
  --web.console.libraries=/etc/prometheus/console_libraries \\
  --web.listen-address=0.0.0.0:9090

[Install]
WantedBy=multi-user.target
EOF

echo "Starting services..."
sudo systemctl daemon-reload
sudo systemctl enable node_exporter prometheus
sudo systemctl restart node_exporter prometheus

echo "Opening firewall if UFW exists..."
if command -v ufw >/dev/null 2>&1; then
  sudo ufw allow 9090/tcp || true
  sudo ufw allow 9100/tcp || true
fi

echo "Done."
echo "Check Prometheus:"
echo "curl http://localhost:9090/-/ready"
echo
echo "Check node_exporter:"
echo "curl http://localhost:9100/metrics"