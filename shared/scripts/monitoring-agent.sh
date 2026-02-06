#!/usr/bin/env bash
# ──────────────────────────────────────────────────────────────
# monitoring-agent.sh — Install Prometheus node_exporter
# ──────────────────────────────────────────────────────────────
set -euo pipefail

echo ">>> [monitoring] Installing node_exporter..."

NODE_EXPORTER_VERSION="1.8.2"
ARCH="amd64"

cd /tmp
curl -fsSLO "https://github.com/prometheus/node_exporter/releases/download/v${NODE_EXPORTER_VERSION}/node_exporter-${NODE_EXPORTER_VERSION}.linux-${ARCH}.tar.gz"
tar xzf "node_exporter-${NODE_EXPORTER_VERSION}.linux-${ARCH}.tar.gz"
mv "node_exporter-${NODE_EXPORTER_VERSION}.linux-${ARCH}/node_exporter" /usr/local/bin/
rm -rf "node_exporter-${NODE_EXPORTER_VERSION}.linux-${ARCH}"*

# Create a dedicated user
useradd --no-create-home --shell /usr/sbin/nologin node_exporter || true

# Systemd service
cat <<'EOF' > /etc/systemd/system/node_exporter.service
[Unit]
Description=Prometheus Node Exporter
Documentation=https://prometheus.io/docs/guides/node-exporter/
After=network-online.target
Wants=network-online.target

[Service]
User=node_exporter
Group=node_exporter
Type=simple
ExecStart=/usr/local/bin/node_exporter \
  --collector.systemd \
  --collector.processes \
  --web.listen-address=:9100
Restart=always
RestartSec=5

# Security hardening
NoNewPrivileges=true
ProtectSystem=strict
ProtectHome=true
PrivateTmp=true

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable node_exporter

# Open firewall port
ufw allow 9100/tcp comment "Prometheus node_exporter" || true

echo ">>> [monitoring] node_exporter v${NODE_EXPORTER_VERSION} installed."
