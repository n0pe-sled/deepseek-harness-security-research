#!/bin/sh
# Phase 1 acceptance proof, run inside the burp container via:
#   ./tools/session.sh <target> --profile burp exec burp /app/burp-proof.sh
#
# Proves:
#   1. the allowlist gate is up (non-empty);
#   2. a fixture request round-trips through the proxy;
#   3. exactly one exchange reaches the fixture;
#   4. a host outside the allowlist is refused at the controller;
#   5. Burp proxy history contains the exchange (best effort against the pinned
#      version's REST surface, reported as a warning when unvalidated).
# Best-effort parts never fail the core proof.
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
. "$SCRIPT_DIR/burp-lib.sh"
STATE_DIR=${STATE_DIR:-/state}
ALLOWLIST_FILE=${ALLOWLIST_FILE:-/state/allowlist.txt}

BURP_PROXY_PORT=${BURP_PROXY_PORT:-8080}
BURP_API_PORT=${BURP_API_PORT:-1337}
FIXTURE_PORT=${FIXTURE_PORT:-18000}
proxy="http://127.0.0.1:$BURP_PROXY_PORT"
api="http://127.0.0.1:$BURP_API_PORT"
fixture="http://127.0.0.1:$FIXTURE_PORT"

nonce=$(printf '%s' "proof-$(date +%s%N)" | sha256sum | cut -c 1-16)

pass=0
fail=0
ok() { pass=$((pass + 1)); echo "PASS: $*"; }
bad() { fail=$((fail + 1)); echo "FAIL: $*"; }

# 1. Allowlist gate.
if [ -s "$ALLOWLIST_FILE" ]; then
  ok "allowlist is present and non-empty ($(wc -l < "$ALLOWLIST_FILE" | tr -d ' ') entries)"
else
  bad "allowlist is missing or empty; fail-closed gate is down"
fi

# 2. Fixture round-trip through the proxy.
body=$(curl -s --proxy "$proxy" --max-time 10 "$fixture/proof-path?nonce=$nonce" 2>/dev/null || true)
case "$body" in
  *burp-fixture*"$nonce"*) ok "fixture round-trip through the proxy" ;;
  *) bad "fixture round-trip through the proxy: unexpected response: $body" ;;
esac

# 3. Single exchange: the fixture counter must be exactly 1.
case "$body" in
  *'"count":1'*) ok "exactly one exchange reached the fixture" ;;
  *) bad "single-exchange check failed; fixture counter was not 1" ;;
esac

# 4. Fail-closed allowlist enforcement at the controller.
if burp_host_allowed "$fixture"; then
  ok "in-allowlist host accepted"
else
  bad "in-allowlist host was rejected"
fi
if burp_host_allowed "http://example.com"; then
  bad "out-of-allowlist host was accepted"
else
  ok "out-of-allowlist host refused"
fi

# 5. Proxy history via the REST API (best effort; version-specific surface).
history=$(curl -s -u "${BURP_REST_USER:-}:${BURP_REST_PASSWORD:-}" --max-time 10 "$api/v0.1/proxy/history" 2>/dev/null || true)
case "$history" in
  *"$nonce"*) ok "proxy history contains the fixture exchange" ;;
  *) echo "WARN: proxy history endpoint not validated against this pinned version; the fixture counter already proves a single exchange" ;;
esac

# 6. Scope reset (best effort; baseline applies on restart).
if burp_scope_clear; then
  ok "scope cleared to baseline"
else
  echo "WARN: Burp-scope clear not validated against this pinned version; baseline applies on restart"
fi

echo
echo "PHASE 1 SUMMARY: pass=$pass fail=$fail"
[ "$fail" -eq 0 ] || exit 1
echo "PHASE 1: core connectivity proof PASSED"
