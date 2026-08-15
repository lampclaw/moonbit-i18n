# Unicode MF2 reference snapshot

This directory pins official Unicode MessageFormat WG tag `LDML48.2`, commit
`7f142fb4f1f5ea6ab1eb34ce2b87e918ca9fd331`. The pin is an immutable
normative review reference, not a moving branch.

The project exposes stable standards catalog profile
`unicode-mf2-ldml48.2-js-v2`, experimental datetime profile
`unicode-mf2-ldml48.2-js-v2+experimental-datetime-v1`, legacy standards v1,
the frozen compatibility profile
`lampclaw-mf2-strict-v1+lampclaw-datetime-v1`, and the standalone syntax,
resolution, and default-function profiles. Their accepted and deferred feature
groups are machine-readable in `profile.json`. `requirements.json` maps every
scoped normative requirement and stable registry option to test evidence.
Generated fixture tests prove grammar, validity, resolution, fallback,
selection, bidi, and Unicode options on the declared backends. The function
evidence separates 104 stable from 20 experimental date/time cases.
`differential.json` and `differential-report.json` compare a pinned independent
implementation under Node 26 and separate 20 stable from 4 experimental cases,
while classifying exact output, CLDR-text variation, and semantic failures.
The same suites run in real Chromium, Firefox, and WebKit. Draft date/time
support never expands the stable conformance claim.

When intentionally changing the profile:

1. review the upstream diff from this exact tag and commit;
2. update the profile identifier, compatibility matrix, tests, docs, and
   generated catalog contract hashes in one change;
3. run `node scripts/check-mf2-requirements.mjs`,
   `node scripts/check-mf2-differential.mjs`,
   `node scripts/check-mf2-profile.mjs`, and the full release checklist.

The exact upstream syntax, data-model, resolution, formatting, and error
references used by automated tests are vendored in `upstream/` under the
included Unicode License. Run
`node scripts/sync-mf2-upstream-fixtures.mjs` to reproduce them from the pinned
commit, then `node scripts/generate-mf2-syntax-tests.mjs` to regenerate the
syntax tests, `node scripts/generate-mf2-format-tests.mjs` for resolution, and
`node scripts/generate-mf2-function-tests.mjs` for the Node 26 function suite.
The sync script verifies every file's immutable SHA-256 digest.
