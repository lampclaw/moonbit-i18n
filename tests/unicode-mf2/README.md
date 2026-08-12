# Unicode MF2 reference snapshot

This directory pins the upstream Unicode MessageFormat WG fixtures at commit
`d115a614079678850aac8b52742360e888b8f027` (LDML 48.2 era, 2026-06-11).
The pin is a review reference, not a conformance claim and not a moving branch.

The project exposes the catalog profile
`lampclaw-mf2-strict-v1+lampclaw-datetime-v1`. Its accepted and rejected
feature groups are machine-readable in `profile.json` and exercised by
`runtime/mf2_profile_test.mbt` plus the rest of the runtime tests. The profile
uses strict compile/install failure where Unicode MF2 often specifies emitted
errors plus fallback formatting, so reporting an upstream-suite pass percentage
would be misleading.

When intentionally changing the profile:

1. review the upstream diff from this exact commit;
2. update the profile identifier, compatibility matrix, tests, docs, and
   generated catalog contract hashes in one change;
3. run `node scripts/check-mf2-profile.mjs` and the full release checklist.

Upstream fixture files are not copied into this repository. They remain under
the Unicode license in the upstream repository.
