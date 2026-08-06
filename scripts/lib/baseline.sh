#!/usr/bin/env bash
# Shared helpers for the legacy baseline scripts. Sourced, not executed.

BASELINE_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)

# Everything a call test needs. The portals are separate because they need a
# sibling ivoz-ui checkout that a Docker-only machine will not have.
BASELINE_CORE_SERVICES=(data redis backend kamailio-users kamailio-trunks asterisk rtpengine)
BASELINE_PORTAL_SERVICES=(portal-platform portal-brand portal-client portal-user)

BASELINE_COMPOSE_PROJECT=${BASELINE_COMPOSE_PROJECT:-ivozprovider}
BASELINE_NETWORK="${BASELINE_COMPOSE_PROJECT}_network"

# The compose file interpolates ${UID}/${GID} to keep bind-mounted files owned
# by the invoking user. UID is a readonly bash builtin variable, so it has to be
# exported into the environment rather than assigned.
export UID
export GID="${GID:-$(id -g)}"

# API entry points, as seen from a container on the compose network.
BASELINE_API_BASE=${BASELINE_API_BASE:-http://backend.ivozprovider.local/api}
BASELINE_API_USERNAME=${BASELINE_API_USERNAME:-admin}
BASELINE_API_PASSWORD=${BASELINE_API_PASSWORD:-changeme}

BASELINE_MYSQL_ROOT_PASSWORD=${BASELINE_MYSQL_ROOT_PASSWORD:-changeme}
BASELINE_MYSQL_DATABASE=${BASELINE_MYSQL_DATABASE:-ivozprovider}

baseline_compose() {
    docker compose -p "${BASELINE_COMPOSE_PROJECT}" -f "${BASELINE_ROOT}/docker-compose.yml" "$@"
}

baseline_health() {
    docker inspect -f '{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}' \
        "$(baseline_compose ps -qa "$1")" 2>/dev/null || echo missing
}

# baseline_wait_healthy <service>... - block until every service reports healthy
# (or running, for services without a healthcheck).
baseline_wait_healthy() {
    local deadline=$((SECONDS + ${BASELINE_HEALTH_TIMEOUT:-900}))
    local service state pending

    while :; do
        pending=()
        for service in "$@"; do
            state=$(baseline_health "$service")
            case "$state" in
                healthy|running) ;;
                *) pending+=("${service}=${state}") ;;
            esac
        done

        [ ${#pending[@]} -eq 0 ] && return 0

        if [ $SECONDS -ge $deadline ]; then
            echo "timed out waiting for: ${pending[*]}" >&2
            return 1
        fi
        sleep 5
    done
}

# baseline_mysql <sql> - run a statement against the baseline database.
baseline_mysql() {
    baseline_compose exec -T data \
        mysql -uroot -p"${BASELINE_MYSQL_ROOT_PASSWORD}" \
        --default-character-set=utf8 -N -B "${BASELINE_MYSQL_DATABASE}" -e "$1"
}

# baseline_newman <newman args>... - run newman on the compose network so it can
# resolve backend.ivozprovider.local, with the repository mounted at /work.
baseline_newman() {
    docker run --rm \
        --network "${BASELINE_NETWORK}" \
        --volume "${BASELINE_ROOT}:/work" \
        --workdir /work \
        --user "${UID}:${GID}" \
        "${BASELINE_NEWMAN_IMAGE:-postman/newman:6-alpine}" \
        "$@"
}
