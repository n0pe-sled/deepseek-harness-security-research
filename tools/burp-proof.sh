#!/bin/sh
# Host orchestration for the phase 1 Burp connectivity proof.
#
# Usage:  tools/burp-proof.sh RESEARCH_TARGET [--teardown]
#
# Builds and starts the burp profile (burp + burp-fixture), waits until the
# service is healthy, runs the in-container proof, and reports. With
# --teardown it stops the profile afterwards. State is preserved under
# $RESEARCH_WORK_ROOT/.session-state/$RESEARCH_TARGET/burp.
#
# Requires .env with RESEARC_WORK_ROOT, and BURP_VERSION/BURP_SHA256 plus
# BURP_DIST_URL (or burp/dist/burpsuite_pro.jar in the build context).
set -eu

target=${1:?usage: tools/burp-proof.sh RESEARCH_TARGET [--teardown]}
case "$target" in
  ''|*[!a-z0-9_-]*) echo "tools/burp-proof.sh: RESEARCH_TARGET must use lowercase letters, numbers, underscores, or hyphens" >&2; exit 2 ;;
esac
teardown=0
[ "${2:-}" = "--teardown" ] && teardown=1

framework_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
test -f "$framework_root/.env" || { echo "tools/burp-proof.sh: copy .env.example to .env and populate it first" >&2; exit 2; }

compose() {
  (
    cd "$framework_root"
    RESEARCH_TARGET=$target docker compose --env-file "$framework_root/.env" \
      -f "$framework_root/compose.yaml" --profile burp "$@"
  )
}

echo "==> building and starting the burp profile"
compose up -d --build

echo "==> waiting for burp to become healthy"
i=0
cid=""
status=""
while [ $i -lt 150 ]; do
  cid=$(compose ps -q burp 2>/dev/null || true)
  if [ -n "$cid" ]; then
    status=$(docker inspect --format '{{.State.Health.Status}}' "$cid" 2>/dev/null || true)
    if [ "$status" = "healthy" ]; then
      echo "==> burp healthy"
      break
    fi
  fi
  i=$((i + 1))
  sleep 2
done
if [ "$status" != "healthy" ]; then
  echo "burp did not become healthy" >&2
  compose logs burp 2>&1 | tail -n 60 >&2
  exit 1
fi

echo "==> running the phase 1 proof inside the container"
compose exec -T burp /app/burp-proof.sh
rc=$?

if [ "$teardown" -eq 1 ]; then
  echo "==> tearing down the burp profile"
  compose down
fi

exit "$rc"
