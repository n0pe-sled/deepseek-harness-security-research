# Security Research MCP Profiles

Add these through `dsh --profile web --patch <file>` or transcribe the values into your
installed Skill & MCP Manager. The manager reports them as external if supplied
by an overlay and preserves rows it does not own.

| Overlay | Intended worker | Status |
|---|---|---|
| `managed-dotsider` | discovery of managed .NET, NativeAOT, metadata, IL, runtime trace | recommended first .NET backend |
| `managed-rbinilspy` | token-bounded ILSpy C#/IL/usage/resource queries | alternative .NET backend |
| `managed-java-jd-mcp-duo` | Java/JVM discovery | JAR/class decompilation, bytecode, index, xrefs, hierarchy, call chains |
| `native-ghidra` | native discovery | direct Ghidra MCP with strict program selectors |
| `native-binary-mcp` | discovery static native/PE plus simulation/debugging | composite Ghidra/x64dbg/WinDbg/ILSpy server |
| `capture-wireshark` | simulation/validation | structured PCAP analysis; do not use live capture without explicit bounds |
| `aws-api` | infrastructure only | optional; AWS CLI/SSM remains the deterministic fallback |
| `ludus` | infrastructure only | official Bad Sector Labs MCP; full hands-free API access |

Use one of Dotsider or rbinilspy for the active campaign. Use one of direct
Ghidra or Binary MCP for native work. Binary MCP already contains Ghidra and an
ILSpy surface; do not add it alongside every specialized backend unless the
campaign has demonstrated a missing capability.

For JVM services, `jd-mcp-duo` is preferred over a decompile-only bridge: its
bounded call graph, hierarchy, resource search, and exact bytecode tools make
artifact/source verification possible. Use Vineflower as the normal engine and
`show_bytecode` to resolve disputed ordering. A call-chain result is Class
Hierarchy Analysis, not a proof of live dispatch.

“Binary Defense” has no public MCP integration matching these workflows. If
you meant binary analysis/defense tooling, `native-binary-mcp` is the included
integration.

## Server-specific constraints

- Dotsider: install with `dotnet tool install -g Dotsider.Mcp`; executable is
  `dotsider-mcp`.
- rbinilspy: build its ILSpy worker and Rust server, then set `RBINILSPY_PATH`.
- jd-mcp-duo: the Compose image downloads and checksum-verifies the pinned JAR,
  supplies JDK 25, and writes its SQLite index inside the campaign's
  `analysis/research/indexes/` directory.
- Binary MCP: clone `Sarks0/binary-mcp`, run `uv sync`, set
  `DSH_BINARY_MCP_DIR`, and set relevant analysis-tool paths.
- Ghidra: Compose builds the reviewed GhidraMCP headless engine in its own
  unprivileged container. The stdio bridge is pinned into the DSH image. Keep
  strict program selectors enabled and leave script execution disabled.
- Wireshark: Compose bundles the reviewed Wireshark MCP 2.0.0 commit and
  `tshark`. Its allowed
  input/output root is `/workspace`, preventing PCAP object export from
  writing outside the campaign.
- AWS API: set named `AWS_PROFILE`/`AWS_REGION`; pin
  `DSH_AWS_API_MCP_SPEC` after pilot review. Never put keys in YAML.
- Ludus: export `LUDUS_API_KEY` only in the DSH launch environment and supply
  `LUDUS_URL` from the private `.env`. The official MCP requires Ludus v2 and
  exposes every API operation through `call_ludus_api`; no confirmation stage
  is added. `LUDUS_RANGE_CONNECT=auto` independently retrieves an ephemeral
  per-user WireGuard config from that API for direct VM access. Reference:
  https://docs.ludus.cloud/docs/using-ludus/mcp/

These upstream servers are processes, not research agents, so they do not
count against the worker concurrency budget. Some include state-changing and
generic command tools. Tool visibility in a shared MCP client is not a security
boundary; the role contracts and DSH sandbox/approval layer still govern use.

## Why the deployment is hybrid

`stdio` describes how an MCP wrapper communicates; it does not mean the
underlying product is bundled. API clients such as Ludus and AWS need no local
engine, though Ludus direct VM traffic needs its range route. jd-mcp-duo and
Wireshark MCP are bundled into DSH. Ghidra needs a Java/Ghidra backend, so Compose
isolates that heavyweight parser and persists only `/data` and `/projects`.
The campaign is mounted at the same `/workspace` path in both containers so
program selectors resolve without giving Ghidra write access to evidence.
