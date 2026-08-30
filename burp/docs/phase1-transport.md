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

## Phase 1 validation result (verified 2025.6.1, trial jar)

The native headless REST API is **not present** in current Burp Professional.
Verified against the freely downloaded trial jar (`product=pro&type=Jar`,
anonymous, SHA-256-pinned):

- `java -jar burpsuite_pro.jar --help` lists every supported flag. There is no
  `--headless`, `--rest-api`, or `--port`; those flags are reported as
  "Unrecognized command-line argument".
- `--version` reports `2025.6.1-39604 Burp Suite Professional`.
- The jar contains no REST API module (no `net/portswigger/**/rest*` classes);
  the launcher exits with `Could not start Burp: NullPointerException` when the
  flags are passed.

Consequences for the plan:

1. "Download the trial each time" is pullable but does not get you automation.
   Trial state and every control surface live in the GUI.
2. The containerized automate path is therefore one of:
   - **burp-rest-api extension under Xvfb** (community standard): run the Pro
     jar on a virtual framebuffer, load the open-source burp-rest-api
     extension (with `--developer-extension-class-name` or `--config-file`),
     drive it through its own API on 127.0.0.1:8090. Keeps the no-host-port
     and no-VNC-published properties; the display is virtual, not served.
     Trial activation may still need a GUI interaction on first boot, which
     is the open item to probe.
   - **Burp Enterprise** for a native headless REST API and official container
     (separate commercial product and license; not the Pro trial).
3. `BURP_REST_ARGS` remains the escape hatch for version-specific flags. The
   launch command and the proof's history/scope checks must be re-targeted to
   whichever API surface survives the pivot.

Also fixed in the same pass: the container's `/home/burp` tmpfs was
root-owned, so the unprivileged JVM could not create its user preferences
directory. `HOME=/tmp` is now set in the Compose environment (burp user owns
/tmp on tmpfs), which removes the preferences failure.
