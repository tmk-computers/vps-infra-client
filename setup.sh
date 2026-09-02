#!/bin/bash
# ==============================================================================
# 🚀 VPS-INFRA-CLIENT: ZERO-TOUCH ENTERPRISE RUNTIME DEPLOYMENT SCRIPT
# ==============================================================================
set -e

GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BOLD='\033[1m'
NC='\033[0m' # No Color

echo -e "${CYAN}${BOLD}"
echo "======================================================================"
echo "   🚀 VPS-INFRA-CLIENT: MANAGED DEVOPS & CI/CD RUNTIME SETUP"
echo "======================================================================"
echo -e "${NC}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# 1. Check Docker & Docker Compose
echo -e "${CYAN}▶ Checking Docker prerequisites...${NC}"
if ! command -v docker &> /dev/null; then
    echo -e "${RED}❌ Docker is not installed. Please install Docker first.${NC}"
    exit 1
fi

if ! docker compose version &> /dev/null; then
    echo -e "${RED}❌ Docker Compose (v2) is not installed.${NC}"
    exit 1
fi
echo -e "${GREEN}✅ Docker & Docker Compose detected.${NC}"

# Parse optional CLI arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --license) TMK_ARG_LICENSE="$2"; shift ;;
        --tag) TMK_ARG_TAG="$2"; shift ;;
        *) echo "Unknown parameter: $1";;
    esac
    shift
done

# 2. Check or Create .env configuration
if [ ! -f "$SCRIPT_DIR/.env" ]; then
    echo -e "${YELLOW}⚠️  No .env file found. Creating one from .env.example...${NC}"
    cp "$SCRIPT_DIR/.env.example" "$SCRIPT_DIR/.env"
    echo -e "${YELLOW}👉 Please review and edit '.env' with your domain, credentials, and TMK_LICENSE_KEY.${NC}"
fi

if [ -n "$TMK_ARG_TAG" ]; then
    echo -e "${CYAN}▶ Applying container image tag override: ${TMK_ARG_TAG}...${NC}"
    sed -i "s|^DEVOPS_API_IMAGE=.*|DEVOPS_API_IMAGE=ghcr.io/tmk-computers/tmk-devops-api:${TMK_ARG_TAG}|" "$SCRIPT_DIR/.env" || true
    sed -i "s|^DEVOPS_WEB_IMAGE=.*|DEVOPS_WEB_IMAGE=ghcr.io/tmk-computers/tmk-devops-web:${TMK_ARG_TAG}|" "$SCRIPT_DIR/.env" || true
    sed -i "s|^CI_API_IMAGE=.*|CI_API_IMAGE=ghcr.io/tmk-computers/tmk-ci-api:${TMK_ARG_TAG}|" "$SCRIPT_DIR/.env" || true
    sed -i "s|^CI_WEB_IMAGE=.*|CI_WEB_IMAGE=ghcr.io/tmk-computers/tmk-ci-web:${TMK_ARG_TAG}|" "$SCRIPT_DIR/.env" || true
    echo -e "${GREEN}✅ Configured container images to use tag '${TMK_ARG_TAG}'.${NC}"
fi

if [ -n "$TMK_ARG_LICENSE" ]; then
    TMK_ARG_LICENSE=$(echo "$TMK_ARG_LICENSE" | sed -e 's/^[[:space:]"'\''"]*//' -e 's/[[:space:]"'\''"]*$//')
    if grep -q "^TMK_LICENSE_KEY=" "$SCRIPT_DIR/.env"; then
        sed -i 's|^TMK_LICENSE_KEY=.*|TMK_LICENSE_KEY="'"$TMK_ARG_LICENSE"'"|' "$SCRIPT_DIR/.env"
    else
        echo "TMK_LICENSE_KEY=\"$TMK_ARG_LICENSE\"" >> "$SCRIPT_DIR/.env"
    fi
    echo -e "${GREEN}✅ Configured TMK_LICENSE_KEY from --license argument.${NC}"
fi

# 3. Safely load and export .env variables
if [ -f "$SCRIPT_DIR/.env" ]; then
    while IFS= read -r line || [ -n "$line" ]; do
        trimmed_line=$(echo "$line" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
        [[ -z "$trimmed_line" || "$trimmed_line" =~ ^# ]] && continue
        if [[ "$trimmed_line" =~ ^([A-Za-z_][A-Za-z0-9_]*)=(.*)$ ]]; then
            key="${BASH_REMATCH[1]}"
            val="${BASH_REMATCH[2]}"
            val="${val%\"}"
            val="${val#\"}"
            val="${val%\'}"
            val="${val#\'}"
            export "$key=$val"
        fi
    done < "$SCRIPT_DIR/.env"
fi

# 4. Create external Docker network
echo -e "${CYAN}▶ Ensuring 'traefik_net' Docker network exists...${NC}"
if ! docker network inspect traefik_net &> /dev/null; then
    docker network create traefik_net
    echo -e "${GREEN}✅ Created external network 'traefik_net'.${NC}"
else
    echo -e "${GREEN}✅ Network 'traefik_net' is already present.${NC}"
fi

# 5. Scaffold Persistent Volume Directories
echo -e "${CYAN}▶ Scaffolding persistent volume directories...${NC}"
mkdir -p \
    "$SCRIPT_DIR/volumes/apps" \
    "$SCRIPT_DIR/volumes/artifacts/builds" \
    "$SCRIPT_DIR/volumes/apk" \
    "$SCRIPT_DIR/volumes/db/postgres/data" \
    "$SCRIPT_DIR/volumes/db/postgres/backups" \
    "$SCRIPT_DIR/volumes/db/pgadmin" \
    "$SCRIPT_DIR/volumes/infra/registry" \
    "$SCRIPT_DIR/volumes/infra/backups" \
    "$SCRIPT_DIR/network/traefik"

# Crucial Docker Safeguard: Pre-create license.key as a regular file before Docker bind-mounts it
if [ -d "$SCRIPT_DIR/volumes/license.key" ]; then
    rm -rf "$SCRIPT_DIR/volumes/license.key"
fi
if [ ! -f "$SCRIPT_DIR/volumes/license.key" ]; then
    if [ -n "$TMK_LICENSE_KEY" ]; then
        echo "$TMK_LICENSE_KEY" > "$SCRIPT_DIR/volumes/license.key"
    else
        touch "$SCRIPT_DIR/volumes/license.key"
    fi
    chmod 644 "$SCRIPT_DIR/volumes/license.key"
fi
echo -e "${GREEN}✅ Volume license.key secured as regular file mount.${NC}"

# 6. Prepare Traefik SSL Certificate Storage & Dashboard Auth
if [ ! -f "$SCRIPT_DIR/network/traefik/acme.json" ]; then
    touch "$SCRIPT_DIR/network/traefik/acme.json"
fi
chmod 600 "$SCRIPT_DIR/network/traefik/acme.json"

if [ ! -f "$SCRIPT_DIR/network/traefik/users.htpasswd" ]; then
    echo "admin:\$2y\$05\$LcKxE/OkQYg7D2UPBkedkOO./SILLHS6GW04OS3B/.urSdR7bmPnW" > "$SCRIPT_DIR/network/traefik/users.htpasswd"
fi
chmod 600 "$SCRIPT_DIR/network/traefik/users.htpasswd"
echo -e "${GREEN}✅ Traefik acme.json & users.htpasswd secured (chmod 600).${NC}"

# 7. Start Core Infrastructure Services
echo -e "\n${CYAN}▶ Starting Reverse Proxy (Traefik)...${NC}"
docker compose -f "$SCRIPT_DIR/network/traefik/docker-compose.yml" --env-file "$SCRIPT_DIR/.env" up -d

echo -e "\n${CYAN}▶ Starting Shared PostgreSQL & pgAdmin...${NC}"
docker compose -f "$SCRIPT_DIR/db/postgres/docker-compose.yml" --env-file "$SCRIPT_DIR/.env" up -d

echo -e "\n${CYAN}▶ Starting Private Docker Registry...${NC}"
docker compose -f "$SCRIPT_DIR/docker-registry/docker-compose.yml" --env-file "$SCRIPT_DIR/.env" up -d

echo -e "\n${CYAN}▶ Pulling and Starting Managed Platform Services (DevOps & CI)...${NC}"
docker compose -f "$SCRIPT_DIR/docker-compose.yml" --env-file "$SCRIPT_DIR/.env" up -d

# 8. Print Completion Summary
echo -e "\n${GREEN}${BOLD}======================================================================${NC}"
echo -e "${GREEN}${BOLD}   🎉 VPS-INFRA RUNTIME DEPLOYED SUCCESSFULLY!${NC}"
echo -e "${GREEN}${BOLD}======================================================================${NC}"
echo -e "${BOLD}Company / Organization:${NC}  ${COMPANY_NAME:-Custom Organization}"
echo -e "${BOLD}Primary Domain:${NC}          ${PRIMARY_DOMAIN:-example.com}"
echo ""
echo -e "${BOLD}🌐 Platform Access Endpoints:${NC}"
echo -e "  • DevOps Manager Panel:  ${CYAN}https://${DEVOPS_WEB_HOST:-devops.example.com}${NC}"
echo -e "  • DevOps REST API:       ${CYAN}https://${DEVOPS_API_HOST:-devops-api.example.com}${NC}"
echo -e "  • CI/CD Dashboard:       ${CYAN}https://${CI_WEB_HOST:-ci.example.com}${NC}"
echo -e "  • CI/CD API & Artifacts: ${CYAN}https://${CI_API_HOST:-ci-api.example.com}${NC}"
echo -e "  • Private Registry:      ${CYAN}https://${REGISTRY_HOST:-registry.example.com}${NC}"
echo -e "  • pgAdmin Web:           ${CYAN}https://${PGADMIN_HOST:-pgadmin.example.com}${NC}"
echo -e "  • Traefik Dashboard:     ${CYAN}https://${TRAEFIK_DASHBOARD_HOST:-traefik.example.com}${NC}"
echo ""
echo -e "${BOLD}🔑 Initial Administrator Access:${NC}"
echo -e "  • SuperAdmin Email:      ${YELLOW}${SUPERADMIN_EMAIL:-admin@example.com}${NC}"
echo -e "  • SuperAdmin Password:   ${YELLOW}${SUPERADMIN_PASSWORD:-[Configured in .env]}${NC}"
echo ""
echo -e "${BOLD}💡 Next Steps:${NC}"
echo "  1. Point your domain DNS A-records to this VPS public IP."
echo "  2. Log in to the DevOps Manager to register your Products & microservices."
echo "  3. Use templates in '$SCRIPT_DIR/templates' for new service deployments."
echo -e "${GREEN}======================================================================${NC}\n"
