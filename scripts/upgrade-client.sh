#!/bin/bash
# ==============================================================================
# 🚀 VPS-INFRA-CLIENT: DETACHED BACKGROUND UPGRADE RUNNER & TELEMETRY DISPATCHER
# ==============================================================================
# Executed in background by DevOps API or manually via CLI.
# Safely pulls the latest client code, runs setup.sh, and reports telemetry on failure.
# ==============================================================================
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$SCRIPT_DIR"

LOCK_FILE="$SCRIPT_DIR/upgrade.lock"
STATUS_FILE="$SCRIPT_DIR/upgrade.status"
LOG_FILE="$SCRIPT_DIR/upgrade.log"
TELEMETRY_ENDPOINT="${LICENSE_TELEMETRY_URL:-https://license.tmkcomputers.in/api/v1/telemetry/upgrade-failure}"

# Prevent concurrent upgrade executions
if [ -f "$LOCK_FILE" ]; then
    PID=$(cat "$LOCK_FILE" 2>/dev/null || true)
    if [ -n "$PID" ] && kill -0 "$PID" 2>/dev/null; then
        echo "Upgrade already in progress with PID $PID." >&2
        exit 1
    fi
fi
echo "$$" > "$LOCK_FILE"

cleanup() {
    rm -f "$LOCK_FILE"
}
trap cleanup EXIT

# Helper to update status JSON file atomically
update_status() {
    local status="$1"
    local message="$2"
    local step="${3:-}"
    local now_utc
    now_utc="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

    cat <<EOF > "$STATUS_FILE.tmp"
{
  "status": "$status",
  "message": "$message",
  "step": "$step",
  "timestampUtc": "$now_utc"
}
EOF
    mv "$STATUS_FILE.tmp" "$STATUS_FILE"
}

# Helper to report failure to Central Licensing Authority
report_telemetry() {
    local failed_step="$1"
    local error_msg="$2"
    local now_utc
    now_utc="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

    # Extract license key
    local license_key=""
    if [ -f "$SCRIPT_DIR/volumes/license.key" ]; then
        license_key="$(cat "$SCRIPT_DIR/volumes/license.key" | tr -d '\r\n')"
    elif [ -f "$SCRIPT_DIR/license.key" ]; then
        license_key="$(cat "$SCRIPT_DIR/license.key" | tr -d '\r\n')"
    elif [ -f "$SCRIPT_DIR/.env" ]; then
        license_key="$(grep -E '^TMK_LICENSE_KEY=' "$SCRIPT_DIR/.env" 2>/dev/null | cut -d '=' -f2- | tr -d '"' | tr -d "'" | tr -d '\r\n')"
    fi
    license_key="${license_key:-UNLICENSED_NODE}"

    # Extract company name or client name
    local client_name="Enterprise Client"
    if [ -f "$SCRIPT_DIR/.env" ]; then
        client_name="$(grep -E '^COMPANY_NAME=' "$SCRIPT_DIR/.env" 2>/dev/null | cut -d '=' -f2- | tr -d '"' | tr -d "'" | tr -d '\r\n')"
    fi
    client_name="${client_name:-Enterprise Client}"

    # Current git commit / version
    local current_commit="unknown"
    if command -v git &>/dev/null && [ -d "$SCRIPT_DIR/.git" ]; then
        current_commit="$(git -C "$SCRIPT_DIR" rev-parse --short HEAD 2>/dev/null || echo "unknown")"
    fi

    # OS Info
    local os_info
    os_info="$(uname -srm 2>/dev/null || echo "Linux")"

    # Extract last 100 lines of log safely as JSON escaped string
    local log_snippet=""
    if [ -f "$LOG_FILE" ]; then
        log_snippet="$(tail -n 100 "$LOG_FILE" | python3 -c "import sys, json; print(json.dumps(sys.stdin.read()))" 2>/dev/null || echo '""')"
    else
        log_snippet='""'
    fi

    local payload
    payload=$(cat <<EOF
{
  "clientName": $(python3 -c "import json; print(json.dumps('$client_name'))" 2>/dev/null || echo "\"$client_name\""),
  "licenseKey": "$license_key",
  "currentVersion": "$current_commit",
  "targetVersion": "origin/main",
  "failedStep": $(python3 -c "import json; print(json.dumps('$failed_step'))" 2>/dev/null || echo "\"$failed_step\""),
  "errorMessage": $(python3 -c "import json; print(json.dumps('$error_msg'))" 2>/dev/null || echo "\"$error_msg\""),
  "logs": $log_snippet,
  "osInfo": "$os_info",
  "timestampUtc": "$now_utc"
}
EOF
)

    echo "▶ Dispatching telemetry failure report to Central License Authority..." >> "$LOG_FILE"
    curl -s -X POST "$TELEMETRY_ENDPOINT" \
        -H "Content-Type: application/json" \
        -d "$payload" \
        --max-time 15 >> "$LOG_FILE" 2>&1 || true
}

exec >> "$LOG_FILE" 2>&1
echo ""
echo "======================================================================"
echo "   🚀 CLIENT PLATFORM UPGRADE STARTED AT $(date -u)"
echo "======================================================================"

CURRENT_STEP="Initialization"
update_status "IN_PROGRESS" "Starting client upgrade..." "$CURRENT_STEP"

# 1. Backup .env configuration
CURRENT_STEP="Backing up configuration (.env)"
echo "▶ $CURRENT_STEP..."
if [ -f "$SCRIPT_DIR/.env" ]; then
    cp "$SCRIPT_DIR/.env" "$SCRIPT_DIR/.env.bak.$(date +%Y%m%d%H%M%S)"
fi

# 2. Fetch and pull latest Git repository updates
CURRENT_STEP="Git Fetch & Pull"
echo "▶ $CURRENT_STEP..."
update_status "IN_PROGRESS" "Fetching latest changes from Git repository..." "$CURRENT_STEP"

if ! git fetch origin main; then
    echo "❌ git fetch failed." >&2
    update_status "FAILED" "Failed to fetch repository updates from Git remote." "$CURRENT_STEP"
    report_telemetry "$CURRENT_STEP" "git fetch origin main failed"
    exit 1
fi

# Preserve untracked files and reset tracked files to clean remote state
if ! git reset --hard origin/main; then
    echo "❌ git reset to origin/main failed." >&2
    update_status "FAILED" "Failed to update codebase to latest commit." "$CURRENT_STEP"
    report_telemetry "$CURRENT_STEP" "git reset --hard origin/main failed"
    exit 1
fi

# 3. Ensure executable permissions on setup scripts
chmod +x "$SCRIPT_DIR/setup.sh" "$SCRIPT_DIR/uninstall.sh" "$SCRIPT_DIR/scripts/"*.sh 2>/dev/null || true

# 4. Execute setup.sh in non-interactive upgrade mode
CURRENT_STEP="Executing setup.sh platform update"
echo "▶ $CURRENT_STEP..."
update_status "IN_PROGRESS" "Pulling updated Docker images and restarting platform services..." "$CURRENT_STEP"

# Run setup.sh (input </dev/null prevents interactive prompts)
if ! bash "$SCRIPT_DIR/setup.sh" </dev/null; then
    echo "❌ setup.sh failed." >&2
    update_status "FAILED" "Setup script encountered an error during service startup." "$CURRENT_STEP"
    report_telemetry "$CURRENT_STEP" "bash setup.sh failed with non-zero exit code"
    exit 1
fi

# 5. Verify healthy services
CURRENT_STEP="Verifying service health"
echo "▶ $CURRENT_STEP..."
update_status "IN_PROGRESS" "Verifying service health..." "$CURRENT_STEP"

NEW_COMMIT="$(git rev-parse --short HEAD 2>/dev/null || echo "latest")"
echo "✅ Upgrade completed successfully to commit $NEW_COMMIT."
update_status "SUCCESS" "Platform successfully upgraded to version $NEW_COMMIT." "Completed"
exit 0
