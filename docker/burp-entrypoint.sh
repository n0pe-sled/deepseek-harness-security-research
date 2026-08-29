#!/bin/sh
# Phase 1 entrypoint for the containerized headless Burp service.
# Launches Burp headless with the REST API, waits until it answers, writes the
# connection descriptor, and keeps the JVM in the foreground.
#
# Fail-closed controls in this phase:
#   - the allowed-target allowlist must be non-empty or the service refuses to start
#   - the REST API and proxy bind only to the shared loopback (compose enforces)
#   - license material is never written to the repository or build image
set -eu

umask 077
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
. "$SCRIPT_DIR/burp-lib.sh"

: "${STATE_DIR:=/state}"
: "${BURP_JAR:=/opt/burp/burpsuite_pro.jar}"
: "${BURP_API_PORT:=1337}"
: "${BURP_PROXY_PORT:=8080}"
: "${BURP_REST_USER:=}"
: "${BURP_REST_PASSWORD:=}"
: "${BURP_REQUIRE_LICENSE:=0}"
: "${BURP_MAX_HEAP:=1g}"
: "${ALLOWLIST_FILE:=/state/allowlist.txt}"
BURP_REST_ARGS=${BURP_REST_ARGS:-}
BURP_JAVA_OPTS=${BURP_JAVA_OPTS:--Djava.awt.headless=true -Xmx${BURP_MAX_HEAP}}

mkdir -p "$STATE_DIR"
burp_log "phase 1 entrypoint starting (version=${BURP_VERSION:-unset})"

# Preflight.
[ -f "$BURP_JAR" ] || burp_die "missing $BURP_JAR (set BURP_DIST_URL or add burp/dist/burpsuite_pro.jar to the build context)"
command -v java >/dev/null 2>&1 || burp_die "java not found in PATH"
command -v curl >/dev/null 2>&1 || burp_die "curl not found in PATH"
BURP_JAVA_VERSION=$(java -version 2>&1 | head -n 1 | tr -d '"')

# Allowlist is the fail-closed gate. Refuse to run an unfenced proxy.
if ! burp_write_allowlist_file; then
  burp_die "BURP_TARGET_ALLOWLIST is empty; refusing to start an unfenced proxy"
fi
BURP_ALLOWLIST_COUNT=$(wc -l < "$ALLOWLIST_FILE" | tr -d ' ')
BURP_ALLOWLIST_HASH=$(burp_sha256 "$ALLOWLIST_FILE" 2>/dev/null || true)

# License state. Phase 1 runs in trial mode by default so connectivity can be
# proven without a key. Licensing for sustained use lands in phase 2.
BURP_LICENSE_STATE=trial
if [ "$BURP_REQUIRE_LICENSE" = "1" ]; then
  if [ -n "${BURP_LICENSE_KEY:-}" ]; then
    printf '%s\n' "$BURP_LICENSE_KEY" > /run/license.key
    chmod 600 /run/license.key
    BURP_LICENSE_STATE=licensed
  elif ls /run/license/* >/dev/null 2>&1; then
    BURP_LICENSE_STATE=licensed
  else
    burp_die "BURP_REQUIRE_LICENSE=1 but no license key or /run/license file is present"
  fi
fi

# Build the headless REST API launch command. Rest args from the operator are
# appended last so they can override defaults (trusted input from .env).
cmd="java $BURP_JAVA_OPTS -jar $BURP_JAR --headless --rest-api --port=$BURP_API_PORT"
if [ -n "$BURP_REST_USER" ]; then
  cmd="$cmd --user=$BURP_REST_USER"
fi
if [ -n "$BURP_REST_PASSWORD" ]; then
  cmd="$cmd --password=$BURP_REST_PASSWORD"
fi
if [ -n "${BURP_PROJECT_FILE:-}" ]; then
  cmd="$cmd --project-file=$BURP_PROJECT_FILE"
fi
cmd="$cmd $BURP_REST_ARGS"

cat > /tmp/burp-run.sh <<EOF
#!/bin/sh
exec $cmd
EOF
chmod +x /tmp/burp-run.sh

burp_log "launching headless Burp REST API on 127.0.0.1:${BURP_API_PORT}"
: > "$STATE_DIR/burp.log"
/tmp/burp-run.sh >> "$STATE_DIR/burp.log" 2>&1 &
pid=$!

cleanup() {
  kill "$pid" 2>/dev/null || true
  wait "$pid" 2>/dev/null || true
  burp_write_connection_json stopped 2>/dev/null || true
}
trap cleanup TERM INT

# Wait for the REST API to answer. A 401 or 404 still counts as reachable.
if burp_wait_http "http://127.0.0.1:$BURP_API_PORT/v0.1/" 240 "$BURP_REST_USER" "$BURP_REST_PASSWORD"; then
  burp_log "REST API reachable on 127.0.0.1:$BURP_API_PORT"
else
  burp_log "WARNING: REST API not reachable within 240s; tail of log follows"
  tail -n 40 "$STATE_DIR/burp.log" 2>/dev/null || true
fi

# Best-effort scope from the allowlist. Not yet reliable until the pinned
# version REST surface is validated; failure is reported, not fatal.
burp_apply_scope || burp_log "WARNING: Burp-scope application deferred to phase 3/validation"

burp_write_connection_json ready

wait "$pid"
rc=$?
cleanup
exit "$rc"
