#!/bin/bash
# Sourced by setup.sh. Read-only check; never creates or resets accounts.
validate_admin_account() {
    local attempt result
    ADMIN_VALIDATION_STATUS=error

    # If shared_postgres is not running locally (e.g. CI-only profile or external DB), skip gracefully
    if ! docker ps --format '{{.Names}}' | grep -qx "shared_postgres"; then
        ADMIN_VALIDATION_STATUS=skipped
        return 0
    fi

    echo "Checking the configured administrator in PostgreSQL (12 attempts, 5 seconds between retries)..."
    for ((attempt = 1; attempt <= 12; attempt++)); do
        # Use the same database/user defaults as the API's Compose connection.
        # psql quotes the email as an SQL literal, including embedded apostrophes.
        if result=$(docker exec -i -e PGCONNECT_TIMEOUT=3 -e PGOPTIONS='-c statement_timeout=3000' shared_postgres \
            psql -X -t -A -v ON_ERROR_STOP=1 \
            -U "${POSTGRES_USER:-postgres}" -d "${POSTGRES_DB:-devops_prod}" \
            -v "admin_email=${SUPERADMIN_EMAIL:-admin@example.com}" 2>/dev/null <<'SQL'
SELECT EXISTS (
    SELECT 1 FROM public."AspNetUsers"
    WHERE lower("Email") = lower(:'admin_email')
);
SQL
        ); then
            case "$result" in
                t) ADMIN_VALIDATION_STATUS=found; return 0 ;;
                f) ADMIN_VALIDATION_STATUS=missing ;;
                *) ADMIN_VALIDATION_STATUS=error ;;
            esac
        else
            ADMIN_VALIDATION_STATUS=error
        fi
        if ((attempt < 12)); then sleep 5; fi
    done
    # Let setup print its full summary even when validation is unsuccessful.
    return 0
}

print_admin_validation() {
    case "$ADMIN_VALIDATION_STATUS" in
        found)
            echo "  ✅ Account found in the configured database."
            ;;
        skipped)
            echo "  ℹ️ Local shared_postgres container not running on this host (external database or distributed node)."
            ;;
        missing)
            echo "  ❌ Account NOT FOUND in the configured database after startup retries."
            echo "     The displayed credentials have no matching account in this database."
            echo "     Check API startup logs for administrator creation failures."
            ;;
        *)
            echo "  ⚠️ Account check FAILED: could not verify the user table."
            echo "     Check PostgreSQL availability, database settings, and API migrations."
            ;;
    esac
    echo "  Password and administrator role have NOT been validated; these are configuration values."
    echo "  Changing .env does not prove an existing account's password was updated."
    if [[ "$ADMIN_VALIDATION_STATUS" != found && "$ADMIN_VALIDATION_STATUS" != skipped ]]; then
        echo "  Diagnostic command: docker logs --tail 200 devops-api-prod"
    fi
}
