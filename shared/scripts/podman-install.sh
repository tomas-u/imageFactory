#!/usr/bin/env bash
# ──────────────────────────────────────────────────────────────
# podman-install.sh — Install Podman from official Ubuntu repos
# ──────────────────────────────────────────────────────────────
set -euo pipefail

echo ">>> [podman] Installing Podman..."

export DEBIAN_FRONTEND=noninteractive

apt-get update -y
apt-get install -y \
  podman \
  buildah \
  skopeo

# Enable the Podman socket (Docker-compatible API)
systemctl enable podman.socket

# Container logging and resource defaults
mkdir -p /etc/containers
cat <<'EOF' > /etc/containers/containers.conf
[containers]
log_driver = "journald"
default_ulimits = [
  "nofile=65536:65536",
]
no_new_privileges = true

[engine]
runtime = "crun"
EOF

echo ">>> [podman] Podman installed: $(podman --version)"
