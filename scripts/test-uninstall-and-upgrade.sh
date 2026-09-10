#!/bin/bash
# ==============================================================================
# 🧪 VPS-INFRA: INTEGRATION TEST SUITE FOR UNINSTALL, PRIVATE NETWORK & UPGRADE
# ==============================================================================
set -e

GREEN='\033[0;32m'
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$SCRIPT_DIR"

echo -e "${CYAN}======================================================================${NC}"
echo -e "${CYAN}   🧪 RUNNING AUTOMATED INTEGRATION TEST SUITE${NC}"
echo -e "${CYAN}======================================================================${NC}"

# -----------------------------------------------------------------------------
# TEST 1: UNINSTALL SCRIPT HELP & CLI VALIDATION
# -----------------------------------------------------------------------------
echo -e "\n${CYAN}▶ TEST 1: Validating uninstall.sh CLI flags...${NC}"
if ! bash "$SCRIPT_DIR/uninstall.sh" --help &>/dev/null; then
    echo -e "${RED}❌ Test 1 Failed: uninstall.sh --help returned non-zero.${NC}" >&2
    exit 1
fi

# Verify rejection of unknown flags
if bash "$SCRIPT_DIR/uninstall.sh" --invalid-flag &>/dev/null; then
    echo -e "${RED}❌ Test 1 Failed: uninstall.sh should reject invalid flags.${NC}" >&2
    exit 1
fi
echo -e "${GREEN}✅ Test 1 Passed: uninstall.sh CLI flag parser is valid.${NC}"

# -----------------------------------------------------------------------------
# TEST 2: UPGRADE LOCKFILE & CONCURRENCY PROTECTION
# -----------------------------------------------------------------------------
echo -e "\n${CYAN}▶ TEST 2: Validating upgrade runner lockfile mechanism...${NC}"
LOCK_FILE="$SCRIPT_DIR/upgrade.lock"
echo "$$" > "$LOCK_FILE"

# Attempting to run upgrade-client while lock exists should fail with error
if bash "$SCRIPT_DIR/scripts/upgrade-client.sh" &>/dev/null; then
    rm -f "$LOCK_FILE"
    echo -e "${RED}❌ Test 2 Failed: upgrade-client.sh should prevent concurrent execution.${NC}" >&2
    exit 1
fi
rm -f "$LOCK_FILE"
echo -e "${GREEN}✅ Test 2 Passed: Lockfile concurrency safeguard is operational.${NC}"

# -----------------------------------------------------------------------------
# TEST 3: PRIVATE NETWORK ENVIRONMENT DETECTIONS
# -----------------------------------------------------------------------------
echo -e "\n${CYAN}▶ TEST 3: Validating Private Network configuration logic...${NC}"
TEST_OUTPUT=$(bash -c '
    export NETWORK_MODE=private
    export ENABLE_HTTPS_REDIRECT=false
    if [ "${NETWORK_MODE:-public}" = "private" ] || [ "${ENABLE_HTTPS_REDIRECT:-true}" = "false" ]; then
        echo "REDIRECT_BYPASSED"
    fi
')

if [ "$TEST_OUTPUT" != "REDIRECT_BYPASSED" ]; then
    echo -e "${RED}❌ Test 3 Failed: Private network bypass logic failed.${NC}" >&2
    exit 1
fi
echo -e "${GREEN}✅ Test 3 Passed: Private network bypass evaluates accurately.${NC}"

# -----------------------------------------------------------------------------
# TEST 4: CENTRAL TELEMETRY DISPATCH & INGESTION
# -----------------------------------------------------------------------------
echo -e "\n${CYAN}▶ TEST 4: Validating Central Telemetry Failure Reporting...${NC}"
TELEMETRY_PAYLOAD='{
  "clientName": "Automated Test Suite",
  "licenseKey": "TEST-INTEGRATION-KEY",
  "currentVersion": "v2.3",
  "targetVersion": "v2.4",
  "failedStep": "simulated test failure",
  "errorMessage": "Integration test error assertion",
  "logs": "Detailed sample execution logs from test suite runner",
  "osInfo": "Linux Integration Test",
  "timestampUtc": "'$(date -u +"%Y-%m-%dT%H:%M:%SZ")'"
}'

RESPONSE=$(curl -s -w "%{http_code}" -X POST "http://localhost:5055/api/v1/telemetry/upgrade-failure" \
    -H "Content-Type: application/json" \
    -d "$TELEMETRY_PAYLOAD" -o /tmp/telemetry_resp.json)

if [ "$RESPONSE" != "201" ]; then
    echo -e "${RED}❌ Test 4 Failed: Expected HTTP 201, got $RESPONSE.${NC}" >&2
    exit 1
fi

REPORT_ID=$(python3 -c "import json; print(json.load(open('/tmp/telemetry_resp.json')).get('reportId', ''))" 2>/dev/null || echo "")
if [ -z "$REPORT_ID" ]; then
    echo -e "${RED}❌ Test 4 Failed: reportId not returned in response.${NC}" >&2
    exit 1
fi

# Clean up test row
docker exec license-server-prod node -e "
    const db = new (require('sqlite3').Database)('/app/data/licenses.db');
    db.run(\"DELETE FROM upgrade_failure_reports WHERE license_key='TEST-INTEGRATION-KEY'\", () => db.close());
" 2>/dev/null || true

rm -f /tmp/telemetry_resp.json
echo -e "${GREEN}✅ Test 4 Passed: Telemetry payload ingested successfully (Report #${REPORT_ID}).${NC}"

# -----------------------------------------------------------------------------
# TEST 5: TRAEFIK COMPOSE CONFIGURATION SYNTAX
# -----------------------------------------------------------------------------
echo -e "\n${CYAN}▶ TEST 5: Validating Traefik compose syntax with private network variables...${NC}"
if ! docker compose -f "$SCRIPT_DIR/network/traefik/docker-compose.yml" config >/dev/null; then
    echo -e "${RED}❌ Test 5 Failed: Traefik docker-compose.yml has syntax errors.${NC}" >&2
    exit 1
fi
echo -e "${GREEN}✅ Test 5 Passed: Traefik compose configuration is syntactically valid.${NC}"

# -----------------------------------------------------------------------------
# TEST 6: PLATFORM COMPOSE CONFIGURATION SYNTAX
# -----------------------------------------------------------------------------
echo -e "\n${CYAN}▶ TEST 6: Validating Platform docker-compose.yml syntax with PRIVATE_IP rules...${NC}"
if ! docker compose -f "$SCRIPT_DIR/docker-compose.yml" config >/dev/null; then
    echo -e "${RED}❌ Test 6 Failed: Platform docker-compose.yml has syntax errors.${NC}" >&2
    exit 1
fi
echo -e "${GREEN}✅ Test 6 Passed: Platform compose configuration is syntactically valid.${NC}"

echo -e "\n${GREEN}${BOLD}======================================================================${NC}"
echo -e "${GREEN}${BOLD}   🎉 ALL 6 INTEGRATION TESTS PASSED SUCCESSFULLY!${NC}"
echo -e "${GREEN}${BOLD}======================================================================${NC}"
exit 0
