# Campaign Scope

## Objective

Find and independently reproduce: `<exact security impact>`.

## Authorization

- Owner/authorization record: `<reference>`
- Authorized targets: `<identifiers and environments>`
- Attacker position: `<remote/local/authenticated/unauthenticated>`
- Allowed techniques: `<boundaries>`
- Forbidden techniques: internet exposure, third-party targets, denial of
  service, persistence, or destructive state changes unless expressly listed.

## Baseline acquisition

- Environment kind: `<aws|ludus|docker|local>`
- Exact discovery query: `<query; never paste secrets>`
- Required runtime services/modules/configuration: `<list>`
- Artifact paths: `<list>`

## Success proof

- Required starting access: `<what the attacker has>`
- Required effect: `<command execution, authority, marker-file read, etc.>`
- Proof target/file: `<authorized marker>`
- Clean-reset procedure: `<snapshot/redeploy/recreate>`

## Research limits

- External research: `<none|narrow protocol/API docs|explicit sources>`
- Artifact retention: `<location and secret policy>`
- Maximum request rate/runtime/resource consumption: `<limits>`
