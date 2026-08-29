#!/bin/sh
# Container health check: healthy only when the headless REST API answers on the
# shared loopback AND the connection descriptor exists. Any HTTP status counts
# as answering; only a connection failure is unhealthy.
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
. "$SCRIPT_DIR/burp-lib.sh"

STATE_DIR=${STATE_DIR:-/state}
[ -f "$STATE_DIR/connection.json" ] || exit 1

code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 3 \
  "http://127.0.0.1:${BURP_API_PORT:-1337}/v0.1/" 2>/dev/null || true)

[ -n "$code" ] && [ "$code" != "000" ]
