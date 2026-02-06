#!/usr/bin/env bash
# ──────────────────────────────────────────────────────────────
# monitoring-agent.sh — Install Prometheus node_exporter
# ──────────────────────────────────────────────────────────────
set -euo pipefail

echo ">>> [monitoring] Installing node_exporter..."

NODE_EXPORTER_VERSION="${NODE_EXPORTER_VERSION:-1.8.2}"
ARCH="$(dpkg --print-architecture)"

# SHA256 checksums per version/arch — update when bumping version
declare -A CHECKSUMS
CHECKSUMS["1.8.2-amd64"]="6809dd0b3ec45fd6e992c19071d6b5253aed3ead7bf0686885a51d85c6643c66"
CHECKSUMS["1.8.2-arm64"]="627382b9723c642411c33f48861134ebe893e70a63bcc8b3fc0619cd0bfac4be"

CHECKSUM_KEY="${NODE_EXPORTER_VERSION}-${ARCH}"
if [[ -z "${CHECKSUMS[$CHECKSUM_KEY]:-}" ]]; then
  echo "ERROR: No checksum found for node_exporter ${NODE_EXPORTER_VERSION} (${ARCH})."
  echo "Add the SHA256 to the CHECKSUMS map in this script."
  exit 1
fi

TARBALL="node_exporter-${NODE_EXPORTER_VERSION}.linux-${ARCH}.tar.gz"

cd /tmp
curl -fsSLO "https://github.com/prometheus/node_exporter/releases/download/v${NODE_EXPORTER_VERSION}/${TARBALL}"

echo "${CHECKSUMS[$CHECKSUM_KEY]}  ${TARBALL}" | sha256sum --check -
tar xzf "${TARBALL}"
mv "node_exporter-${NODE_EXPORTER_VERSION}.linux-${ARCH}/node_exporter" /usr/local/bin/
rm -rf "node_exporter-${NODE_EXPORTER_VERSION}.linux-${ARCH}"*

# Create a dedicated user
useradd --no-create-home --shell /usr/sbin/nologin node_exporter || true

# Systemd service — bind to localhost only (override at deploy time if needed)
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
  --web.listen-address=127.0.0.1:9100
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

echo ">>> [monitoring] node_exporter v${NODE_EXPORTER_VERSION} installed (listening on 127.0.0.1:9100)."
