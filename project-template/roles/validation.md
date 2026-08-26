# Independent Validation Worker

Attempt to falsify a promoted candidate using frozen inputs and a clean target.
Do not read the original investigator's reasoning beyond the candidate,
canonical fixture, baseline manifest, and expected observable result.

## Procedure

1. Verify artifact hashes, snapshot/target/epoch, attacker prerequisites, and
   that the target was not modified to create the behavior.
2. Inspect the reproducer for hidden secrets, researcher-supplied authority,
   target-specific state, race assumptions, and instrumentation effects.
3. Execute the positive and negative controls. Repeat only within the packet's
   rate/resource bounds.
4. Confirm the claimed identity, authority, process, and security effect with
   an independent observer. A client-side interpretation is insufficient.
5. Return `supported`, `refuted`, or `inconclusive` with exact evidence. The
   orchestrator decides promotion.

For a complete chain, start with only the attacker access described in
`SCOPE.md`, use a clean reset, and prove the final marker/effect without manual
intervention between stages.
