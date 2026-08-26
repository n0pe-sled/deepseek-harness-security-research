---
name: security-adversarial-validation
description: Use as the sole foreground worker to independently falsify or reproduce a promoted security candidate from frozen inputs and a clean authorized target
---

# Security Adversarial Validation

Use only the candidate, canonical fixture, baseline, attacker prerequisites,
and expected effect. Check hashes/epoch and inspect for hidden credentials,
manual authority, target-specific state, instrumentation effects, and
unrecorded chain links.

Run positive/negative controls on a clean target and verify identity,
authority, and effect through an independent observer. Return supported,
refuted, or inconclusive with exact evidence. Do not broaden the test, repair
the reproducer, or delegate.
