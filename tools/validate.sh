#!/bin/sh
set -eu

framework_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
preset="$framework_root/dsh/agent-presets/security-research/agent.cordis.yml"

test -f "$preset"
test "$(rg -c "name: '@deepseek-ai/dsh-tool-subagent'" "$preset")" -eq 1
rg -q 'toolName: research_worker' "$preset"
rg -q 'enableRunInBackground: true' "$preset"
rg -q 'backgroundMode: one-shot' "$preset"
rg -q 'maxDepth: 1' "$preset"
rg -q "agentOptions:.*ENABLE_RTX_SPARK.*provider: 'rtx-spark'" "$preset"
rg -q 'thresholdRatio: 0.65' "$preset"
rg -q 'retainRatio: 0.15' "$preset"
rg -q 'default: security-research' "$framework_root/dsh/security-research-default.cordis.patch.yml"
test -f "$framework_root/dsh/web-search-searxng.cordis.patch.yml"
rg -q 'searchProvider: searxng' "$framework_root/dsh/web-search-searxng.cordis.patch.yml"
rg -q -U 'id: web-search-deepseek\n  name:.*\n  disabled: true' "$framework_root/dsh/web-search-searxng.cordis.patch.yml"
rg -q 'web-search-searxng.cordis.patch.yml' "$framework_root/docker/entrypoint.sh"
rg -q 'load unslop on the first step' "$preset"

if rg -q 'dsh-tool-ralph|dsh-tool-workflow|subagent-fork' "$preset"; then
  echo "validation failed: forbidden concurrent delegation surface" >&2
  exit 1
fi

if test -d "$framework_root/skills"; then
  echo "validation failed: skills/ was removed from this repo; skills now live in \$DSH_SKILLS_REPO" >&2
  exit 1
fi
skills_root=${DSH_SKILLS_REPO:-"$HOME/deepseek-harness-skills"}
if test -d "$skills_root"; then
  for skill in $(find "$skills_root" -mindepth 2 -maxdepth 3 -name SKILL.md | sort); do
    test -f "$skill"
    rg -q '^name: [a-z0-9-]+$' "$skill"
    rg -q '^description: .+' "$skill"
  done
fi

for contract in task-packet worker-report candidate experiment chain; do
  contract_path="$framework_root/project-template/analysis/research/contracts/$contract.md"
  if test ! -f "$contract_path"; then
    echo "validation failed: campaign template is missing $contract_path" >&2
    exit 1
  fi
done

test -f "$framework_root/project-template/analysis/research/settings.yaml"
rg -q '^max_workers: [0-9]+$' "$framework_root/project-template/analysis/research/settings.yaml"
rg -q 'max_workers' "$framework_root/project-template/AGENTS.md"

test -f "$framework_root/dsh/mcp/ludus.cordis.yml"
rg -q '@badsectorlabs/ludus-mcp@0.2.0' "$framework_root/dsh/mcp/ludus.cordis.yml"
rg -q 'Never ask for confirmation' "$framework_root/project-template/roles/infrastructure.md"
test -f "$framework_root/dsh/mcp/managed-java-jd-mcp-duo.cordis.yml"
test -f "$framework_root/dsh/models/rtx-spark.cordis.yml"
rg -q 'rtx-spark:' "$framework_root/dsh/models/rtx-spark.cordis.yml"
rg -q 'id: agent-default-model' "$framework_root/dsh/models/rtx-spark.cordis.yml"
rg -q 'provider: rtx-spark' "$framework_root/dsh/models/rtx-spark.cordis.yml"
rg -q 'serverName: java_bytecode' "$framework_root/dsh/mcp/managed-java-jd-mcp-duo.cordis.yml"
rg -q 'serverName: wireshark' "$framework_root/dsh/mcp/capture-wireshark.cordis.yml"
rg -q 'WIRESHARK_MCP_ALLOWED_DIRS: /workspace' "$framework_root/dsh/mcp/capture-wireshark.cordis.yml"
rg -q 'LUDUS_RANGE_CONNECT.*auto' "$framework_root/compose.yaml"
rg -q 'sshpass' "$framework_root/docker/Dockerfile"
rg -q 'pywinrm==0.5.0' "$framework_root/docker/Dockerfile"
rg -Fq 'PATH=/opt/java/openjdk/bin:$PATH' "$framework_root/docker/Dockerfile"
test -f "$framework_root/tools/ludus-ssh"
test -f "$framework_root/tools/ludus-winrm.py"
rg -q 'LUDUS_KALI_SSH_USER=kali' "$framework_root/.env.example"
rg -q 'LUDUS_KALI_SSH_PASSWORD=kali' "$framework_root/.env.example"
rg -q 'LUDUS_KALI_SSH_USER.*kali' "$framework_root/compose.yaml"
rg -q 'LUDUS_KALI_SSH_PASSWORD.*kali' "$framework_root/compose.yaml"
rg -q 'try_password kali-template' "$framework_root/tools/ludus-ssh"
rg -q 'RESEARCH_WORK_ROOT=.*ai-research-working' "$framework_root/.env.example"
rg -q '^name: dsh-.*RESEARCH_TARGET:?.*Set RESEARCH_TARGET' "$framework_root/compose.yaml"
test -x "$framework_root/tools/session.sh"
rg -Fq '*[!a-z0-9_-]*)' "$framework_root/tools/session.sh"
if rg -q '\./runtime|CAMPAIGN_DIR|DSH_STATE_DIR|DSH_AGENTS_STATE_DIR|LUDUS_SSH_DIR' "$framework_root/compose.yaml"; then
  echo "validation failed: Compose has an in-repository output fallback" >&2
  exit 1
fi
rg -q 'command: /opt/ghidra-mcp-bridge/bin/bridge-mcp-ghidra' "$framework_root/dsh/mcp/native-ghidra.cordis.yml"
rg -q 'ghidra-headless:' "$framework_root/compose.yaml"
rg -q '^FROM ghidra_source AS source$' "$framework_root/docker/Ghidra.Dockerfile"
rg -q 'GHIDRA_MCP_FILE_ROOT: /workspace' "$framework_root/compose.yaml"
rg -q 'GHIDRA_MCP_ALLOW_SCRIPTS: 0' "$framework_root/compose.yaml"
rg -Fq '127.0.0.1:${DSH_PORT:-3080}:${DSH_PORT:-3080}' "$framework_root/compose.yaml"
rg -q 'socat.*TCP-LISTEN:' "$framework_root/docker/entrypoint.sh"
rg -q 'dsh-launch.mjs' "$framework_root/docker/entrypoint.sh"
rg -Fq "process.chdir(process.env.DSH_CAMPAIGN_ROOT ?? '/workspace')" "$framework_root/docker/dsh-launch.mjs"
rg -q 'n0pe-sled/deepseek-harness.git' "$framework_root/docker/Dockerfile"
rg -q 'n0pe-sled/deepseek-harness-plugins.git' "$framework_root/docker/Dockerfile"
rg -q 'n0pe-sled/deepseek-harness-skills.git' "$framework_root/docker/Dockerfile"
rg -Fq 'for plugin_dir in /opt/deepseek-harness-plugins/*; do' "$framework_root/docker/entrypoint.sh"
rg -Fq 'test -f "$plugin_dir/package.json" || continue' "$framework_root/docker/entrypoint.sh"
rg -Fq 'for plugin_dir in /opt/deepseek-harness-plugins/*; do' "$framework_root/docker/Dockerfile"
rg -Fq 'test -f "$plugin_dir/lib/index.js"' "$framework_root/docker/Dockerfile"
rg -Fq 'test -f "$plugin_dir/lib/client.js"' "$framework_root/docker/Dockerfile"
if rg -q 'pnpm --dir .*deepseek-harness-plugins.* (install|run build)' "$framework_root/docker/Dockerfile"; then
  echo "validation failed: plugin dev dependencies must not be resolved during the image build" >&2
  exit 1
fi
if rg -q '!!js \[' "$framework_root/dsh"; then
  echo "validation failed: !!js sequence tags are unsupported; quote the complete JS expression" >&2
  exit 1
fi
if rg -q 'DSH_SPEC|npm install --global.*@deepseek-ai/dsh' "$framework_root/docker/Dockerfile" "$framework_root/compose.yaml"; then
  echo "validation failed: published DSH install remains" >&2
  exit 1
fi

echo "static validation passed: one foreground worker, depth one, no alternate delegation"
