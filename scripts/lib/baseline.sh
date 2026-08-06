#!/bin/bash
#
# Shared helpers for the legacy baseline scripts.

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
export ROOT

# Where run artifacts (CDR dumps, JUnit summaries) are written
BASELINE_DIR="${BASELINE_DIR:-$ROOT/var/baseline}"
export BASELINE_DIR

# Credentials used across the whole compose stack
MYSQL_PASSWORD="${MYSQL_PASSWORD:-changeme}"
MYSQL_DATABASE="${MYSQL_DATABASE:-ivozprovider}"
API_USERNAME="${API_USERNAME:-admin}"
API_PASSWORD="${API_PASSWORD:-changeme}"
export MYSQL_PASSWORD MYSQL_DATABASE API_USERNAME API_PASSWORD

COMPOSE_NETWORK="${COMPOSE_NETWORK:-ivozprovider_network}"
DATA_CONTAINER="${DATA_CONTAINER:-ivozprovider-data}"

# Fixed compose addresses (docker-compose.yml)
USERS_ADDRESS="${USERS_ADDRESS:-10.189.4.40}"
TRUNKS_ADDRESS="${TRUNKS_ADDRESS:-10.189.4.41}"
AS_ADDRESS="${AS_ADDRESS:-10.189.4.42}"
MEDIA_RELAY_ADDRESS="${MEDIA_RELAY_ADDRESS:-10.189.4.43}"
RESOLVER_ADDRESS="${RESOLVER_ADDRESS:-10.189.4.53}"
BBS_ADDRESS="${BBS_ADDRESS:-10.189.4.60}"
export USERS_ADDRESS TRUNKS_ADDRESS AS_ADDRESS MEDIA_RELAY_ADDRESS RESOLVER_ADDRESS BBS_ADDRESS

function info()  { echo -e "[\e[1;32m*\e[0m] \e[1;37m$1\e[0m"; }
function warn()  { echo -e "[\e[1;33m!\e[0m] \e[1;33m$1\e[0m"; }
function error() { echo -e "[\e[1;31m!\e[0m] \e[1;31m$1\e[0m" >&2; }

function compose() {
    docker compose --project-directory "$ROOT" "$@"
}

# Run a query against the data container
function mysql_query() {
    docker exec -i -e MYSQL_PWD="$MYSQL_PASSWORD" "$DATA_CONTAINER" \
        mysql --user=root --batch --skip-column-names "$MYSQL_DATABASE" -e "$1"
}

function mysql_stdin() {
    docker exec -i -e MYSQL_PWD="$MYSQL_PASSWORD" "$DATA_CONTAINER" \
        mysql --user=root "$MYSQL_DATABASE"
}

# The proxies cache Domains/address rows in memory, so anything that seeds them
# has to ask kamailio to reload (on a real platform the provider does this
# through the reload service).
function kamailio_reload() {
    local role container
    for role in users trunks; do
        container="ivozprovider-kamailio-${role}"
        docker inspect -f '{{.State.Running}}' "$container" 2>/dev/null | grep -q true || continue
        # Every module that caches a table it is seeded from: lcr holds the
        # outgoing routing rules/gateways, dialplan the transformation rules,
        # regex the match lists.
        for cmd in domain.reload permissions.addressReload permissions.trustedReload \
                   dispatcher.reload lcr.reload dialplan.reload regex.reload \
                   htable.reload rtpengine.reload; do
            docker exec "$container" \
                kamcmd -s "unix:/run/kamailio/kamailio_proxy${role}_ctl" "$cmd" \
                > /dev/null 2>&1 || true
        done
        info "Reloaded kamailio-${role} domain/address/dispatcher caches"
    done
}

function wait_for_healthy() {
    local service="$1"
    local timeout="${2:-600}"
    local waited=0
    local cid status

    info "Waiting for '$service' to become healthy..."
    while true; do
        cid="$(compose ps -q "$service" 2>/dev/null)"
        if [ -n "$cid" ]; then
            status="$(docker inspect -f '{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}' "$cid" 2>/dev/null)"
            case "$status" in
                healthy|running) return 0 ;;
                exited|dead) error "'$service' exited"; return 1 ;;
            esac
        fi
        sleep 5
        waited=$((waited + 5))
        if [ "$waited" -ge "$timeout" ]; then
            error "Timed out waiting for '$service' (last status: ${status:-unknown})"
            return 1
        fi
    done
}
