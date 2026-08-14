# Unicode MF2 reference snapshot

This directory pins the upstream Unicode MessageFormat WG fixtures at commit
`d115a614079678850aac8b52742360e888b8f027` (LDML 48.2 era, 2026-06-11).
The pin is a review reference, not a conformance claim and not a moving branch.

The project exposes the legacy catalog profile
`lampclaw-mf2-strict-v1+lampclaw-datetime-v1` and the standalone syntax/data
model profile `unicode-mf2-ldml48.2-syntax-v1`. Their accepted and deferred
feature groups are machine-readable in `profile.json`. The standalone profiles
`unicode-mf2-ldml48.2-resolution-v1` and
`unicode-mf2-ldml48.2-default-functions-v1` add resolution and the stable
required registry. Generated fixture tests prove grammar, validity,
resolution, fallback, selection, bidi, Unicode options, and all 124 pinned
function cases on the declared backends. Draft date/time support is tracked
separately and does not expand the stable conformance claim.

When intentionally changing the profile:

1. review the upstream diff from this exact commit;
2. update the profile identifier, compatibility matrix, tests, docs, and
   generated catalog contract hashes in one change;
3. run `node scripts/check-mf2-profile.mjs` and the full release checklist.

The exact upstream syntax, data-model, resolution, formatting, and error
references used by automated tests are vendored in `upstream/` under the
included Unicode License. Run
`node scripts/sync-mf2-upstream-fixtures.mjs` to reproduce them from the pinned
commit, then `node scripts/generate-mf2-syntax-tests.mjs` to regenerate the
syntax tests, `node scripts/generate-mf2-format-tests.mjs` for resolution, and
`node scripts/generate-mf2-function-tests.mjs` for the Node 26 function suite.
The sync script verifies every file's immutable SHA-256 digest.
