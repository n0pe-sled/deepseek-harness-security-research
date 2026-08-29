#!/bin/sh
# Shared helpers for the containerized headless Burp service.
# Phase 1 (feature/burp-container): connectivity, allowlist gate, descriptor.
# POSIX sh only. Sourced by the entrypoint, health check, and proof script.

burp_log() {
  printf '%s burp| %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$*" >&2
}

burp_die() {
  burp_log "FATAL: $*"
  exit 1
}

# Normalize a target to host[:port], stripping scheme and path. Pure POSIX
# parameter expansion so it behaves identically on GNU and BSD systems.
burp_normalize_host() {
  value=$1
  case "$value" in
    http://*)  value=${value#http://} ;;
    https://*) value=${value#https://} ;;
  esac
  case "$value" in
    */*) value=${value%%/*} ;;
  esac
  printf '%s\n' "$value"
}

# Parse BURP_TARGET_ALLOWLIST (space, comma, or newline separated host[:port])
# into one normalized entry per line in ALLOWLIST_FILE. Returns non-zero when
# the allowlist is empty (the fail-closed gate).
burp_write_allowlist_file() {
  : "${ALLOWLIST_FILE:?ALLOWLIST_FILE unset}"
  : > "$ALLOWLIST_FILE"
  if [ -n "${BURP_TARGET_ALLOWLIST:-}" ]; then
    printf '%s\n' "$BURP_TARGET_ALLOWLIST" \
      | tr ', \t' '\n' \
      | while IFS= read -r _raw; do
          _norm=$(burp_normalize_host "$_raw")
          [ -n "$_norm" ] && printf '%s\n' "$_norm"
        done \
      | sort -u > "$ALLOWLIST_FILE"
  fi
  [ -s "$ALLOWLIST_FILE" ]
}

# Portable sha256 of a file, or exit 127 when no tool is available.
burp_sha256() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | cut -d ' ' -f 1
  elif command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$1" | cut -d ' ' -f 1
  else
    return 127
  fi
}

# Fail closed: exit 0 when TARGET is in the allowlist, non-zero otherwise.
# Matches on host or host:port, so 127.0.0.1:18000 permits 127.0.0.1 at any
# port only when the allowlist row has no port.
burp_host_allowed() {
  target=$1
  [ -s "${ALLOWLIST_FILE:-/state/allowlist.txt}" ] || return 1
  needle=$(burp_normalize_host "$target")
  while IFS= read -r row; do
    [ -z "$row" ] && continue
    case "$row" in
      "$needle" | "$needle":*) return 0 ;;
      *:"$needle") return 0 ;;
    esac
  done < "${ALLOWLIST_FILE:-/state/allowlist.txt}"
  return 1
}

# Wait up to SECONDS for an HTTP service to answer on URL. Any HTTP status,
# including 401 or 404, counts as reachable; only a connection failure is
# unhealthy. Auth is passed when USER is non-empty.
burp_wait_http() {
  url=$1
  seconds=${2:-180}
  user=${3:-}
  pass=${4:-}
  _i=0
  while [ "$_i" -lt "$seconds" ]; do
    if [ -n "$user" ]; then
      code=$(curl -s -o /dev/null -w '%{http_code}' -u "$user:$pass" --max-time 3 "$url" 2>/dev/null || true)
    else
      code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 3 "$url" 2>/dev/null || true)
    fi
    if [ -n "$code" ] && [ "$code" != "000" ]; then
      return 0
    fi
    sleep 1
    _i=$((_i + 1))
  done
  return 1
}

# Write the connection descriptor later phases consume. Lives under STATE_DIR,
# which compose bind-mounts to .session-state/<target>/burp/ on the host.
burp_write_connection_json() {
  : "${STATE_DIR:?STATE_DIR unset}"
  : "${BURP_API_PORT:?BURP_API_PORT unset}"
  : "${BURP_PROXY_PORT:?BURP_PROXY_PORT unset}"
  session_id=${BURP_SESSION_ID:-$(cat /proc/sys/kernel/random/uuid 2>/dev/null || date +%s%N)}
  conn=${STATE_DIR}/connection.json
  cat > "$conn" <<EOF
{
  "service": "burp",
  "session_id": "$session_id",
  "started_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "burp_version": "${BURP_VERSION:-unknown}",
  "java_version": "${BURP_JAVA_VERSION:-unknown}",
  "edition": "professional",
  "license_state": "${BURP_LICENSE_STATE:-trial}",
  "rest_api": {
    "host": "127.0.0.1",
    "port": "$BURP_API_PORT",
    "url": "http://127.0.0.1:$BURP_API_PORT/v0.1/",
    "auth": "${BURP_REST_AUTH:-basic}"
  },
  "proxy": {
    "host": "127.0.0.1",
    "port": "$BURP_PROXY_PORT",
    "url": "http://127.0.0.1:$BURP_PROXY_PORT"
  },
  "allowlist_hash": "${BURP_ALLOWLIST_HASH:-}",
  "allowlist_count": "${BURP_ALLOWLIST_COUNT:-0}",
  "workdir": "/workspace",
  "state_dir": "$STATE_DIR",
  "state": "$1"
}
EOF
  chmod 600 "$conn"
  cat "$conn"
}

# Best-effort scope application from the allowlist. The exact REST surface of
# the pinned Burp version is a phase 1 validation task, so this returns failure
# until the endpoint is confirmed; the wrapper allowlist gate is the reliable
# fail-closed control in this phase.
burp_apply_scope() {
  burp_log "scope application from the REST API not validated against this version; wrapper allowlist is the phase 1 control"
  return 1
}

burp_scope_clear() {
  burp_log "scope clear from the REST API not validated against this version; baseline applies on restart"
  return 1
}
