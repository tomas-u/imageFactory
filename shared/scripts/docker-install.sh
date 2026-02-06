#!/usr/bin/env bash
# ──────────────────────────────────────────────────────────────
# docker-install.sh — Install Docker CE from official repo
# ──────────────────────────────────────────────────────────────
set -euo pipefail

echo ">>> [docker] Installing Docker CE..."

export DEBIAN_FRONTEND=noninteractive

# Add Docker's official GPG key
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
  -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc

# Add the Docker apt repository
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] \
  https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "${VERSION_CODENAME}") stable" \
  | tee /etc/apt/sources.list.d/docker.list > /dev/null

apt-get update -y
apt-get install -y \
  docker-ce \
  docker-ce-cli \
  containerd.io \
  docker-buildx-plugin \
  docker-compose-plugin

# Enable Docker to start on boot
systemctl enable docker
systemctl enable containerd

# Docker daemon hardening
mkdir -p /etc/docker
cat <<'EOF' > /etc/docker/daemon.json
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "50m",
    "max-file": "3"
  },
  "default-ulimits": {
    "nofile": {
      "Name": "nofile",
      "Hard": 65536,
      "Soft": 65536
    }
  },
  "live-restore": true,
  "userland-proxy": false,
  "no-new-privileges": true
}
EOF

echo ">>> [docker] Docker CE installed: $(docker --version)"
