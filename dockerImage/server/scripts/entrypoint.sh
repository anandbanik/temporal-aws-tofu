#!/bin/sh
# pipefail is included in alpine
# shellcheck disable=SC3040
set -eu -o pipefail

# Resolve hostname to IP address for binding if not already set (supports both IPv4 and IPv6)
: "${BIND_ON_IP:=$(getent hosts "$(hostname)" | awk '{print $1;}')}"
export BIND_ON_IP

# Set broadcast address for ringpop membership
if [ -z "${TEMPORAL_BROADCAST_ADDRESS:-}" ]; then
    if [ -n "${ECS_CONTAINER_METADATA_URI_V4:-}" ]; then
        if command -v wget >/dev/null 2>&1; then
            ECS_RESPONSE=$(wget -q -O - "${ECS_CONTAINER_METADATA_URI_V4}/task" 2>&1 || true)
            PARSED_IP=$(echo "${ECS_RESPONSE}" | sed -n 's/.*"IPv4Addresses":\["\([^"]*\)".*/\1/p')
            if [ -n "${PARSED_IP}" ]; then
                TEMPORAL_BROADCAST_ADDRESS="${PARSED_IP}"
                echo "entrypoint.sh: broadcast address from ECS metadata: ${TEMPORAL_BROADCAST_ADDRESS}"
            else
                echo "entrypoint.sh: failed to parse IP from ECS metadata, falling back to hostname resolution"
            fi
        else
            echo "entrypoint.sh: wget not found, falling back to hostname resolution"
        fi
    fi
    # Fallback to hostname resolution (works in Docker and Fargate awsvpc)
    : "${TEMPORAL_BROADCAST_ADDRESS:=$(getent hosts "$(hostname)" | awk '{print $1;}')}"
    export TEMPORAL_BROADCAST_ADDRESS
fi

echo "entrypoint.sh: TEMPORAL_BROADCAST_ADDRESS=${TEMPORAL_BROADCAST_ADDRESS}"

# Determine which service(s) to start
if [ -n "${SERVICES:-}" ]; then
    echo "entrypoint.sh: Starting services: ${SERVICES}"
    exec temporal-server start --service "${SERVICES}"
else
    echo "entrypoint.sh: Starting all services"
    exec temporal-server start
fi