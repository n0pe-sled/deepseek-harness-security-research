#!/bin/sh
set -eu

framework_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
preset="$framework_root/dsh/agent-presets/security-research/agent.cordis.yml"

test -f "$preset"
test "$(rg -c "name: '@deepseek-ai/dsh-tool-subagent'" "$preset")" -eq 1
rg -q 'toolName: research_worker' "$preset"
rg -q 'enableRunInBackground: false' "$preset"
rg -q 'backgroundMode: one-shot' "$preset"
rg -q 'maxDepth: 1' "$preset"
rg -q 'thresholdRatio: 0.65' "$preset"
rg -q 'retainRatio: 0.15' "$preset"
rg -q 'default: security-research' "$framework_root/dsh/security-research-default.cordis.patch.yml"

if rg -q 'dsh-tool-ralph|dsh-tool-workflow|subagent-fork' "$preset"; then
  echo "validation failed: forbidden concurrent delegation surface" >&2
  exit 1
fi

for skill in "$framework_root"/skills/*/SKILL.md; do
  test -f "$skill"
  rg -q '^name: [a-z0-9-]+$' "$skill"
  rg -q '^description: .+' "$skill"
done

for contract in task-packet worker-report candidate experiment chain; do
  contract_path="$framework_root/project-template/analysis/research/contracts/$contract.md"
  if test ! -f "$contract_path"; then
    echo "validation failed: campaign template is missing $contract_path" >&2
    exit 1
  fi
done

test -f "$framework_root/dsh/mcp/ludus.cordis.yml"
rg -q '@badsectorlabs/ludus-mcp@0.2.0' "$framework_root/dsh/mcp/ludus.cordis.yml"
rg -q 'Never ask for confirmation' "$framework_root/project-template/roles/infrastructure.md"
test -f "$framework_root/dsh/mcp/managed-java-jd-mcp-duo.cordis.yml"
rg -q 'serverName: java_bytecode' "$framework_root/dsh/mcp/managed-java-jd-mcp-duo.cordis.yml"
rg -q 'command: /opt/ghidra-mcp-bridge/bin/bridge-mcp-ghidra' "$framework_root/dsh/mcp/native-ghidra.cordis.yml"
rg -q 'ghidra-headless:' "$framework_root/compose.yaml"
rg -q 'GHIDRA_MCP_FILE_ROOT: /workspace' "$framework_root/compose.yaml"
rg -q 'GHIDRA_MCP_ALLOW_SCRIPTS: 0' "$framework_root/compose.yaml"
rg -q 'pnpm --dir /opt/deepseek-harness dsh' "$framework_root/docker/entrypoint.sh"
rg -q 'n0pe-sled/deepseek-harness.git' "$framework_root/docker/Dockerfile"
rg -q 'n0pe-sled/deepseek-harness-plugins.git' "$framework_root/docker/Dockerfile"
rg -q 'n0pe-sled/deepseek-harness-skills.git' "$framework_root/docker/Dockerfile"
rg -q 'for plugin in skill-mcp-manager system-prompt-editor web-search-searxng' "$framework_root/docker/entrypoint.sh"
if rg -q '!!js \[' "$framework_root/dsh"; then
  echo "validation failed: !!js sequence tags are unsupported; quote the complete JS expression" >&2
  exit 1
fi
if rg -q 'DSH_SPEC|npm install --global.*@deepseek-ai/dsh' "$framework_root/docker/Dockerfile" "$framework_root/compose.yaml"; then
  echo "validation failed: published DSH install remains" >&2
  exit 1
fi

echo "static validation passed: one foreground worker, depth one, no alternate delegation"
