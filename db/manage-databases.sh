#!/bin/bash
# ==============================================================================
# 🗄️ Multi-Database Manager: PostgreSQL, MariaDB 11.x, and SQL Server 2022
# ==============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(dirname "$SCRIPT_DIR")"
ENV_FILE="${BASE_DIR}/.env"

# Color helpers
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

if [ ! -f "$ENV_FILE" ]; then
    echo -e "${RED}❌ .env file not found at ${ENV_FILE}${NC}"
    exit 1
fi

function print_usage() {
    echo -e "${CYAN}======================================================================${NC}"
    echo -e "${CYAN}   🚀 VPS Multi-Database Infrastructure CLI                          ${NC}"
    echo -e "${CYAN}======================================================================${NC}"
    echo "Usage: $0 {status|start|stop|restart} [postgres|mariadb|sqlserver|mongodb|all]"
    echo ""
    echo "Examples:"
    echo "  $0 status                     # View running status and RAM/CPU usage of all engines"
    echo "  $0 start mariadb              # Start MariaDB 11.x + phpMyAdmin"
    echo "  $0 stop sqlserver             # Stop SQL Server to free up 1.6 GB RAM"
    echo "  $0 restart postgres           # Restart PostgreSQL 16 + pgAdmin"
    echo "  $0 start mongodb              # Start MongoDB 7.0 LTS + Mongo Express (disabled by default)"
    echo "  $0 stop all                   # Stop all database containers"
    echo "  $0 start all                  # Start all database containers"
    echo ""
}

function check_status() {
    echo -e "${CYAN}=== 🗄️ Database Engines Status & Resource Usage ===${NC}"
    echo ""
    printf "%-18s %-16s %-10s %-12s %-14s\n" "ENGINE" "CONTAINER" "PORT" "STATUS" "MEMORY"
    echo "----------------------------------------------------------------------"

    ENGINES=("postgres:shared_postgres:5432:PostgreSQL 16" "mariadb:shared_mariadb:3306:MariaDB 11.x" "sql-server:shared_sql:1433:SQL Server 2022" "oracle:shared_oracle:1521:Oracle 23ai Free" "mongodb:shared_mongodb:27017:MongoDB 7.0 LTS")

    for entry in "${ENGINES[@]}"; do
        IFS=":" read -r key container port name <<< "$entry"
        ps_out=$(docker ps -a --filter "name=^/${container}$" --format "{{.Status}}" 2>/dev/null || true)
        
        if [[ -z "$ps_out" ]]; then
            status_badge="${RED}Not Created${NC}"
            mem="0 MB"
        elif [[ "$ps_out" =~ ^Up ]]; then
            status_badge="${GREEN}Online (Up)${NC}"
            mem=$(docker stats --no-stream --format "{{.MemUsage}}" "$container" 2>/dev/null | awk '{print $1}' || echo "N/A")
        else
            status_badge="${YELLOW}Stopped${NC}"
            mem="0 MB (Free)"
        fi
        
        printf "%-18s %-16s %-10s %-22b %-14s\n" "$name" "$container" "$port" "$status_badge" "$mem"
    done
    echo ""
}

function manage_engine() {
    local action="$1"
    local target="$2"

    case "$target" in
        postgres)
            echo -e "${BLUE}▶ [PostgreSQL 16] ${action}...${NC}"
            case "$action" in
                start) docker compose --env-file "$ENV_FILE" -f "${SCRIPT_DIR}/postgres/docker-compose.yml" up -d ;;
                stop) docker compose --env-file "$ENV_FILE" -f "${SCRIPT_DIR}/postgres/docker-compose.yml" stop ;;
                restart) docker compose --env-file "$ENV_FILE" -f "${SCRIPT_DIR}/postgres/docker-compose.yml" restart ;;
            esac
            ;;
        mariadb)
            echo -e "${BLUE}▶ [MariaDB 11.x] ${action}...${NC}"
            case "$action" in
                start) docker compose --env-file "$ENV_FILE" -f "${SCRIPT_DIR}/mariadb/docker-compose.yml" up -d ;;
                stop) docker compose --env-file "$ENV_FILE" -f "${SCRIPT_DIR}/mariadb/docker-compose.yml" stop ;;
                restart) docker compose --env-file "$ENV_FILE" -f "${SCRIPT_DIR}/mariadb/docker-compose.yml" restart ;;
            esac
            ;;
        sqlserver|sql)
            echo -e "${BLUE}▶ [Microsoft SQL Server 2022] ${action}...${NC}"
            case "$action" in
                start) docker compose --env-file "$ENV_FILE" -f "${SCRIPT_DIR}/sql-server/docker-compose.yml" up -d ;;
                stop) docker compose --env-file "$ENV_FILE" -f "${SCRIPT_DIR}/sql-server/docker-compose.yml" stop ;;
                restart) docker compose --env-file "$ENV_FILE" -f "${SCRIPT_DIR}/sql-server/docker-compose.yml" restart ;;
            esac
            ;;
        oracle)
            echo -e "${BLUE}▶ [Oracle Database 23ai Free] ${action}...${NC}"
            case "$action" in
                start) docker compose --env-file "$ENV_FILE" -f "${SCRIPT_DIR}/oracle/docker-compose.yml" up -d ;;
                stop) docker compose --env-file "$ENV_FILE" -f "${SCRIPT_DIR}/oracle/docker-compose.yml" stop ;;
                restart) docker compose --env-file "$ENV_FILE" -f "${SCRIPT_DIR}/oracle/docker-compose.yml" restart ;;
            esac
            ;;
        mongodb|mongo)
            echo -e "${BLUE}▶ [MongoDB 7.0 LTS] ${action}...${NC}"
            case "$action" in
                start) docker compose --env-file "$ENV_FILE" -f "${SCRIPT_DIR}/mongodb/docker-compose.yml" up -d ;;
                stop) docker compose --env-file "$ENV_FILE" -f "${SCRIPT_DIR}/mongodb/docker-compose.yml" stop ;;
                restart) docker compose --env-file "$ENV_FILE" -f "${SCRIPT_DIR}/mongodb/docker-compose.yml" restart ;;
            esac
            ;;
        all)
            echo -e "${BLUE}▶ [All Database Engines] ${action}...${NC}"
            for eng in postgres mariadb sqlserver oracle mongodb; do
                manage_engine "$action" "$eng"
            done
            ;;
        *)
            echo -e "${RED}❌ Unknown database target: '${target}'${NC}"
            print_usage
            exit 1
            ;;
    esac
}

ACTION="${1:-status}"
TARGET="${2:-}"

case "$ACTION" in
    status)
        check_status
        ;;
    start|stop|restart)
        if [ -z "$TARGET" ]; then
            echo -e "${RED}❌ Target required for '${ACTION}'. Specify: postgres, mariadb, sqlserver, or all.${NC}"
            print_usage
            exit 1
        fi
        manage_engine "$ACTION" "$TARGET"
        echo ""
        check_status
        ;;
    *)
        print_usage
        ;;
esac
