# MessageFormat profiles

[中文](mf2-profile.zh-CN.mbt.md)

Version `0.8.0` exposes five deliberately separate profiles:

- `lampclaw-mf2-strict-v1+lampclaw-datetime-v1` is the compatibility catalog
  profile used by existing apps.
- `unicode-mf2-ldml48.2-js-v1` is the aggregate standards-mode authoring,
  generated-facade, catalog, and Node 26 JavaScript runtime profile.
- `unicode-mf2-ldml48.2-syntax-v1` covers the complete pinned grammar and
  normative interchange data model.
- `unicode-mf2-ldml48.2-resolution-v1` adds declaration/option resolution,
  selection, fallback, structured output, bidi isolation, and strict BCP 47.
- `unicode-mf2-ldml48.2-default-functions-v1` adds the stable required
  default registry and the public custom-function boundary.

Keeping these contracts separate prevents standards work from silently
changing existing catalog meaning. Canonical JSON config now selects an
explicit `messageProfile`; new scaffolds and the maintained Rabbita application
use `unicode-mf2-ldml48.2-js-v1`. Omission temporarily selects compatibility
mode with warning `I18N1003`. The private `:lampclaw:datetime` function is
accepted only by the compatibility profile and is rejected by standards mode.
See the [migration guide](message-profile-migration.mbt.md).

The upstream point is Unicode MessageFormat WG commit
[`d115a614079678850aac8b52742360e888b8f027`](https://github.com/unicode-org/message-format-wg/commit/d115a614079678850aac8b52742360e888b8f027),
dated 2026-06-11 in the LDML 48.2 era. Immutable sources, hashes, fixtures,
the Unicode license, and the machine-readable profile live under
`tests/unicode-mf2/`. Locale canonicalization separately pins the IANA
Language Subtag Registry dated 2026-08-08.

## Compatibility matrix

| Area | Compatibility catalog | Standards generated catalog | Standalone standards core |
|---|---|---|---|
| Profile | `lampclaw-mf2-strict-v1+lampclaw-datetime-v1` | `unicode-mf2-ldml48.2-js-v1` | Syntax, resolution, and default-registry identifiers above |
| Grammar/model | Strict project subset | Complete pinned message grammar and valid model | Public functional/JSON interchange model |
| Resolution | Eager strict-v1 behavior | Source-ordered declarations, normative selection/fallback/errors | Same behavior with explicit formatting context |
| Parts/bidi | Balanced legacy rich parts | Compatibility `MessagePart` projection plus default Unicode isolation; use the standalone core for fields/attributes | Renderer-independent structured output with options, fields, attributes, IDs, and isolation control |
| Functions | Project subset plus private datetime | Stable required defaults plus separately marked draft date/time | Portable registry; Node 26 `Intl` provider is in `runtime/js` |
| Extensions | Private datetime only | No private/custom functions in generated authoring | Namespaced custom registry, excluded from conformance |
| Catalog identity | Catalog v2 + profile-specific contract hash | Catalog v2 + profile-specific contract hash | Not a deployment format |

See the [syntax/data-model guide](mf2-syntax-data-model.mbt.md),
[resolution guide](mf2-resolution-formatting.mbt.md), and
[default-function guide](mf2-default-functions.mbt.md).

## Conformance statement

The JavaScript backend claims the pinned syntax, validity/data-model,
resolution core, and stable required default-function surfaces. Evidence is:

- 114 well-formed syntax, 133 syntax-error, and 23 data-model cases;
- 67 fallback, pattern-selection, bidi, and Unicode-option cases on Native,
  JavaScript, Wasm, and Wasm-GC;
- all 124 pinned default-function cases on Node 26 JavaScript;
- a checked matrix of 20 scoped normative rows, all 6 stable functions, and all
  40 stable options, each linked to executable evidence; and
- 24 differential cases against independent `messageformat@4.0.0`: 15 exact
  outputs, 2 matching error/fallback semantics, and 7 CLDR-sensitive outputs.
  There are no unexplained semantic failures or currently observed CLDR text
  differences on Node 26.7.0.

The stable repertoire is `:string`, `:number`, `:integer`, `:offset`,
`:currency`, and `:percent`. `:date`, `:time`, and `:datetime` are implemented
to satisfy the roadmap but are Draft in the pin and excluded from the stable
claim. Draft `:unit` is deferred. Native/Wasm CLDR output remains outside the
JavaScript claim. The `0.9.x` phase still needs to select and freeze the exact
latest stable Unicode/LDML target for 1.0, run the complete supported browser
matrix at that frozen target, and freeze public contracts.

Therefore `0.8.0` is a materially larger conformance surface, but it still
does not claim complete Unicode MessageFormat conformance.

## Change discipline

All five identifiers are compatibility contracts. The selected compatibility
or standards authoring identifier participates in catalog contract hashes. A
semantic expansion or incompatible tightening must update its identifier,
matrix, pinned sources, generated tests, migration guidance, and both language
versions of the documentation in one change. CI verifies those relationships,
the differential report, and the published archive.
