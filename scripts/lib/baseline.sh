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

# Fixed address for the bbs container. The BBS scenarios place calls into
# proxytrunks as if they came from a carrier, so the tester has to be a trusted
# DDI provider address, and outbound calls have to be routed back to it.
BASELINE_BBS_ADDRESS=${BASELINE_BBS_ADDRESS:-10.189.4.50}
BASELINE_PROXYTRUNKS_ADDRESS=${BASELINE_PROXYTRUNKS_ADDRESS:-10.189.4.41}

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

# As baseline_mysql, but keeps the column names as a header row.
baseline_mysql_csv() {
    baseline_compose exec -T data \
        mysql -uroot -p"${BASELINE_MYSQL_ROOT_PASSWORD}" \
        --default-character-set=utf8 -B "${BASELINE_MYSQL_DATABASE}" -e "$1"
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

# baseline_api <token> <method> <path> [body] - call the REST API from inside the
# backend container.
baseline_api() {
    baseline_compose exec -T backend \
        curl -s -X "$2" "http://localhost/api$3" \
        -H "Authorization: Bearer $1" \
        -H "Content-Type: application/json" \
        ${4:+-d "$4"}
}

baseline_platform_token() {
    baseline_compose exec -T backend \
        curl -s -X POST http://localhost/api/platform/admin_login \
        -F "username=${BASELINE_API_USERNAME}" -F "password=${BASELINE_API_PASSWORD}" |
        sed -nr 's/.*"token":"([^"]+)".*/\1/p'
}

baseline_brand_token() {
    baseline_compose exec -T backend \
        curl -s -X POST http://localhost/api/brand/token/exchange \
        -F "token=$1" -F "username=${2:-brandadmin}" |
        sed -nr 's/.*"token":"([^"]+)".*/\1/p'
}
