#!/bin/sh
set -eu

dsh_root=${DSH_HOME:-/state/dsh}
agents_root=${DSH_AGENTS_HOME:-/state/agents}
campaign_root=/workspace

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
  pnpm --dir /opt/deepseek-harness dsh plugin --profile web add \
    "/opt/deepseek-harness-plugins/$plugin" --offline >/dev/null
done

set -- pnpm --dir /opt/deepseek-harness dsh --profile web --patch /opt/framework/dsh/security-research-default.cordis.patch.yml

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
  if test ! -x "${JD_MCP_DUO_PATH:-/opt/jd-mcp-duo/bin/jd-mcp-duo}"; then
    echo "ENABLE_JAVA_MCP=1 requires a Linux jd-mcp-duo release at JD_MCP_DUO_DIR" >&2
    exit 2
  fi
  set -- "$@" --patch /opt/framework/dsh/mcp/managed-java-jd-mcp-duo.cordis.yml
fi

if test "${ENABLE_GHIDRA_MCP:-0}" = 1; then
  if ! curl -fsS "${GHIDRA_MCP_URL:-http://127.0.0.1:18089/}check_connection" >/dev/null; then
    echo "ENABLE_GHIDRA_MCP=1 requires the ghidra-headless service (--profile native)" >&2
    exit 2
  fi
  set -- "$@" --patch /opt/framework/dsh/mcp/native-ghidra.cordis.yml
fi

set -- "$@" -- --no-open --host 127.0.0.1 --port "${DSH_PORT:-3080}" --trusted-host "${DSH_TRUSTED_HOST:-localhost:3080}"
exec "$@"
