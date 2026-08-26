---
name: security-campaign-orchestration
description: Use when starting, resuming, routing, or stopping an authorized long-running vulnerability research campaign with one foreground worker at a time
---

# Security Campaign Orchestration

Use this only in the root campaign session. Start from `SCOPE.md`, `STATE.yaml`,
the active manifest, and the approach registry. If a baseline is absent or
incoherent, route infrastructure before analysis.

Keep the current problem as one causal gate. Create a typed task packet and
delegate it through the foreground-only `research_worker` tool. Do not start a
second child or do concurrent local research while the child runs. Consume its
persisted report, reject snapshot/epoch mismatches, update durable state, and
only then select the next role.

Use sequential diversity: route a materially different approach after a
family stalls. Reopen a blocked family only for new evidence or mechanism.
Require independent validation before `clean-reproduction` and
`complete-chain`. If no complete result exists, preserve the strongest proven
capability and exact missing gate.
