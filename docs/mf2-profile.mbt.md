# MessageFormat profiles

[中文](mf2-profile.zh-CN.mbt.md)

Version `0.9.0` freezes the JavaScript conformance candidate against the
official Unicode MessageFormat 2.0 text shipped with LDML 48.2. Authoring must
select one of these explicit message profiles:

- `unicode-mf2-ldml48.2-js-v2` is the recommended stable profile. It includes
  the stable `:string`, `:number`, `:integer`, `:offset`, `:currency`, and
  `:percent` functions and rejects Draft date/time functions.
- `unicode-mf2-ldml48.2-js-v2+experimental-datetime-v1` adds the pinned Draft
  `:date`, `:time`, and `:datetime` functions under a separately versioned,
  non-stable contract.
- `unicode-mf2-ldml48.2-js-v1` is the `0.8.x` standards profile. It remains
  readable for migration and emits warning `I18N1004`.
- `lampclaw-mf2-strict-v1+lampclaw-datetime-v1` is the original compatibility
  profile. It preserves the private `:lampclaw:datetime` contract.

Omitting `messageProfile` is error `I18N1003` in `0.9.0`. The standalone
`pseudo`, XLIFF, i18next, and ARB commands likewise require
`--message-profile`. See the [migration guide](message-profile-migration.mbt.md).

The public standalone standards core retains three narrower identifiers:

- `unicode-mf2-ldml48.2-syntax-v1` for the complete pinned grammar and
  normative interchange data model;
- `unicode-mf2-ldml48.2-resolution-v1` for resolution, selection, fallback,
  structured output, bidi isolation, and strict BCP 47; and
- `unicode-mf2-ldml48.2-default-functions-v1` for the stable default registry
  and public custom-function boundary.

## Frozen standards baseline

The normative source is the official Unicode MessageFormat WG tag
[`LDML48.2`](https://github.com/unicode-org/message-format-wg/tree/LDML48.2),
commit `7f142fb4f1f5ea6ab1eb34ce2b87e918ca9fd331`. The complete immutable
source set, hashes, generated fixtures, and Unicode license are vendored under
`tests/unicode-mf2/`.

`tests/unicode-mf2/standards.json` additionally freezes CLDR 48.2, CLDR JSON
48.2.0, the IANA Language Subtag Registry dated 2026-08-08, and the Node
26.7.0 `Intl` host policy. Updating any normative input requires an explicit
profile review; CI rejects a moving reference or hash drift.

## Compatibility matrix

| Area | Stable v2 | Experimental datetime | Legacy/compatibility |
|---|---|---|---|
| Authoring | Explicit `unicode-mf2-ldml48.2-js-v2` | Explicit `unicode-mf2-ldml48.2-js-v2+experimental-datetime-v1` | Explicit v1 or compatibility identifier |
| Grammar/model | Complete pinned MF2 grammar and valid model | Same | v1 uses the same standards core; compatibility uses the strict project subset |
| Resolution/bidi | Normative source order, selection, fallback, errors, and Unicode isolation | Same | v1 preserves its previous aggregate meaning; compatibility preserves eager strict-v1 behavior |
| Functions | Six stable functions | Stable six plus three pinned Draft date/time functions | v1 accepts stable and Draft date/time; compatibility adds private datetime |
| Catalog | Catalog v2 plus profile-specific contract hash | Same | Same fail-closed identity rule |
| Runtime claim | Node 26 JavaScript and supported browsers | Tested but excluded from stable claim | Migration compatibility only |

Generated application authoring does not permit arbitrary custom functions.
Low-level users may register namespaced functions through
`Mf2FunctionRegistry`; such extensions are outside the Unicode conformance
claim.

## Conformance statement

The `0.9.0` JavaScript backend is a release candidate for the pinned stable
MF2 surface, backed by:

- 270 upstream syntax and data-model cases (114 well-formed, 133 syntax
  errors, and 23 data-model cases);
- 67 resolution, selection, fallback, bidi, and Unicode-option cases on
  Native, JavaScript, Wasm, and Wasm-GC;
- 104 stable default-function cases plus 20 separately classified
  experimental date/time cases;
- 77 one-to-one anchored normative rows, all 6 stable functions, and all 40
  stable options, with zero unexplained gaps or blockers;
- 24 differential cases against independent `messageformat@4.0.0`, split
  into 20 stable and 4 experimental date/time cases, with zero unexplained
  semantic failures; and
- the same syntax, resolution, function, and differential suites in real
  Chromium, Firefox, and WebKit, plus six Rabbita application scenarios.

The recorded Node host is 26.7.0 with ICU 78.3, CLDR 48.0, Unicode 17.0, and
tz 2026c. Browser runs record their own `Intl` fingerprints so host-data
differences remain visible instead of being mistaken for engine bugs.

The claim is intentionally limited to the stable JavaScript profile. Draft
date/time behavior is experimental, Draft `:unit` is deferred, custom
functions are extensions, and Native/Wasm do not yet ship a project-owned
CLDR formatter. Therefore `0.9.0` does not claim every optional or Draft MF2
feature on every backend.

## Contract discipline

The profile identifiers, catalog v2, diagnostics v1, manifest formats, CLI
surface, generated facade template, and public MoonBit interfaces are frozen
in `docs/contracts/1.0-candidate.json`. A semantic expansion or incompatible
tightening must introduce an explicit profile or contract migration and update
the normative matrix, fixtures, differential evidence, browser evidence, and
both language versions of the documentation in one change.
