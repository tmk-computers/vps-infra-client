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

# Return success when the requested TCP port has an active listener.
is_port_in_use() {
    local port="$1"
    ss -H -ltn "sport = :$port" 2>/dev/null | grep -q .
}

# Match actual host port bindings and this installation's Compose identity.
# Compose metadata also recognizes containers created before our role label existed.
is_our_traefik_port() {
    local port="$1" containers container metadata bindings role service directory configs
    local found=false
    containers=$(docker ps -q) || return 1
    for container in $containers; do
        bindings=$(docker inspect --format '{{range $port, $bindings := .NetworkSettings.Ports}}{{range $bindings}}{{println .HostPort}}{{end}}{{end}}' "$container") || return 1
        if ! grep -qx "$port" <<< "$bindings"; then
            continue
        fi
        metadata=$(docker inspect --format '{{index .Config.Labels "com.tmk.vps-infra.role"}}|{{index .Config.Labels "com.docker.compose.service"}}|{{index .Config.Labels "com.docker.compose.project.working_dir"}}|{{index .Config.Labels "com.docker.compose.project.config_files"}}' "$container") || return 1
        IFS='|' read -r role service directory configs <<< "$metadata"
        [[ "$service" == traefik && "$directory" == "$SCRIPT_DIR/network/traefik" && "$configs" == "$SCRIPT_DIR/network/traefik/docker-compose.yml" ]] || return 1
        case "$role" in
            reverse-proxy|''|'<no value>') ;;
            *) return 1 ;;
        esac
        found=true
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

    if [ ! -r /dev/tty ]; then
        echo -e "${RED}❌ User confirmation is required, but no interactive terminal is available.${NC}"
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

echo "$SCRIPT_DIR"

echo -e "\n${CYAN}▶ Starting Shared PostgreSQL & pgAdmin...${NC}"
docker compose -f "$SCRIPT_DIR/db/postgres/docker-compose.yml" --env-file "$SCRIPT_DIR/.env" up -d

echo -e "\n${CYAN}▶ Starting Private Docker Registry...${NC}"
docker compose -f "$SCRIPT_DIR/docker-registry/docker-compose.yml" --env-file "$SCRIPT_DIR/.env" up -d

echo -e "\n${CYAN}▶ Pulling and Starting Managed Platform Services (DevOps & CI)...${NC}"
docker compose -f "$SCRIPT_DIR/docker-compose.yml" --env-file "$SCRIPT_DIR/.env" up -d

# 8. Print Completion Summary
echo -e "\n${GREEN}${BOLD}======================================================================${NC}"
echo -e "${GREEN}${BOLD}   VPS-INFRA CONTAINERS STARTED${NC}"
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
echo "  1. Verify DNS points to this VPS and HTTPS certificates are issued before logging in."
echo "  2. Log in to the DevOps Manager to register your Products & microservices."
echo "  3. Use templates in '$SCRIPT_DIR/templates' for new service deployments."
echo -e "${GREEN}======================================================================${NC}\n"
