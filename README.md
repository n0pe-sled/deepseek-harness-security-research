# Security Research Agent Framework for DeepSeek Harness

This package turns one DeepSeek Harness session into a persistent security
research orchestrator. The orchestrator may run one foreground worker at a
time. Infrastructure, discovery, simulation, and validation are worker modes,
not concurrently running teams.

The Docker image fetches the pinned revision of
`n0pe-sled/deepseek-harness`, installs its locked pnpm workspace, builds all
production artifacts from source, and launches that source checkout with
`pnpm dsh`. It does not install the published `@deepseek-ai/dsh` package.
The image also checks out pinned revisions of `n0pe-sled/deepseek-harness-plugins`
and `n0pe-sled/deepseek-harness-skills`, rebuilds all custom plugins from
source, registers them in the Web profile, and seeds the custom skills into the
persistent agent-skills root. This includes `unslop`, `skill-mcp-manager`, and
`system-prompt-editor`.

The hard scheduling controls are in the supplied agent preset:

- one `research_worker` delegation tool;
- foreground, one-shot delegation with no background argument;
- `maxDepth: 1`, so a root orchestrator can create one child and that child
  cannot delegate;
- no fork, workflow, Ralph, or other delegation tools.

Automatic compaction is explicit: at 65% of the routed model's context window,
the agent summarizes older balanced history and retains the newest 15%
verbatim. For a one-million-token route this means a roughly 650,000-token
trigger and 150,000-token retained tail. Manual `/compact` remains available.

Foreground execution blocks the orchestrator until the worker terminates. This
gives a maximum of two agents in the campaign: orchestrator plus one worker.
Separate root sessions remain an operator responsibility.

## Package layout

- `project-template/AGENTS.md`: campaign controller and evidence gates.
- `roles/`: bounded worker contracts passed in task packets.
- `skills/`: role guides compatible with `deepseek-harness-skills`.
- `dsh/agent-presets/`: importable DeepSeek agent preset.
- `dsh/mcp/`: real upstream MCP configuration rows and adapter guidance.
- `project-template/analysis/research/`: durable campaign state and schemas.
- `tools/install.sh`: installer for the existing skills/plugins layout.

## Install

Set the locations of stable checkouts, then run:

```bash
export DSH_SKILLS_REPO="$HOME/deepseek-harness-skills"
export DSH_PLUGINS_REPO="$HOME/deepseek-harness-plugins"
./tools/install.sh
```

The installer never overwrites a skill or preset. `DSH_HOME`,
`DSH_AGENTS_HOME`, `DSH_SKILLS_REPO`, and `DSH_PLUGINS_REPO` may be set for
non-default layouts.

Create a campaign by copying `project-template`, edit `SCOPE.md`, and start DSH
with that directory as the session working directory. Pick the
`Security Research (two-agent)` preset. Add MCP rows with your Skill & MCP
Manager or pass one of the overlays documented under `dsh/mcp/`.

Use one managed backend and, when needed, one native backend. Small models
perform worse when overlapping decompilers return conflicting symbol models.

The framework reuses your Skill & MCP Manager for live MCP lifecycle and your
System Prompt Editor for optional machine-level additions. The campaign
`AGENTS.md` remains authoritative; do not put target-specific facts into the
global prompt editor.

Set `ENABLE_RTX_SPARK=1` plus the private `RTX_SPARK_BASE_URL` and
`RTX_SPARK_API_KEY` in `.env` to register the bundled OpenAI-compatible custom
route. Its display name, model id/name, and context window are also overridable
from `.env`; the default capacity is 1,048,576 tokens.

## Docker Compose

Copy `.env.example` to `.env`, fill model/Ludus variables, and run from
the repository root:

```bash
cp .env.example .env
docker compose up --build
```

An empty `CAMPAIGN_DIR` is initialized from the generic project template.
DSH state and the campaign are bind-mounted, so
container replacement does not lose evidence. DSH stays bound to the container
loopback and a small in-container TCP proxy publishes only the selected host
loopback port. The UI remains local at `http://127.0.0.1:3080` (or
`DSH_PORT`). The host Docker socket is not mounted.

The normal launch includes the pinned jd-mcp-duo JAR/JDK, Wireshark MCP/tshark,
and the heavyweight Ghidra headless sidecar. Disable individual analyzers with
`ENABLE_JAVA_MCP=0`, `ENABLE_WIRESHARK_MCP=0`, or `ENABLE_GHIDRA_MCP=0`; the
sidecar is still built, but no Ghidra tools enter that DSH session.

Ludus has two paths. Its MCP calls the HTTPS control-plane API. By default,
`LUDUS_RANGE_CONNECT=auto` also retrieves the current user's WireGuard client
configuration from that API, starts an in-container tunnel, and thereby gives
shell tools and protocol clients direct access to the user's range VM routes.
The generated peer private key lives only under `/run` in the container. If
Docker Desktop is already connected through the host's working Ludus VPN, use
`LUDUS_RANGE_CONNECT=host`; use `api-only` when no direct VM traffic is needed.
The container has only `NET_ADMIN` plus `/dev/net/tun`, not host networking or
the Docker socket.

Ghidra is the one intentional analysis sidecar: its stdio bridge is small, but
the server requires a real Ghidra/JDK installation. It has a separate
filesystem, persistent named volumes, a read-only campaign mount, and shares
only a private network namespace with DSH so the security-hardened upstream
bridge can use loopback. The Java and Wireshark stdio services
live in DSH because their complete local engines are bundled and do not need
independent network services.
