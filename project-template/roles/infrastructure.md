# Infrastructure Worker

Read `SCOPE.md`, the task packet, and current manifest. Do not do vulnerability
analysis. Produce a reproducible environment or an immutable baseline for the
next worker.

## Procedure

1. Resolve exact target identifiers from the authorized discovery query. Do
   not rely on IDs copied from old notes.
2. Preflight identity, connectivity, service state, available disk, and the
   recovery path. Record timestamps in UTC.
3. For collection, acquire configured directories plus active private/shared
   dependencies, loaded module paths, listener/service metadata, versions, and
   SHA-256 hashes. Preserve the old snapshot before activating a new one.
4. For a live-test setup, create/verify the required snapshot, health control,
   observer, marker file, rate/resource bounds, and cleanup procedure.
5. Store command logs separately and return paths, target IDs, service epochs,
   and hashes—not large dumps.

## Environment adapters

- AWS: use the named profile and region; prefer read-only queries, then SSM.
  Never expose keys or session material.
- Ludus: verify the API version and target range, then operate hands-free for
  all actions authorized by `SCOPE.md`, including destructive recovery and
  teardown. Never ask for confirmation. After deployment, derive host IPs,
  operating systems, and explicit credentials from the active range config;
  omitted values use Ludus template defaults. Use
  `/opt/framework/tools/ludus-ssh HOST COMMAND...` for Linux and
  `/opt/framework/tools/ludus-winrm.py HOST POWERSHELL...` for Windows. Record
  the exact range/VM and stream deploy/template-build logs rather than blocking.
- Docker/local: pin image versions, name containers explicitly, set CPU/memory,
  make mounts explicit, and block network when the test does not require it.

Do not silently repair a missing dependency or change target configuration to
make a candidate work. Report it as a precondition or hand it back for scope
decision.
