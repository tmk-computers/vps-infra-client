#!/bin/bash
# Sourced by setup.sh after infrastructure startup.
authenticate_registry() {
    local user="${DOCKER_REGISTRY_USER:-${REGISTRY_USER:-}}"
    local password="${DOCKER_REGISTRY_PASSWORD:-${REGISTRY_PASSWORD:-}}"
    local target="${DOCKER_REGISTRY_HOST:-${REGISTRY_HOST:-localhost:5000}}"
    local attempts=1 attempt output

    if [[ "${DOCKER_REGISTRY_TYPE:-private}" == private ]]; then
        user="${user:-admin}"
        password="${password:-tmkregistry2026}"
        if [[ "${DEPLOYMENT_MODE:-all-in-one}" != devops-only ]]; then
            attempts=30
        fi
    fi

    [[ -n "$user" && -n "$password" ]] || return 0
    echo "▶ Authenticating Docker with registry ${target}..."
    for ((attempt = 1; attempt <= attempts; attempt++)); do
        if output=$(printf '%s\n' "$password" | docker login "$target" -u "$user" --password-stdin 2>&1); then
            echo "✅ Docker registry authentication succeeded."
            return 0
        fi
        if (( attempt < attempts )); then
            if (( attempt == 1 )); then
                echo "Waiting for the private registry to accept login..."
            fi
            sleep 2
        fi
    done

    printf '%s\n' "$output" >&2
    echo "Registry authentication failed for ${target}. Check registry availability and credentials in .env." >&2
    if [[ "$attempts" -gt 1 ]]; then
        echo "Inspect startup errors with: docker logs --tail 100 docker-registry-backend" >&2
    fi
    return 1
}
