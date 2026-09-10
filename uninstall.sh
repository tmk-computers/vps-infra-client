#!/bin/bash
# ==============================================================================
# 🛑 VPS-INFRA-CLIENT: CLEAN UNINSTALL & TEARDOWN SCRIPT
# ==============================================================================
# Safely stops and cleans up all vps-infra-client services, networks, and cron jobs.
# Provides optional persistent data retention for seamless reinstallation.
# ==============================================================================
set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Defaults: Safe data preservation for clean reinstalls
PURGE_DATA=false
PURGE_ENV=false
FORCE=false

print_usage() {
    local exit_code="${1:-0}"
    echo -e "${BOLD}Usage:${NC} bash uninstall.sh [OPTIONS]"
    echo ""
    echo -e "${BOLD}Options:${NC}"
    echo "  --keep-data      Preserve persistent database & registry volumes (default)"
    echo "  --purge-data     Permanently delete persistent volumes (/var/www/vps-infra/volumes)"
    echo "  --keep-env       Preserve .env configuration file for instant reinstall (default)"
    echo "  --purge-env      Permanently delete .env configuration file"
    echo "  -f, --force      Non-interactive mode (bypasses confirmation prompts)"
    echo "  -h, --help       Show this help message"
    echo ""
    echo -e "${BOLD}Examples:${NC}"
    echo "  bash uninstall.sh                     # Interactive mode"
    echo "  bash uninstall.sh --force             # Non-interactive teardown, keeping data & .env"
    echo "  bash uninstall.sh --purge-data --purge-env --force # Complete hard purge"
    exit "$exit_code"
}

# Parse CLI arguments
while [[ "$#" -gt 0 ]]; do
    case "$1" in
        --keep-data) PURGE_DATA=false ;;
        --purge-data) PURGE_DATA=true ;;
        --keep-env) PURGE_ENV=false ;;
        --purge-env) PURGE_ENV=true ;;
        -f|--force) FORCE=true ;;
        -h|--help) print_usage 0 ;;
        *) echo -e "${RED}Unknown option: $1${NC}" >&2; print_usage 1 ;;
    esac
    shift
done

echo -e "${RED}${BOLD}"
echo "======================================================================"
echo "   🛑 VPS-INFRA-CLIENT: PLATFORM TEARDOWN & UNINSTALLATION"
echo "======================================================================"
echo -e "${NC}"

# Interactive Confirmation
if [ "$FORCE" = false ]; then
    echo -e "${YELLOW}This script will shut down and remove all vps-infra-client services.${NC}"
    read -rp "Are you sure you want to proceed with uninstallation? [y/N]: " CONFIRM
    if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
        echo -e "${CYAN}Uninstallation cancelled.${NC}"
        exit 0
    fi

    # Confirm Data Volumes
    if [ "$PURGE_DATA" = false ]; then
        read -rp "Do you also want to PERMANENTLY DELETE database and registry data (/var/www/vps-infra/volumes)? [y/N]: " CONFIRM_DATA
        if [[ "$CONFIRM_DATA" =~ ^[Yy]$ ]]; then
            PURGE_DATA=true
        fi
    fi

    # Confirm .env configuration
    if [ "$PURGE_ENV" = false ]; then
        read -rp "Do you also want to delete the configuration file (.env)? [y/N]: " CONFIRM_ENV
        if [[ "$CONFIRM_ENV" =~ ^[Yy]$ ]]; then
            PURGE_ENV=true
        fi
    fi
fi

echo -e "\n${CYAN}▶ 1. Stopping Application Platform Services...${NC}"
if [ -f "$SCRIPT_DIR/docker-compose.yml" ]; then
    docker compose -f "$SCRIPT_DIR/docker-compose.yml" --profile all down --remove-orphans 2>/dev/null || true
fi
if [ -f "$SCRIPT_DIR/docker-compose.uat.yml" ]; then
    docker compose -f "$SCRIPT_DIR/docker-compose.uat.yml" --profile all down --remove-orphans 2>/dev/null || true
fi
echo -e "${GREEN}   ✅ Application platform containers stopped.${NC}"

echo -e "\n${CYAN}▶ 2. Stopping Private Docker Registry...${NC}"
if [ -f "$SCRIPT_DIR/docker-registry/docker-compose.yml" ]; then
    docker compose -f "$SCRIPT_DIR/docker-registry/docker-compose.yml" down --remove-orphans 2>/dev/null || true
    echo -e "${GREEN}   ✅ Docker registry stopped.${NC}"
fi

echo -e "\n${CYAN}▶ 3. Stopping Shared Database Services (PostgreSQL & MS SQL)...${NC}"
if [ -f "$SCRIPT_DIR/db/docker-compose.yml" ]; then
    docker compose -f "$SCRIPT_DIR/db/docker-compose.yml" down --remove-orphans 2>/dev/null || true
    echo -e "${GREEN}   ✅ Shared database containers stopped.${NC}"
fi

echo -e "\n${CYAN}▶ 4. Stopping Global Reverse Proxy (Traefik)...${NC}"
if [ -f "$SCRIPT_DIR/network/traefik/docker-compose.yml" ]; then
    docker compose -f "$SCRIPT_DIR/network/traefik/docker-compose.yml" down --remove-orphans 2>/dev/null || true
    echo -e "${GREEN}   ✅ Traefik reverse proxy stopped.${NC}"
fi

echo -e "\n${CYAN}▶ 5. Removing Traefik Docker Network...${NC}"
if docker network inspect traefik_net &>/dev/null; then
    docker network rm traefik_net 2>/dev/null || true
    echo -e "${GREEN}   ✅ 'traefik_net' network removed.${NC}"
else
    echo -e "${GREEN}   ✅ 'traefik_net' network already removed.${NC}"
fi

echo -e "\n${CYAN}▶ 6. Cleaning Up Maintenance Cron Jobs...${NC}"
if [ -f /etc/cron.d/docker-maintenance ]; then
    if [ "$EUID" -eq 0 ] || command -v sudo &>/dev/null; then
        sudo rm -f /etc/cron.d/docker-maintenance 2>/dev/null || true
        echo -e "${GREEN}   ✅ /etc/cron.d/docker-maintenance removed.${NC}"
    fi
else
    echo -e "${GREEN}   ✅ No maintenance cron jobs found.${NC}"
fi

# 7. Persistent Data Handling
echo -e "\n${CYAN}▶ 7. Managing Persistent Storage Volumes...${NC}"
VOLUMES_DIR="$SCRIPT_DIR/volumes"
if [ "$PURGE_DATA" = true ]; then
    if [ -d "$VOLUMES_DIR" ]; then
        echo -e "${YELLOW}   ⚠️ Purging persistent volumes ($VOLUMES_DIR)...${NC}"
        if [ "$EUID" -eq 0 ] || command -v sudo &>/dev/null; then
            sudo rm -rf "$VOLUMES_DIR"
        else
            rm -rf "$VOLUMES_DIR"
        fi
        echo -e "${GREEN}   ✅ Persistent storage volumes deleted.${NC}"
    fi
else
    echo -e "${GREEN}   ✅ Preserved persistent volumes at: $VOLUMES_DIR${NC}"
fi

# 8. Configuration File Handling
echo -e "\n${CYAN}▶ 8. Managing Configuration File (.env)...${NC}"
if [ "$PURGE_ENV" = true ]; then
    if [ -f "$SCRIPT_DIR/.env" ]; then
        rm -f "$SCRIPT_DIR/.env"
        echo -e "${YELLOW}   ⚠️ Deleted configuration file (.env).${NC}"
    fi
else
    echo -e "${GREEN}   ✅ Preserved configuration file at: $SCRIPT_DIR/.env${NC}"
fi

# 9. Clean up runtime status and logs
rm -f "$SCRIPT_DIR/upgrade.status" "$SCRIPT_DIR/upgrade.lock" 2>/dev/null || true

echo -e "\n${GREEN}${BOLD}======================================================================${NC}"
echo -e "${GREEN}${BOLD}   🎉 VPS-INFRA-CLIENT SERVICES CLEANLY UNINSTALLED${NC}"
echo -e "${GREEN}${BOLD}======================================================================${NC}"
if [ "$PURGE_DATA" = false ] && [ "$PURGE_ENV" = false ]; then
    echo -e "${BOLD}Database and configurations have been preserved.${NC}"
    echo -e "To perform a clean reinstall at any time, simply run:"
    echo -e "   ${CYAN}bash setup.sh${NC}"
elif [ "$PURGE_DATA" = true ]; then
    echo -e "${YELLOW}All persistent databases, uploads, and registry data have been permanently removed.${NC}"
    echo -e "To configure and install from scratch:"
    echo -e "   ${CYAN}cp .env.example .env && nano .env && bash setup.sh${NC}"
fi
echo ""
