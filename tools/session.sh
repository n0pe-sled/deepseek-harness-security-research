#!/bin/sh
set -eu

if test "$#" -lt 1; then
  echo "usage: session.sh RESEARCH_TARGET [COMPOSE COMMAND ...]" >&2
  exit 2
fi

research_target=$1
shift
case "$research_target" in
  ''|*[!a-z0-9_-]*)
    echo "session.sh: RESEARCH_TARGET must use lowercase letters, numbers, underscores, or hyphens" >&2
    exit 2
    ;;
esac

framework_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
if test ! -f "$framework_root/.env"; then
  echo "session.sh: copy .env.example to .env and populate private values first" >&2
  exit 2
fi

if test "$#" -eq 0; then
  set -- up --build
fi

RESEARCH_TARGET=$research_target
export RESEARCH_TARGET
exec docker compose --env-file "$framework_root/.env" \
  -f "$framework_root/compose.yaml" "$@"
