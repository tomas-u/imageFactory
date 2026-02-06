#!/usr/bin/env bash
# ──────────────────────────────────────────────────────────────
# cleanup.sh — Prepare image for snapshotting
# ──────────────────────────────────────────────────────────────
# This script MUST run last, right before the image is captured.
# It removes build-time artifacts, logs, SSH keys, and caches
# to produce a clean, secure, and small snapshot.
# ──────────────────────────────────────────────────────────────
set -euo pipefail

echo ">>> [cleanup] Starting image cleanup..."

# ── 1. Remove build-time SSH keys ────────────────────────────
# New keys will be regenerated on first boot via cloud-init.

rm -f /etc/ssh/ssh_host_*

# ── 2. Clean apt cache ──────────────────────────────────────

apt-get autoremove -y --purge
apt-get clean -y
rm -rf /var/lib/apt/lists/*

# ── 3. Clear logs ───────────────────────────────────────────

find /var/log -type f -exec truncate --size=0 {} \;
journalctl --vacuum-time=0 2>/dev/null || true

# ── 4. Clear temp files ─────────────────────────────────────

rm -rf /tmp/* /var/tmp/*

# ── 5. Clear shell history ──────────────────────────────────

unset HISTFILE
rm -f /root/.bash_history
rm -f /home/*/.bash_history
history -c 2>/dev/null || true

# ── 6. Clear cloud-init state ───────────────────────────────
# So cloud-init runs fresh on first boot of new instances.

cloud-init clean --logs 2>/dev/null || true

# ── 7. Zero free space (optional — reduces image size) ──────
# Uncomment for on-prem / VMware where image size matters.
# Not needed for cloud (EBS snapshots handle this differently).
#
# dd if=/dev/zero of=/EMPTY bs=1M 2>/dev/null || true
# rm -f /EMPTY

# ── 8. Sync filesystem ─────────────────────────────────────

sync

echo ">>> [cleanup] Image cleanup complete."
