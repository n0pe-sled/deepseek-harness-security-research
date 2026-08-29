# Transport and license model for the containerized headless Burp service
# Phase 1 (feature/burp-container)

## Decision

Burp runs as its own isolated Compose service, `burp`, that joins
`network_mode: service:network-anchor` exactly like `ghidra-headless`. That
means the REST API, the proxy, and any proof fixtures all live on the same
loopback the DSH session uses. Nothing binds a LAN interface; the only port
published to the host is `DSH_PORT` on the existing `network-anchor` service.

Two channels matter:

- **Proxy channel**: DSH session tools route through the proxy by setting
  `HTTP_PROXY`/`HTTPS_PROXY` to `http://127.0.0.1:$BURP_PROXY_PORT` when a
  campaign authorizes interception. This is opt-in at the tooling layer.
- **Control channel**: a bounded MCP bridge (phase 3) talks to the headless
  REST API at `http://127.0.0.1:$BURP_API_PORT/v0.1/`. The stdio bridge would
  live in the DSH image and the service stays isolated, mirroring how the
  ghidra stdio bridge works against the isolated sidecar.

## Why loopback, not a published port

The repo already established this shape for Ghidra: a heavyweight parser in its
own namespace, a small stdio bridge in DSH, and persistent state under
`.session-state/<target>/`. Burp is the same weight class. Publishing the proxy
on the host LAN would hand anyone on the LAN an interception point, which is
why this phase binds everything to the shared loopback only.

## License model

- Phase 1 runs in **trial mode** (`BURP_REQUIRE_LICENSE=0`) so connectivity can
  be proven without a key. A fresh Burp Professional install includes a free
  evaluation period with the REST API enabled.
- Sustained use requires a Professional license. `BURP_REQUIRE_LICENSE=1`
  demands a key in `BURP_LICENSE_KEY` or a license file on the read-only
  `/run/license` mount (session state on the host) and refuses to start without
  one.
- License material is never committed, never baked into an image layer, and
  written (when passed by env) only to `/run` (tmpfs) with `umask 077`.
- Burp Community has no headless REST API; it is out of scope and recorded as
  deferred in issue #18.

## Fail-closed controls in this phase

| Control | Mechanism | Owner |
|---|---|---|
| Non-empty target allowlist | entrypoint refuses to start when `BURP_TARGET_ALLOWLIST` is empty | `burp-entrypoint.sh` |
| Out-of-scope sends | `burp_host_allowed` rejected by the controller before any proxied request | `burp-lib.sh`, `burp-proof.sh` |
| Loopback-only bind | compose `network_mode: service:network-anchor`, no host port for Burp | `compose.yaml` |
| Credentials | no model/DSH/GitHub/Ludus/cloud creds in the Burp container | compose env |

Burp's own scope is only applied best-effort in this phase; the exact REST
surface of the pinned version must be validated before scope and history tools
become authoritative (phase 3).

## Connection descriptor

`burp_write_connection_json` emits `.session-state/<target>/burp/connection.json`
(after `connection.json` in the Android emulator design) with: session id,
started-at, Burp and Java versions, license state, REST API and proxy
addresses, allowlist hash and count, workdir, and state. Later phases and the
MCP tools key every operation to this descriptor and refuse stale or foreign
session ids.

## Phase 1 validation task

The one open technical variable is whether the pinned Burp version exposes the
native REST API flags (`--headless --rest-api --port`) and its exact endpoint
paths (`/v0.1/proxy/history`, configurator endpoints). `BURP_REST_ARGS` exists
so the operator can adjust the launch line without editing code. The
`burp-proof.sh` script reports history/scope checks as warnings until those
endpoints are confirmed against the pinned version, and the fixture counter
provides the authoritative single-exchange assertion in the meantime.
