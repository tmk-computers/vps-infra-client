#!/usr/bin/env bash
# ==============================================================================
# Managed VPS CI/CD Platform - Turnkey Bootstrap & Installation Script
# Supports: Ubuntu 22.04 / 24.04 LTS, Debian 11/12
# ==============================================================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

INFRA_DIR="/var/www/vps-infra"

echo -e "${CYAN}${BOLD}"
echo "================================================================================"
echo "          🚀 Managed VPS CI/CD & Private Cloud Platform Installer              "
echo "================================================================================"
echo -e "${NC}"

# 1. Check Root Privileges
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}❌ This script must be run as root (or with sudo).${NC}" 
   exit 1
fi

# 2. System Hardware Check
echo -e "${BLUE}🔍 Checking system specifications...${NC}"
TOTAL_RAM_KB=$(grep MemTotal /proc/meminfo | awk '{print $2}')
TOTAL_RAM_GB=$(( TOTAL_RAM_KB / 1024 / 1024 ))
TOTAL_CORES=$(nproc)

echo -e "   • CPU Cores: ${BOLD}${TOTAL_CORES}${NC}"
echo -e "   • Memory:    ${BOLD}${TOTAL_RAM_GB} GB RAM${NC}"

if [ "$TOTAL_RAM_GB" -lt 4 ]; then
  echo -e "${YELLOW}⚠️ Warning: System has less than 4 GB of RAM. Minimum 8 GB recommended for full multi-stack builds.${NC}"
fi

# 3. Swap Configuration (Ensure at least 4GB swap space)
SWAP_TOTAL=$(free -m | grep -i swap | awk '{print $2}')
if [ "$SWAP_TOTAL" -lt 2048 ]; then
    echo -e "${BLUE}⚙️ Configuring 4 GB swap space to prevent memory spikes...${NC}"
    if [ ! -f /swapfile ]; then
        fallocate -l 4G /swapfile || dd if=/dev/zero of=/swapfile bs=1M count=4096
        chmod 600 /swapfile
        mkswap /swapfile
        swapon /swapfile
        echo '/swapfile none swap sw 0 0' >> /etc/fstab
        echo -e "${GREEN}✅ 4 GB Swap created and active.${NC}"
    fi
fi

# 4. Install Dependencies & Docker Engine
echo -e "${BLUE}📦 Updating system packages and installing prerequisites...${NC}"
apt-get update -qq
apt-get install -y -qq apt-transport-https ca-certificates curl gnupg lsb-release ufw git jq htop apache2-utils

if ! command -v docker &> /dev/null; then
    echo -e "${BLUE}🐳 Installing Docker Engine...${NC}"
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg --yes
    chmod a+r /etc/apt/keyrings/docker.gpg

    echo \
      "deb [arch="$(dpkg --print-architecture)" signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
      "$(. /etc/os-release && echo "$VERSION_CODENAME")" stable" | \
      tee /etc/apt/sources.list.d/docker.list > /dev/null

    apt-get update -qq
    apt-get install -y -qq docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    systemctl enable --now docker
    echo -e "${GREEN}✅ Docker Engine installed successfully.${NC}"
fi

# 5. Configure Firewall (UFW)
echo -e "${BLUE}🛡️ Configuring UFW Firewall...${NC}"
ufw allow 22/tcp >/dev/null 2>&1 || true
ufw allow 80/tcp >/dev/null 2>&1 || true
ufw allow 443/tcp >/dev/null 2>&1 || true
ufw --force enable >/dev/null 2>&1 || true
echo -e "${GREEN}✅ Firewall configured (Ports 22, 80, 443 open).${NC}"

# 6. Setup Directory Structure & Volumes
echo -e "${BLUE}📁 Initializing platform directories and persistent volumes...${NC}"
mkdir -p "${INFRA_DIR}/volumes/artifacts/builds"
mkdir -p "${INFRA_DIR}/volumes/apps"
mkdir -p "${INFRA_DIR}/volumes/db-backups"
mkdir -p "${INFRA_DIR}/volumes/postgres_data"
mkdir -p "${INFRA_DIR}/volumes/sqlserver_data"
mkdir -p "${INFRA_DIR}/ci-server/gradle-cache"
mkdir -p "${INFRA_DIR}/ci-server/pub-cache"
mkdir -p "${INFRA_DIR}/ci-server/maven-cache"
mkdir -p "${INFRA_DIR}/ci-server/nuget-cache"
mkdir -p "${INFRA_DIR}/ci-server/ccache"
mkdir -p "${INFRA_DIR}/ci-server/android-sdk"
mkdir -p "${INFRA_DIR}/network/traefik"

# Create Traefik acme.json with strict permissions
if [ ! -f "${INFRA_DIR}/network/traefik/acme.json" ]; then
    touch "${INFRA_DIR}/network/traefik/acme.json"
    chmod 600 "${INFRA_DIR}/network/traefik/acme.json"
fi

# 7. Create Shared Docker Network
if ! docker network inspect traefik_net >/dev/null 2>&1; then
    echo -e "${BLUE}🌐 Creating external Docker bridge network 'traefik_net'...${NC}"
    docker network create traefik_net
    echo -e "${GREEN}✅ Network 'traefik_net' created.${NC}"
fi

# 8. Setup Environment Configuration (.env)
if [ ! -f "${INFRA_DIR}/.env" ]; then
    echo "  -> Initializing .env from .env.example..."
    cp "${INFRA_DIR}/.env.example" "${INFRA_DIR}/.env"
    
    # Generate random strong passwords
    PG_PASS=$(tr -dc A-Za-z0-9_ < /dev/urandom | head -c 24)
    SQL_PASS="Sql!$(tr -dc A-Za-z0-9 < /dev/urandom | head -c 20)"
    JWT_SEC=$(tr -dc A-Za-z0-9_ < /dev/urandom | head -c 48)
    WH_TOKEN=$(tr -dc A-Za-z0-9 < /dev/urandom | head -c 32)
    
    sed -i "s/POSTGRES_PASSWORD=.*/POSTGRES_PASSWORD=${PG_PASS}/" "${INFRA_DIR}/.env"
    sed -i "s/MSSQL_SA_PASSWORD=.*/MSSQL_SA_PASSWORD=${SQL_PASS}/" "${INFRA_DIR}/.env"
    sed -i "s/JWT_SECRET=.*/JWT_SECRET=${JWT_SEC}/" "${INFRA_DIR}/.env"
    sed -i "s/CI_WEBHOOK_SECRET=.*/CI_WEBHOOK_SECRET=${WH_TOKEN}/" "${INFRA_DIR}/.env"
    echo -e "${GREEN}✅ Secure random passwords and secrets generated in .env.${NC}"
fi

# 9. Apply Kernel Performance Optimizations
if [ -f "${INFRA_DIR}/scripts/optimize-vps-limits.sh" ]; then
    chmod +x "${INFRA_DIR}/scripts/optimize-vps-limits.sh"
    "${INFRA_DIR}/scripts/optimize-vps-limits.sh"
fi

echo ""
echo -e "${GREEN}${BOLD}================================================================================"
echo "          🎉 Platform Bootstrap & Prerequisites Completed Successfully!        "
echo "================================================================================${NC}"
echo -e "Next steps:"
echo -e " 1. Review and update domain names in: ${BOLD}${INFRA_DIR}/.env${NC}"
echo -e " 2. Start core services:"
echo -e "    ${CYAN}cd ${INFRA_DIR}/network/traefik && docker compose up -d${NC}"
echo -e "    ${CYAN}cd ${INFRA_DIR}/docker-registry && docker compose up -d${NC}"
echo -e "    ${CYAN}cd ${INFRA_DIR}/db/postgres && docker compose up -d${NC}"
echo -e "    ${CYAN}cd ${INFRA_DIR}/devops-manager && docker compose up -d${NC}"
echo -e "    ${CYAN}cd ${INFRA_DIR}/ci-server && docker compose up -d${NC}"
echo ""
