# GitLab campaign review (2026-08)

Reviewed: `~/Research/ai-research-working/gitlab`, campaign `gitlab-ce-latest-unauth-rce`,
rounds 1 and 2 against GitLab CE 19.3.1-ce.0. The campaign closed on the documented
strongest-primitive branch: no unauth or authed RCE, no written primitive from either
position, and the precise missing gate recorded in `STATE.yaml` and the final assessments.

## What held up

The negative result is trustworthy because of the control discipline. Every refutation ran
a positive control plus a byte-identical-deny control. Evidence is hash-tied to a frozen
epoch, the registry carries a reopen condition per family, and round 2 re-baselined from the
committed pinned role instead of trusting a dirty snapshot. Keep that baseline. The changes
below are additive, each grounded in a campaign artifact.

## Improvement areas

### 1. Anonymous surface enumeration missed web routes

The existence oracle on `/unsubscribes/<base64(email)>` leaks a registered user's avatar
in the og:image meta tag (`page_layout_helper.rb:60-65`, look-up at `unsubscribes_controller.rb:9-11`).
Round 1's DISCO-001/DISCO-004 mapped 45 anonymous controllers and the API mount table but
left this route as a residual (F1). The oracle was confirmed only in round 2's
forgotten-route audit (SIM-013, R2C-4). A web GET route that renders a looked-up record is
anonymous surface and should be enumerated and differential-tested in the first pass, not
the second.

Change: new skill `security-anonymous-oracle-audit`; edits to
`security-vulnerability-discovery` and `security-attack-simulation` making the
known-vs-unknown differential a required control before any anonymous read is certified.

### 2. Incidental findings have no triage path

Round 2 produced two off-objective results: the by-design public reaction (R2B-18a) and the
email oracle (R2C-4). The registry row A015 records the policy "escalate only if it composes
with another primitive", but that policy lives in the row, not in a skill. A skill makes the
compose-vs-park decision consistent across workers and keeps a parked finding's unpark
condition attached to it.

Change: new skill `security-findings-triage`.

### 3. The reopen path is not codified

`STATE.yaml` says the gate reopens on a new release, a controllable public origin, or a new
mechanism. DISCO-003 is the first step on any new release, but its method exists as one
report. A later operator with a new release would re-derive the diff procedure from scratch.

Change: new skill `security-release-delta-hunt`; an orchestration edit that states the
reopen order: verify epoch provenance, run the delta hunt, then route the first live task.

### 4. Restart and scope change happened by improvisation

The round-2 directive ("continue from the beginning") went well: INFRA-012 produced a
pristine epoch, DISCO-006 built a 41-row matrix, SIM-012/013 executed it. But no skill says
how a restart works, and the two mid-campaign scope changes (the testuser follow-on, the
round-2 directive) landed as `SCOPE.md` amendments without a stated procedure. The DISCO-002
parked authenticated lead has an unpark condition recorded nowhere except its report.

Change: orchestration edit adds restart handling (re-baseline to a pristine epoch) and
mid-campaign scope-change handling (dated amendments, updated success-proof language,
parked-lead unpark conditions).

### 5. Live state changes required hand-rolled re-freezing

INFRA-002 (egress), INFRA-005 (testuser), and INFRA-011 (second tenant) each changed live
state and each re-froze, updated the manifest, and updated the committed role by hand.
INFRA-012 could produce a clean epoch only because the role was committed and pinned. That
invariant deserves to be in the skill so it is not rediscovered.

Change: infrastructure edit adds "live, committed, and frozen must match after one task,
with a revert path".

### 6. Session export was built ad hoc at closeout

The orchestrator hand-wrote the zstd decoder and transcript export (`session-logs/tools`)
at the end so the operator could review raw runs. A standard closeout step would make every
campaign auditable the same way.

Change: new skill `security-session-log-export`.

## Housekeeping

- `skills/security-scope-interview` is untracked. Commit it with these changes.
- The campaign directory is not a git repo. A tracked research repo would let a new round
  diff the event ledger and reports. Consider initializing one for the next campaign.

## Net

Four new skills and four process edits to carry forward, all traceable to a specific
campaign artifact. No change to the control discipline that made the campaign's negative
result defensible.
