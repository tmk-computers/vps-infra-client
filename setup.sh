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

# 1.1 Configure Docker Log Rotation & Maintenance Crons
configure_docker_log_rotation_and_maintenance() {
    echo -e "\n${CYAN}▶ Checking Docker log rotation and automated maintenance crons...${NC}"
    
    # 1. Configure Docker daemon log rotation if missing
    if [ ! -f /etc/docker/daemon.json ]; then
        if [ "$EUID" -eq 0 ] || command -v sudo &> /dev/null; then
            echo -e "   • Setting up /etc/docker/daemon.json (max-size: 50m, max-file: 3)..."
            sudo mkdir -p /etc/docker
            sudo tee /etc/docker/daemon.json > /dev/null << 'EOF'
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "50m",
    "max-file": "3"
  }
}
EOF
            sudo systemctl reload docker 2>/dev/null || true
            echo -e "${GREEN}   ✅ Docker daemon log rotation configured.${NC}"
        fi
    else
        echo -e "${GREEN}   ✅ Docker daemon log rotation already configured.${NC}"
    fi

    # 2. Configure system maintenance cron
    if [ -d /etc/cron.d ] && { [ "$EUID" -eq 0 ] || command -v sudo &> /dev/null; }; then
        if [ ! -f /etc/cron.d/docker-maintenance ]; then
            echo -e "   • Setting up /etc/cron.d/docker-maintenance..."
            sudo tee /etc/cron.d/docker-maintenance > /dev/null << 'EOF'
# Daily Docker builder prune keeping 2GB cache
30 3 * * * root docker builder prune -af --reserved-space 2GB > /dev/null 2>&1
# Daily Local Registry tag prune
15 3 * * * root /usr/bin/python3 /var/www/vps-infra/scripts/prune_registry.py > /dev/null 2>&1
EOF
            sudo chmod 644 /etc/cron.d/docker-maintenance
            echo -e "${GREEN}   ✅ Daily maintenance cron configured.${NC}"
        else
            echo -e "${GREEN}   ✅ /etc/cron.d/docker-maintenance already configured.${NC}"
        fi
    fi

    if [ -f "$SCRIPT_DIR/scripts/prune_registry.py" ]; then
        chmod +x "$SCRIPT_DIR/scripts/prune_registry.py"
    fi
}

configure_docker_log_rotation_and_maintenance

# Parse optional CLI arguments
TMK_ARG_MODE=""
TMK_ARG_REGISTRY_TYPE=""
TMK_ARG_REGISTRY_HOST=""
TMK_ARG_REGISTRY_USER=""
TMK_ARG_REGISTRY_PASS=""
TMK_ARG_SYNC_MODE=""
TMK_ARG_CI_SECRET=""

while [[ "$#" -gt 0 ]]; do
    case "$1" in
        --license)
            if [[ "$#" -lt 2 || -z "$2" || "$2" == --* ]]; then
                echo -e "${RED}❌ --license requires a value.${NC}"
                exit 1
            fi
            TMK_ARG_LICENSE="$2"
            shift 2
            ;;
        --tag)
            if [[ "$#" -lt 2 || -z "$2" || "$2" == --* ]]; then
                echo -e "${RED}❌ --tag requires a value.${NC}"
                exit 1
            fi
            TMK_ARG_TAG="$2"
            shift 2
            ;;
        --domain)
            if [[ "$#" -lt 2 || -z "$2" || "$2" == --* ]]; then
                echo -e "${RED}❌ --domain requires a value.${NC}"
                exit 1
            fi
            TMK_ARG_DOMAIN="$2"
            shift 2
            ;;
        -y|--yes|--force)
            TMK_ARG_YES=true
            shift 1
            ;;
        --mode)
            TMK_ARG_MODE="$2"
            shift 2
            ;;
        --registry-type)
            TMK_ARG_REGISTRY_TYPE="$2"
            shift 2
            ;;
        --registry-host)
            TMK_ARG_REGISTRY_HOST="$2"
            shift 2
            ;;
        --registry-user)
            TMK_ARG_REGISTRY_USER="$2"
            shift 2
            ;;
        --registry-pass)
            TMK_ARG_REGISTRY_PASS="$2"
            shift 2
            ;;
        --sync-mode)
            TMK_ARG_SYNC_MODE="$2"
            shift 2
            ;;
        --ci-secret)
            TMK_ARG_CI_SECRET="$2"
            shift 2
            ;;
        *)
            echo -e "${RED}❌ Unknown parameter: $1${NC}"
            exit 1
            ;;
    esac
done

# 2. Check or Create .env configuration
if [ ! -f "$SCRIPT_DIR/.env" ]; then
    echo -e "${YELLOW}⚠️  No .env file found. Creating one from .env.example...${NC}"
    cp "$SCRIPT_DIR/.env.example" "$SCRIPT_DIR/.env"
    echo -e "${YELLOW}👉 Setup will configure routing domains; review credentials and TMK_LICENSE_KEY in '.env'.${NC}"
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

if [ -n "${TMK_ARG_TAG:-}" ]; then
    echo -e "${CYAN}▶ Applying container image tag override: ${TMK_ARG_TAG}...${NC}"
    sed -i "s|^DEVOPS_API_IMAGE=.*|DEVOPS_API_IMAGE=ghcr.io/tmk-computers/tmk-devops-api:${TMK_ARG_TAG}|" "$SCRIPT_DIR/.env" || true
    sed -i "s|^DEVOPS_WEB_IMAGE=.*|DEVOPS_WEB_IMAGE=ghcr.io/tmk-computers/tmk-devops-web:${TMK_ARG_TAG}|" "$SCRIPT_DIR/.env" || true
    sed -i "s|^CI_API_IMAGE=.*|CI_API_IMAGE=ghcr.io/tmk-computers/tmk-ci-api:${TMK_ARG_TAG}|" "$SCRIPT_DIR/.env" || true
    sed -i "s|^CI_WEB_IMAGE=.*|CI_WEB_IMAGE=ghcr.io/tmk-computers/tmk-ci-web:${TMK_ARG_TAG}|" "$SCRIPT_DIR/.env" || true
    echo -e "${GREEN}✅ Configured container images to use tag '${TMK_ARG_TAG}'.${NC}"
fi

if [ -n "${TMK_ARG_LICENSE:-}" ]; then
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

# Resolve placeholder hostnames before creating or starting any infrastructure.
source "$SCRIPT_DIR/scripts/configure-domains.sh"
configure_domains

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
    if [ -n "${TMK_LICENSE_KEY:-}" ]; then
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
# Return success when the requested TCP port has an active listener.
is_port_in_use() {
    local port="$1"
    ss -H -ltn "sport = :$port" 2>/dev/null | grep -q .
}

# Match actual host port bindings and this installation's Compose identity.
# Compose metadata also recognizes containers created before our role label existed.
is_our_traefik_port() {
    local port="$1" containers container metadata bindings role service name
    local found=false
    containers=$(docker ps -q) || return 1
    for container in $containers; do
        bindings=$(docker inspect --format '{{range $port, $bindings := .NetworkSettings.Ports}}{{range $bindings}}{{println .HostPort}}{{end}}{{end}}' "$container" 2>/dev/null) || return 1
        if ! grep -qx "$port" <<< "$bindings"; then
            continue
        fi
        name=$(docker inspect --format '{{.Name}}' "$container" 2>/dev/null | sed 's|^/||')
        if [[ "$name" == "traefik_global" ]]; then
            found=true
            continue
        fi
        metadata=$(docker inspect --format '{{index .Config.Labels "com.tmk.vps-infra.role"}}|{{index .Config.Labels "com.docker.compose.service"}}' "$container" 2>/dev/null) || return 1
        IFS='|' read -r role service <<< "$metadata"
        if [[ "$service" == "traefik" || "$role" == "reverse-proxy" ]]; then
            found=true
            continue
        fi
        return 1
    done
    [[ "$found" == true ]]
}

# Display both system-process and Docker-container ownership information.
show_port_owner() {
    local port="$1"
    local containers

    echo -e "${YELLOW}Port ${port} ownership details:${NC}"
    sudo ss -H -ltnp "sport = :$port" 2>/dev/null || true

    containers="$(
        docker ps \
            --filter "publish=$port" \
            --format '  Container: {{.Names}} | Image: {{.Image}} | Ports: {{.Ports}}'
    )"

    if [ -n "$containers" ]; then
        echo "$containers"
    fi
}

# Identify supported host web servers. Unknown workloads are never stopped.
detect_system_web_server() {
    local port="$1"
    local process_info

    process_info="$(sudo ss -H -ltnp "sport = :$port" 2>/dev/null || true)"

    case "$process_info" in
        *nginx*)   echo "nginx" ;;
        *apache2*) echo "apache2" ;;
        *httpd*)   echo "httpd" ;;
        *caddy*)   echo "caddy" ;;
        *)         return 1 ;;
    esac
}

# Ask for permission before releasing ports 80/443 for Traefik.
prepare_traefik_ports() {
    local conflicting_ports=()
    local services_to_stop=()
    local unsupported_conflict=false
    local port
    local service
    local answer

    if ! command -v ss &> /dev/null; then
        echo -e "${RED}❌ The 'ss' command is required to inspect ports 80 and 443.${NC}"
        exit 1
    fi

    echo -e "${CYAN}▶ Checking ports required by Traefik...${NC}"

    for port in 80 443; do
        if is_port_in_use "$port"; then
            if is_our_traefik_port "$port"; then
                echo -e "${GREEN}✅ Port $port is already owned by this installation's Traefik.${NC}"
                continue
            fi
            conflicting_ports+=("$port")
            echo -e "${YELLOW}⚠️  Port $port is already in use.${NC}"
            show_port_owner "$port"

            service="$(detect_system_web_server "$port" || true)"
            if [ -n "$service" ]; then
                if [[ " ${services_to_stop[*]} " != *" $service "* ]]; then
                    services_to_stop+=("$service")
                fi
            else
                unsupported_conflict=true
            fi
        else
            echo -e "${GREEN}✅ Port $port is available.${NC}"
        fi
    done

    if [ "${#conflicting_ports[@]}" -eq 0 ]; then
        echo -e "${GREEN}✅ Ports 80 and 443 are available or already owned by this installation's Traefik.${NC}"
        return 0
    fi

    echo ""
    echo -e "${YELLOW}${BOLD}Traefik requires host ports 80 and 443.${NC}"
    echo "These ports receive HTTP and HTTPS traffic from the internet."
    echo "Traefik cannot start while another service owns either port."
    echo ""

    if [ "$unsupported_conflict" = true ]; then
        echo -e "${RED}❌ At least one required port is owned by an unsupported process or Docker container.${NC}"
        echo "For safety, this script will not stop an unidentified workload."
        echo "Stop or reconfigure the workload shown above, and then rerun this script."
        exit 1
    fi

    echo -e "${YELLOW}Detected web service(s): ${services_to_stop[*]}${NC}"
    echo -e "${RED}Warning: stopping these services may make existing websites unavailable.${NC}"
    echo ""

    if [[ "${TMK_ARG_YES:-false}" != "true" ]]; then
        if [ ! -r /dev/tty ]; then
            echo -e "${RED}❌ User confirmation is required, but no interactive terminal is available.${NC}"
            echo -e "   Pass --yes to automatically approve stopping detected web services."
            exit 1
        fi

        read -r -p "May this script stop these services and assign ports 80/443 to Traefik? [y/N]: " answer < /dev/tty

        case "$answer" in
            y|Y|yes|YES|Yes)
                ;;
            *)
                echo -e "${RED}❌ Permission was not granted.${NC}"
                echo "Deployment stopped without changing the existing web services."
                exit 1
                ;;
        esac
    fi

    for service in "${services_to_stop[@]}"; do
        echo -e "${YELLOW}▶ Stopping $service...${NC}"
        if ! sudo systemctl stop "$service"; then
            echo -e "${RED}❌ Failed to stop $service.${NC}"
            exit 1
        fi
        echo -e "${GREEN}✅ Stopped $service.${NC}"
    done

    for port in 80 443; do
        if is_port_in_use "$port" && ! is_our_traefik_port "$port"; then
            echo -e "${RED}❌ Port $port is still occupied.${NC}"
            show_port_owner "$port"
            echo "Traefik cannot start until this port is released."
            exit 1
        fi
    done

    echo -e "${GREEN}✅ Ports 80 and 443 are now available for Traefik.${NC}"
}

# 7. Start Core Infrastructure Services
echo -e "\n${CYAN}▶ Preparing HTTP and HTTPS ports for Traefik...${NC}"
prepare_traefik_ports

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

# Authenticate only after infrastructure startup. Local registry startup may take
# a few seconds; remote registries should already be available.
source "$SCRIPT_DIR/scripts/authenticate-registry.sh"
authenticate_registry

# Detect compose file
if [ -f "$SCRIPT_DIR/docker-compose.yml" ]; then
    COMPOSE_FILE="$SCRIPT_DIR/docker-compose.yml"
elif [ -f "$SCRIPT_DIR/docker-compose.uat.yml" ]; then
    COMPOSE_FILE="$SCRIPT_DIR/docker-compose.uat.yml"
fi

# Ensure PostgreSQL has initialized and is accepting connections before launching application services
if [ "$DEPLOYMENT_MODE" != "ci-only" ]; then
    echo -e "\n${CYAN}▶ Waiting for PostgreSQL to be ready before starting platform services...${NC}"
    for ((attempt = 1; attempt <= 30; attempt++)); do
        if docker exec shared_postgres pg_isready -U "${POSTGRES_USER:-postgres}" -d "${POSTGRES_DB:-devops_prod}" &>/dev/null; then
            echo -e "${GREEN}✅ PostgreSQL is ready and accepting connections.${NC}"
            break
        fi
        sleep 2
    done
fi

echo -e "\n${CYAN}▶ Pulling and Starting Platform Services (Profile: ${COMPOSE_PROFILES})...${NC}"
docker compose -f "$COMPOSE_FILE" --profile "$COMPOSE_PROFILES" --env-file "$SCRIPT_DIR/.env" up -d

# Verify account creation before presenting the configured credentials.
source "$SCRIPT_DIR/scripts/validate-admin.sh"
validate_admin_account

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
    echo -e "${BOLD}🔑 Configured Administrator Credentials:${NC}"
    printf '  • SuperAdmin Email:      %s\n' "${SUPERADMIN_EMAIL:-admin@example.com}"
    printf '  • SuperAdmin Password:   %s\n' "${SUPERADMIN_PASSWORD:-[Configured in .env]}"
    print_admin_validation
    echo ""
    if [[ "$ADMIN_VALIDATION_STATUS" != "found" && "$ADMIN_VALIDATION_STATUS" != "skipped" ]]; then
        echo -e "${YELLOW}⚠️  Note: Initial superadmin account is still initializing or pending migrations.${NC}"
        echo -e "${YELLOW}   Check container status with: docker logs devops-api-prod${NC}"
        echo ""
    fi
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
    echo "  1. Verify DNS points to this VPS and HTTPS certificates are issued before logging in."
    echo "  2. Log in to the DevOps Manager to register your Products & microservices."
    echo "  3. Use templates in '$SCRIPT_DIR/templates' for new service deployments."
fi
echo -e "${GREEN}======================================================================${NC}\n"
