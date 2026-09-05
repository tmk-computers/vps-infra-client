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
TMK_ARG_MODE=""
TMK_ARG_REGISTRY_TYPE=""
TMK_ARG_REGISTRY_HOST=""
TMK_ARG_REGISTRY_USER=""
TMK_ARG_REGISTRY_PASS=""
TMK_ARG_SYNC_MODE=""
TMK_ARG_CI_SECRET=""

while [[ "$#" -gt 0 ]]; do
    case $1 in
        --license) TMK_ARG_LICENSE="$2"; shift ;;
        --tag) TMK_ARG_TAG="$2"; shift ;;
        --mode) TMK_ARG_MODE="$2"; shift ;;
        --registry-type) TMK_ARG_REGISTRY_TYPE="$2"; shift ;;
        --registry-host) TMK_ARG_REGISTRY_HOST="$2"; shift ;;
        --registry-user) TMK_ARG_REGISTRY_USER="$2"; shift ;;
        --registry-pass) TMK_ARG_REGISTRY_PASS="$2"; shift ;;
        --sync-mode) TMK_ARG_SYNC_MODE="$2"; shift ;;
        --ci-secret) TMK_ARG_CI_SECRET="$2"; shift ;;
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

set_env_val() {
    local key="$1"
    local val="$2"
    if grep -q "^${key}=" "$SCRIPT_DIR/.env"; then
        sed -i "s|^${key}=.*|${key}=\"${val}\"|" "$SCRIPT_DIR/.env"
    else
        echo "${key}=\"${val}\"" >> "$SCRIPT_DIR/.env"
    fi
    export "${key}=${val}"
}

# Interactive Topology Selection if not supplied via CLI or existing env
if [ -n "$TMK_ARG_MODE" ]; then
    DEPLOYMENT_MODE="$TMK_ARG_MODE"
elif [ -z "$DEPLOYMENT_MODE" ] && [ -t 0 ]; then
    echo -e "\n${CYAN}======================================================================${NC}"
    echo -e "${CYAN}${BOLD}   🌐 SELECT DEPLOYMENT TOPOLOGY${NC}"
    echo -e "${CYAN}======================================================================${NC}"
    echo "1) All-in-One          : DevOps Manager + CI Server + Registry + PostgreSQL on ONE VPS (Default)"
    echo "2) DevOps Manager Only : Production / App Host (DevOps Panel, DB, Apps, Traefik)"
    echo "3) CI Server Only      : Dedicated Build Machine (Build Runner, Artifacts, Docker Engine)"
    read -rp "Enter choice [1-3, default: 1]: " TOPOLOGY_CHOICE
    case "$TOPOLOGY_CHOICE" in
        2) DEPLOYMENT_MODE="devops-only" ;;
        3) DEPLOYMENT_MODE="ci-only" ;;
        *) DEPLOYMENT_MODE="all-in-one" ;;
    esac
fi

DEPLOYMENT_MODE="${DEPLOYMENT_MODE:-all-in-one}"
set_env_val "DEPLOYMENT_MODE" "$DEPLOYMENT_MODE"

case "$DEPLOYMENT_MODE" in
    devops-only)
        COMPOSE_PROFILES="devops"
        ;;
    ci-only)
        COMPOSE_PROFILES="ci"
        ;;
    *)
        DEPLOYMENT_MODE="all-in-one"
        COMPOSE_PROFILES="all"
        ;;
esac
set_env_val "COMPOSE_PROFILES" "$COMPOSE_PROFILES"
echo -e "${GREEN}✅ Active Deployment Topology: ${BOLD}${DEPLOYMENT_MODE}${NC} (Profiles: ${COMPOSE_PROFILES})"

# Registry Configuration
if [ -n "$TMK_ARG_REGISTRY_TYPE" ]; then
    set_env_val "DOCKER_REGISTRY_TYPE" "$TMK_ARG_REGISTRY_TYPE"
fi
if [ -n "$TMK_ARG_REGISTRY_HOST" ]; then
    set_env_val "DOCKER_REGISTRY_HOST" "$TMK_ARG_REGISTRY_HOST"
fi
if [ -n "$TMK_ARG_REGISTRY_USER" ]; then
    set_env_val "DOCKER_REGISTRY_USER" "$TMK_ARG_REGISTRY_USER"
fi
if [ -n "$TMK_ARG_REGISTRY_PASS" ]; then
    set_env_val "DOCKER_REGISTRY_PASSWORD" "$TMK_ARG_REGISTRY_PASS"
fi

# CI Synchronization Configuration
if [ -n "$TMK_ARG_SYNC_MODE" ]; then
    set_env_val "SYNC_MODE" "$TMK_ARG_SYNC_MODE"
elif [ -z "$SYNC_MODE" ]; then
    set_env_val "SYNC_MODE" "api"
fi

if [ -n "$TMK_ARG_CI_SECRET" ]; then
    set_env_val "CI_SECRET" "$TMK_ARG_CI_SECRET"
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
    set_env_val "TMK_LICENSE_KEY" "$TMK_ARG_LICENSE"
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

# Registry Authentication if credentials provided
if [ -n "${DOCKER_REGISTRY_USER:-}" ] && [ -n "${DOCKER_REGISTRY_PASSWORD:-}" ]; then
    REG_TARGET="${DOCKER_REGISTRY_HOST:-${REGISTRY_HOST:-}}"
    if [ -n "$REG_TARGET" ]; then
        echo -e "${CYAN}▶ Authenticating Docker with registry ${REG_TARGET}...${NC}"
        echo "$DOCKER_REGISTRY_PASSWORD" | docker login "$REG_TARGET" -u "$DOCKER_REGISTRY_USER" --password-stdin || {
            echo -e "${YELLOW}⚠️ Docker login failed. Please verify your registry credentials.${NC}"
        }
    fi
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
echo -e "${CYAN}▶ Scaffolding persistent volume directories for [${DEPLOYMENT_MODE}]...${NC}"
mkdir -p \
    "$SCRIPT_DIR/volumes/apps" \
    "$SCRIPT_DIR/volumes/artifacts/builds" \
    "$SCRIPT_DIR/volumes/apk" \
    "$SCRIPT_DIR/network/traefik"

if [ "$DEPLOYMENT_MODE" != "ci-only" ]; then
    mkdir -p \
        "$SCRIPT_DIR/volumes/db/postgres/data" \
        "$SCRIPT_DIR/volumes/db/postgres/backups" \
        "$SCRIPT_DIR/volumes/db/pgadmin" \
        "$SCRIPT_DIR/volumes/infra/backups"
fi

if [ "${DOCKER_REGISTRY_TYPE:-private}" = "private" ] && [ "$DEPLOYMENT_MODE" != "devops-only" ]; then
    mkdir -p "$SCRIPT_DIR/volumes/infra/registry"
fi

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

# 7. Start Infrastructure Services Conditionally Based on Topology
echo -e "\n${CYAN}▶ Starting Reverse Proxy (Traefik)...${NC}"
docker compose -f "$SCRIPT_DIR/network/traefik/docker-compose.yml" --env-file "$SCRIPT_DIR/.env" up -d

if [ "$DEPLOYMENT_MODE" != "ci-only" ]; then
    echo -e "\n${CYAN}▶ Starting Shared PostgreSQL & pgAdmin...${NC}"
    docker compose -f "$SCRIPT_DIR/db/postgres/docker-compose.yml" --env-file "$SCRIPT_DIR/.env" up -d
else
    echo -e "\n${YELLOW}▶ Skipping local PostgreSQL (Topology: ci-only; using REST API sync to DevOps Manager).${NC}"
fi

if [ "${DOCKER_REGISTRY_TYPE:-private}" = "private" ] && [ "$DEPLOYMENT_MODE" != "devops-only" ]; then
    echo -e "\n${CYAN}▶ Starting Private Docker Registry...${NC}"
    docker compose -f "$SCRIPT_DIR/docker-registry/docker-compose.yml" --env-file "$SCRIPT_DIR/.env" up -d
elif [ "${DOCKER_REGISTRY_TYPE:-}" = "external" ]; then
    echo -e "\n${YELLOW}▶ Skipping local Docker Registry container (Using External Registry: ${DOCKER_REGISTRY_HOST:-$REGISTRY_HOST}).${NC}"
fi

# Detect compose file
if [ -f "$SCRIPT_DIR/docker-compose.yml" ]; then
    COMPOSE_FILE="$SCRIPT_DIR/docker-compose.yml"
elif [ -f "$SCRIPT_DIR/docker-compose.uat.yml" ]; then
    COMPOSE_FILE="$SCRIPT_DIR/docker-compose.uat.yml"
fi

echo -e "\n${CYAN}▶ Pulling and Starting Platform Services (Profile: ${COMPOSE_PROFILES})...${NC}"
docker compose -f "$COMPOSE_FILE" --profile "$COMPOSE_PROFILES" --env-file "$SCRIPT_DIR/.env" up -d

# 8. Print Completion Summary
echo -e "\n${GREEN}${BOLD}======================================================================${NC}"
echo -e "${GREEN}${BOLD}   🎉 VPS-INFRA [${DEPLOYMENT_MODE^^}] DEPLOYED SUCCESSFULLY!${NC}"
echo -e "${GREEN}${BOLD}======================================================================${NC}"
echo -e "${BOLD}Topology Mode:${NC}           ${CYAN}${DEPLOYMENT_MODE}${NC} (Profiles: ${COMPOSE_PROFILES})"
echo -e "${BOLD}Registry Mode:${NC}           ${CYAN}${DOCKER_REGISTRY_TYPE:-private}${NC} (${DOCKER_REGISTRY_HOST:-${REGISTRY_HOST:-localhost:5000}})"
echo -e "${BOLD}Sync Mode:${NC}               ${CYAN}${SYNC_MODE:-api}${NC}"
echo -e "${BOLD}Company / Organization:${NC}  ${COMPANY_NAME:-Custom Organization}"
echo -e "${BOLD}Primary Domain:${NC}          ${PRIMARY_DOMAIN:-example.com}"
echo ""
echo -e "${BOLD}🌐 Active Endpoints for this Node:${NC}"

if [ "$DEPLOYMENT_MODE" != "ci-only" ]; then
    echo -e "  • DevOps Manager Panel:  ${CYAN}https://${DEVOPS_WEB_HOST:-devops.example.com}${NC}"
    echo -e "  • DevOps REST API:       ${CYAN}https://${DEVOPS_API_HOST:-devops-api.example.com}${NC}"
    echo -e "  • pgAdmin Web:           ${CYAN}https://${PGADMIN_HOST:-pgadmin.example.com}${NC}"
fi

if [ "$DEPLOYMENT_MODE" != "devops-only" ]; then
    echo -e "  • CI/CD Dashboard:       ${CYAN}https://${CI_WEB_HOST:-ci.example.com}${NC}"
    echo -e "  • CI/CD API & Artifacts: ${CYAN}https://${CI_API_HOST:-ci-api.example.com}${NC}"
    if [ "${DOCKER_REGISTRY_TYPE:-private}" = "private" ]; then
        echo -e "  • Private Registry:      ${CYAN}https://${REGISTRY_HOST:-registry.example.com}${NC}"
    fi
fi

echo -e "  • Traefik Dashboard:     ${CYAN}https://${TRAEFIK_DASHBOARD_HOST:-traefik.example.com}${NC}"
echo ""

if [ "$DEPLOYMENT_MODE" != "ci-only" ]; then
    echo -e "${BOLD}🔑 Initial Administrator Access:${NC}"
    echo -e "  • SuperAdmin Email:      ${YELLOW}${SUPERADMIN_EMAIL:-admin@example.com}${NC}"
    echo -e "  • SuperAdmin Password:   ${YELLOW}${SUPERADMIN_PASSWORD:-[Configured in .env]}${NC}"
    echo ""
fi

echo -e "${BOLD}💡 Next Steps:${NC}"
if [ "$DEPLOYMENT_MODE" = "ci-only" ]; then
    echo "  1. Verify connection to DevOps Manager via DEVOPS_API_URL and CI_SECRET."
    echo "  2. Run builds from the CI Dashboard or trigger via DevOps Webhook."
elif [ "$DEPLOYMENT_MODE" = "devops-only" ]; then
    echo "  1. Configure CI_SECRET in .env to match the remote CI Server."
    echo "  2. Point application domain DNS A-records to this host."
    echo "  3. Log in to DevOps Manager to deploy application microservices."
else
    echo "  1. Point your domain DNS A-records to this VPS public IP."
    echo "  2. Log in to the DevOps Manager to register your Products & microservices."
    echo "  3. Use templates in '$SCRIPT_DIR/templates' for new service deployments."
fi
echo -e "${GREEN}======================================================================${NC}\n"
