#!/usr/bin/env bash
# ==============================================================================
# VPS-INFRA Client - Dual Topology & Compose Profile E2E Verification Suite
# ==============================================================================

set -euo pipefail

GREEN='\033[0;32m'
RED='\033[0;31m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

echo -e "${CYAN}${BOLD}"
echo "======================================================================="
echo "  🧪 VPS-INFRA CLIENT DUAL TOPOLOGY E2E VERIFICATION SUITE"
echo "======================================================================="
echo -e "${NC}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Step 1: Validate Compose Profiles
echo -e "${CYAN}▶ [1/3] Validating Docker Compose profiles in production docker-compose.yml...${NC}"

docker compose -f "${ROOT_DIR}/docker-compose.yml" --profile all config --services > /tmp/client_profile_all.txt
if grep -q "devops" /tmp/client_profile_all.txt && grep -q "ci" /tmp/client_profile_all.txt; then
    echo -e "${GREEN}  ✓ Profile 'all' includes both DevOps and CI services.${NC}"
else
    echo -e "${RED}  ✗ Profile 'all' validation failed.${NC}"
    exit 1
fi

docker compose -f "${ROOT_DIR}/docker-compose.yml" --profile devops config --services > /tmp/client_profile_devops.txt
if grep -q "devops" /tmp/client_profile_devops.txt && ! grep -q "ci-server" /tmp/client_profile_devops.txt; then
    echo -e "${GREEN}  ✓ Profile 'devops' isolates only DevOps services.${NC}"
else
    echo -e "${RED}  ✗ Profile 'devops' validation failed.${NC}"
    exit 1
fi

docker compose -f "${ROOT_DIR}/docker-compose.yml" --profile ci config --services > /tmp/client_profile_ci.txt
if grep -q "ci" /tmp/client_profile_ci.txt && ! grep -q "devops-manager" /tmp/client_profile_ci.txt; then
    echo -e "${GREEN}  ✓ Profile 'ci' isolates only CI build runner services.${NC}"
else
    echo -e "${RED}  ✗ Profile 'ci' validation failed.${NC}"
    exit 1
fi
rm -f /tmp/client_profile_all.txt /tmp/client_profile_devops.txt /tmp/client_profile_ci.txt

# Step 2: Validate setup.sh syntax and help
echo -e "\n${CYAN}▶ [2/3] Validating setup.sh script integrity...${NC}"
bash -n "${ROOT_DIR}/setup.sh"
echo -e "${GREEN}  ✓ setup.sh bash syntax check passed.${NC}"

# Step 3: Validate .env.example contains Section 9 configurations
echo -e "\n${CYAN}▶ [3/3] Validating .env.example Section 9 configuration keys...${NC}"
REQUIRED_KEYS=("DEPLOYMENT_MODE" "COMPOSE_PROFILES" "DOCKER_REGISTRY_TYPE" "DOCKER_REGISTRY_HOST" "CI_SECRET" "SYNC_MODE")
for key in "${REQUIRED_KEYS[@]}"; do
    if grep -q "^${key}=" "${ROOT_DIR}/.env.example"; then
        echo -e "${GREEN}  ✓ Found key: ${key}${NC}"
    else
        echo -e "${RED}  ✗ Missing key: ${key} in .env.example${NC}"
        exit 1
    fi
done

echo -e "\n${GREEN}${BOLD}======================================================================="
echo "  🎉 ALL CLIENT DUAL TOPOLOGY VERIFICATION CHECKS PASSED!"
echo "=======================================================================${NC}"
