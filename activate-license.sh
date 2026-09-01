#!/bin/bash
# ==============================================================================
# 🔑 VPS-INFRA: 1-CLICK AUTOMATED LICENSE ACTIVATOR
# ==============================================================================
set -e

GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BOLD='\033[1m'
NC='\033[0m' # No Color

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo -e "${CYAN}${BOLD}"
echo "======================================================================"
echo "   🔑 VPS-INFRA: AUTOMATED ENTERPRISE LICENSE ACTIVATOR"
echo "======================================================================"
echo -e "${NC}"

# 1. Retrieve License Key (from $1 or interactive prompt)
LICENSE_KEY="$1"
if [ -z "$LICENSE_KEY" ]; then
    echo -e "${YELLOW}👉 Please paste your TMK_LICENSE_KEY token below and press ENTER:${NC}"
    read -r -p "Token: " LICENSE_KEY
fi

# Clean whitespace and quotes
LICENSE_KEY=$(echo "$LICENSE_KEY" | sed -e 's/^[[:space:]"'\''"]*//' -e 's/[[:space:]"'\''"]*$//')

if [ -z "$LICENSE_KEY" ]; then
    echo -e "${RED}❌ Error: No license key provided. Activation aborted.${NC}"
    exit 1
fi

echo -e "\n${CYAN}▶ Step 1: Securing volumes and license file storage...${NC}"
mkdir -p "$SCRIPT_DIR/volumes"

# Docker directory mount fix: if license.key exists as a directory, remove it and touch as file
if [ -d "$SCRIPT_DIR/volumes/license.key" ]; then
    echo -e "${YELLOW}⚠️  Detected license.key was created as a directory by Docker. Converting to file...${NC}"
    rm -rf "$SCRIPT_DIR/volumes/license.key"
fi

# Write key directly to persistent volume file
echo "$LICENSE_KEY" > "$SCRIPT_DIR/volumes/license.key"
chmod 644 "$SCRIPT_DIR/volumes/license.key"
echo -e "${GREEN}✅ License key saved to: $SCRIPT_DIR/volumes/license.key${NC}"

# 2. Update .env file
echo -e "\n${CYAN}▶ Step 2: Synchronizing configuration in .env...${NC}"
if [ -f "$SCRIPT_DIR/.env" ]; then
    if grep -q "^TMK_LICENSE_KEY=" "$SCRIPT_DIR/.env"; then
        sed -i 's|^TMK_LICENSE_KEY=.*|TMK_LICENSE_KEY="'"$LICENSE_KEY"'"|' "$SCRIPT_DIR/.env"
    else
        echo "TMK_LICENSE_KEY=\"$LICENSE_KEY\"" >> "$SCRIPT_DIR/.env"
    fi
    echo -e "${GREEN}✅ Updated TMK_LICENSE_KEY in .env${NC}"
fi

# 3. Apply changes to running containers
echo -e "\n${CYAN}▶ Step 3: Refreshing DevOps and CI runtime containers...${NC}"
docker compose up -d devops-api-prod ci-api-prod

# 4. Verify License Status via API
echo -e "\n${CYAN}▶ Step 4: Validating license activation status...${NC}"
sleep 2

STATUS_JSON=""
for i in {1..5}; do
    STATUS_JSON=$(docker exec ci-api-prod node -e "fetch('http://devops-api-prod:8080/api/License/status').then(r=>r.json()).then(d=>console.log(JSON.stringify(d))).catch(()=>console.log(''))" 2>/dev/null || echo "")
    if [[ "$STATUS_JSON" =~ "isValid" ]]; then
        break
    fi
    sleep 2
done

if [[ "$STATUS_JSON" =~ "\"isValid\":true" ]]; then
    echo -e "\n${GREEN}${BOLD}======================================================================${NC}"
    echo -e "${GREEN}${BOLD}   🎉 ENTERPRISE LICENSE ACTIVATED SUCCESSFULLY!${NC}"
    echo -e "${GREEN}${BOLD}======================================================================${NC}"
    docker exec ci-api-prod node -e "
        const d = $STATUS_JSON;
        console.log('${BOLD}Status:${NC}          \x1b[32mACTIVE / VALID\x1b[0m');
        console.log('${BOLD}Client Name:${NC}     ' + (d.clientName || 'Enterprise Client'));
        console.log('${BOLD}Plan Tier:${NC}       ' + (d.plan || 'Enterprise'));
        console.log('${BOLD}Days Remaining:${NC}  ' + (d.daysRemaining || 0) + ' Days');
        console.log('${BOLD}Expires At:${NC}      ' + (d.expiresAtUtc ? new Date(d.expiresAtUtc).toLocaleDateString() : 'N/A'));
        console.log('${BOLD}Max Projects:${NC}    ' + (d.maxProjects || 100));
        console.log('${BOLD}Max Services:${NC}    ' + (d.maxServices || 500));
    "
    echo -e "${GREEN}======================================================================${NC}\n"
else
    echo -e "\n${YELLOW}⚠️  Activation submitted. Detailed status response:${NC}"
    echo "$STATUS_JSON"
    echo -e "${YELLOW}👉 If you are still seeing an error, check if the server hardware fingerprint matches the token.${NC}\n"
fi
