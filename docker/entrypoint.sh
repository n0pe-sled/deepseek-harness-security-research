#!/bin/sh
set -eu

dsh_root=${DSH_HOME:-/state/dsh}
agents_root=${DSH_AGENTS_HOME:-/state/agents}
campaign_root=/workspace
trusted_host=${DSH_TRUSTED_HOST:-localhost:${DSH_PORT:-3080}}
internal_port=${DSH_INTERNAL_PORT:-39080}
dsh_bin=/opt/framework/docker/dsh-launch.mjs

mkdir -p "$dsh_root/.agent-presets" "$dsh_root/skills" "$agents_root/skills" "$campaign_root"

if test ! -e "$dsh_root/.agent-presets/security-research"; then
  cp -R /opt/framework/dsh/agent-presets/security-research "$dsh_root/.agent-presets/security-research"
fi

for source in /opt/framework/skills/*; do
  name=$(basename "$source")
  if test ! -e "$dsh_root/skills/$name"; then
    cp -R "$source" "$dsh_root/skills/$name"
  fi
done

for source in /opt/deepseek-harness-skills/*; do
  name=$(basename "$source")
  if test -f "$source/SKILL.md" && test ! -e "$agents_root/skills/$name"; then
    cp -R "$source" "$agents_root/skills/$name"
  fi
done

if test ! -f "$campaign_root/SCOPE.md"; then
  cp -R /opt/framework/project-template/. "$campaign_root/"
fi

for plugin in skill-mcp-manager system-prompt-editor web-search-searxng; do
  pnpm --dir /opt/deepseek-harness exec node --import tsx/esm "$dsh_bin" plugin --profile web add \
    "/opt/deepseek-harness-plugins/$plugin" --offline >/dev/null
done

set -- pnpm --dir /opt/deepseek-harness exec node --import tsx/esm "$dsh_bin" --profile web --patch /opt/framework/dsh/security-research-default.cordis.patch.yml

if test "${ENABLE_RTX_SPARK:-0}" = 1; then
  if test -z "${RTX_SPARK_BASE_URL:-}"; then
    echo "ENABLE_RTX_SPARK=1 requires RTX_SPARK_BASE_URL" >&2
    exit 2
  fi
  case "${RTX_SPARK_REASONING_EFFORT:-high}" in
    low|medium|high|max) ;;
    *) echo "RTX_SPARK_REASONING_EFFORT must be low, medium, high, or max" >&2; exit 2 ;;
  esac
  set -- "$@" --patch /opt/framework/dsh/models/rtx-spark.cordis.yml
fi

if test "${ENABLE_LUDUS_MCP:-0}" = 1; then
  if test -z "${LUDUS_URL:-}"; then
    echo "ENABLE_LUDUS_MCP=1 requires LUDUS_URL in the container environment" >&2
    exit 2
  fi
  if test -z "${LUDUS_API_KEY:-}"; then
    echo "ENABLE_LUDUS_MCP=1 requires LUDUS_API_KEY in the container environment" >&2
    exit 2
  fi
  set -- "$@" --patch /opt/framework/dsh/mcp/ludus.cordis.yml
fi

if test "${ENABLE_JAVA_MCP:-0}" = 1; then
  if test ! -x /opt/java/openjdk/bin/java || test ! -f /opt/jd-mcp-duo/jd-mcp-duo.jar; then
    echo "ENABLE_JAVA_MCP=1 but the pinned jd-mcp-duo runtime is missing" >&2
    exit 2
  fi
  set -- "$@" --patch /opt/framework/dsh/mcp/managed-java-jd-mcp-duo.cordis.yml
fi

if test "${ENABLE_GHIDRA_MCP:-0}" = 1; then
  ghidra_tries=0
  until curl -fsS "${GHIDRA_MCP_URL:-http://127.0.0.1:8089/}check_connection" >/dev/null; do
    ghidra_tries=$((ghidra_tries + 1))
    if test "$ghidra_tries" -ge 60; then
      echo "Ghidra MCP did not become ready within five minutes" >&2
      exit 2
    fi
    sleep 5
  done
  set -- "$@" --patch /opt/framework/dsh/mcp/native-ghidra.cordis.yml
fi

if test "${ENABLE_WIRESHARK_MCP:-0}" = 1; then
  if ! command -v tshark >/dev/null || test ! -x /opt/wireshark-mcp/bin/wireshark-mcp; then
    echo "ENABLE_WIRESHARK_MCP=1 but the pinned Wireshark MCP runtime is missing" >&2
    exit 2
  fi
  set -- "$@" --patch /opt/framework/dsh/mcp/capture-wireshark.cordis.yml
fi

if test "${ENABLE_LUDUS_MCP:-0}" = 1 && test "${LUDUS_RANGE_CONNECT:-auto}" != api-only; then
  /opt/framework/docker/ludus-wireguard.py
fi

socat "TCP-LISTEN:${DSH_PORT:-3080},fork,reuseaddr,bind=0.0.0.0" "TCP:127.0.0.1:$internal_port" &
echo "dsh Docker host endpoint: http://127.0.0.1:${DSH_PORT:-3080}"

set -- "$@" -- --no-open --host 127.0.0.1 --port "$internal_port" --trusted-host "$trusted_host"
exec "$@"
