# Unicode MF2 reference snapshot

This directory pins the upstream Unicode MessageFormat WG fixtures at commit
`d115a614079678850aac8b52742360e888b8f027` (LDML 48.2 era, 2026-06-11).
The pin is a review reference, not a conformance claim and not a moving branch.

The project exposes the legacy catalog profile
`lampclaw-mf2-strict-v1+lampclaw-datetime-v1` and the standalone syntax/data
model profile `unicode-mf2-ldml48.2-syntax-v1`. Their accepted and deferred
feature groups are machine-readable in `profile.json`. The generated fixture
test proves the pinned grammar and validity surface; formatting conformance is
not claimed because resolution, fallback behavior, bidi isolation, and the
default registry remain later roadmap phases.

When intentionally changing the profile:

1. review the upstream diff from this exact commit;
2. update the profile identifier, compatibility matrix, tests, docs, and
   generated catalog contract hashes in one change;
3. run `node scripts/check-mf2-profile.mjs` and the full release checklist.

The exact upstream syntax and data-model fixture files used by automated tests
are vendored in `upstream/` under the included Unicode License. Run
`node scripts/sync-mf2-upstream-fixtures.mjs` to reproduce them from the pinned
commit, then `node scripts/generate-mf2-syntax-tests.mjs` to regenerate the
MoonBit tests. The sync script verifies every file's immutable SHA-256 digest.
