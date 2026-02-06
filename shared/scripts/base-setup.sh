#!/usr/bin/env bash
# ──────────────────────────────────────────────────────────────
# base-setup.sh — OS updates, base packages, and hardening
# ──────────────────────────────────────────────────────────────
set -euo pipefail

echo ">>> [base-setup] Starting base setup..."

# ── 1. System Updates ────────────────────────────────────────

export DEBIAN_FRONTEND=noninteractive

apt-get update -y
apt-get upgrade -y
apt-get dist-upgrade -y

# ── 2. Essential Packages ────────────────────────────────────

PACKAGES=(
  ca-certificates
  curl
  wget
  gnupg
  lsb-release
  unzip
  jq
  htop
  net-tools
  dnsutils
  vim
  git
  python3
  python3-pip
  fail2ban
  auditd
  ufw
  chrony
)

# Distro-specific packages
if [ -f /etc/os-release ]; then
  . /etc/os-release
  case "$ID" in
    ubuntu)
      PACKAGES+=(software-properties-common audispd-plugins)
      ;;
    debian)
      PACKAGES+=(audispd-plugins)
      ;;
  esac
fi

apt-get install -y "${PACKAGES[@]}"

# ── 3. Timezone ──────────────────────────────────────────────

timedatectl set-timezone UTC

# ── 4. SSH Hardening ─────────────────────────────────────────
# NOTE: Sections 4-5 (SSH & sysctl hardening) overlap with the
# Ansible hardening role in shared/ansible/roles/hardening/.
# Both exist because Azure and VMware builds don't run Ansible yet.
# Once Ansible is added to all platforms, migrate these settings
# into the Ansible role as the single source of truth.

SSHD_CONFIG="/etc/ssh/sshd_config"

# Disable root login
sed -i 's/^#*PermitRootLogin.*/PermitRootLogin no/' "$SSHD_CONFIG"

# Disable password auth (keys only). Safe during Packer builds because
# the SSH session is already established before this runs.
sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication no/' "$SSHD_CONFIG"

# Limit auth attempts
sed -i 's/^#*MaxAuthTries.*/MaxAuthTries 3/' "$SSHD_CONFIG"

# Disable X11 forwarding
sed -i 's/^#*X11Forwarding.*/X11Forwarding no/' "$SSHD_CONFIG"

# Idle timeout: 5 minutes
sed -i 's/^#*ClientAliveInterval.*/ClientAliveInterval 300/' "$SSHD_CONFIG"
sed -i 's/^#*ClientAliveCountMax.*/ClientAliveCountMax 0/' "$SSHD_CONFIG"

# ── 5. Kernel Hardening (sysctl) ────────────────────────────

cat <<'EOF' > /etc/sysctl.d/99-hardening.conf
# Prevent IP spoofing
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1

# Disable source routing
net.ipv4.conf.all.accept_source_route = 0
net.ipv6.conf.all.accept_source_route = 0

# Disable ICMP redirects
net.ipv4.conf.all.accept_redirects = 0
net.ipv6.conf.all.accept_redirects = 0
net.ipv4.conf.all.send_redirects = 0

# Enable SYN cookies (SYN flood protection)
net.ipv4.tcp_syncookies = 1

# Log martian packets
net.ipv4.conf.all.log_martians = 1

# Disable IPv6 if not needed (uncomment if desired)
# net.ipv6.conf.all.disable_ipv6 = 1
EOF

sysctl --system

# ── 6. Firewall (UFW) ───────────────────────────────────────
# Allow SSH, then enable. Additional ports opened per-role.

ufw default deny incoming
ufw default allow outgoing
ufw allow ssh
ufw --force enable

# ── 7. Fail2Ban ──────────────────────────────────────────────
# Protect SSH from brute-force attacks.

cat <<'EOF' > /etc/fail2ban/jail.local
[sshd]
enabled  = true
port     = ssh
filter   = sshd
logpath  = /var/log/auth.log
maxretry = 5
bantime  = 3600
findtime = 600
EOF

systemctl enable fail2ban

# ── 8. Audit Daemon ──────────────────────────────────────────

systemctl enable auditd

# ── 9. Automatic Security Updates ────────────────────────────

apt-get install -y unattended-upgrades
dpkg-reconfigure -plow unattended-upgrades

echo ">>> [base-setup] Done."
