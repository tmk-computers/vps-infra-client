#!/usr/bin/env bash
# ==============================================================================
# Managed VPS CI/CD Platform - Linux Kernel & System Limit Optimizer
# Designed for 4 vCPU / 16 GB RAM VPS running Docker, DBs, and CI builds
# ==============================================================================

set -e

echo "🔧 Applying Linux kernel and network performance optimizations..."

# 1. Sysctl kernel tuning for high-throughput container networking & DBs
cat <<EOF > /etc/sysctl.d/99-vps-infra-performance.conf
# Virtual Memory & Caching (Prevents aggressive swapping while preserving RAM for apps)
vm.swappiness = 10
vm.vfs_cache_pressure = 50
vm.dirty_background_ratio = 5
vm.dirty_ratio = 10
vm.max_map_count = 262144

# Network & Socket Connection Limits
net.core.somaxconn = 65535
net.ipv4.tcp_max_syn_backlog = 65535
net.core.netdev_max_backlog = 10000
net.ipv4.ip_local_port_range = 1024 65535
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_fin_timeout = 15

# File Descriptors & Inotify Watchers (Essential for multi-repo CI and Node/Docker builds)
fs.file-max = 2097152
fs.inotify.max_user_watches = 524288
fs.inotify.max_user_instances = 8192
EOF

sysctl --system -q >/dev/null 2>&1 || true

# 2. System Limits (nofile, nproc)
cat <<EOF > /etc/security/limits.d/99-vps-infra-limits.conf
* soft nofile 1048576
* hard nofile 1048576
* soft nproc 65535
* hard nproc 65535
root soft nofile 1048576
root hard nofile 1048576
root soft nproc 65535
root hard nproc 65535
EOF

echo "✅ Kernel performance optimizations applied successfully."
