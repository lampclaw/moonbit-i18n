# MessageFormat profiles

[中文](mf2-profile.zh-CN.mbt.md)

Version `0.5.0` exposes two deliberately separate profiles:

- `lampclaw-mf2-strict-v1+lampclaw-datetime-v1` is the catalog, generator,
  generated-facade, and formatting profile used by existing applications.
- `unicode-mf2-ldml48.2-syntax-v1` is the new standalone Unicode MF2 syntax
  and interchange-data-model profile. It parses and validates the complete
  pinned grammar, but does not yet format that model.

This separation prevents a syntax expansion from silently changing existing
catalog meaning. Normal JSON authoring and generated applications continue to
use strict-v1 in `0.5.0`; explicit catalog `messageProfile` selection arrives
in `0.8.x`. The standalone API is documented in the
[syntax and data-model guide](mf2-syntax-data-model.mbt.md).

The upstream comparison point is Unicode MessageFormat WG commit
[`d115a614079678850aac8b52742360e888b8f027`](https://github.com/unicode-org/message-format-wg/commit/d115a614079678850aac8b52742360e888b8f027),
dated 2026-06-11 and from the LDML 48.2 era. The immutable pin, vendored
fixtures, Unicode license, and machine-readable matrix live under
`tests/unicode-mf2/`.

## Compatibility matrix

| Area | Existing catalog profile | `unicode-mf2-ldml48.2-syntax-v1` |
|---|---|---|
| Grammar | Strict, line-oriented project subset | Complete pinned message ABNF, including compact complex messages |
| Well-formed vs valid | Compile/install failure | Separate `parse_mf2_syntax` and `validate_mf2_model` stages |
| Declarations and selection | Runtime-ready strict-v1 model | Normative declarations, selectors, variants, and data-model validity |
| Expressions | Runtime-supported operands and functions | Literal, variable, function-only, options, and attributes |
| Markup | Balanced markup in structured parts | Normative open, close, standalone, and intentionally unbalanced model |
| NFC handling | No full NFC identifier/key normalization | Unicode 16 NFC names and NFC-equivalent duplicate detection |
| Interchange model | Internal compiled model and catalog JSON | Normative public model plus deterministic JSON interchange |
| Formatting | Text and rich-parts formatting | Deferred to `0.6.x` and `0.7.x` |
| Functions | `:string`, `:number`, `:integer`, `:offset`, private `:lampclaw:datetime` | Function references retained without registry interpretation |
| Errors | Strict failure | Pinned syntax and specific data-model error codes; recovery deferred |
| Directionality | Catalog direction metadata | Bidi controls accepted by grammar; output isolation deferred |

## Conformance statement

`0.5.0` claims conformance only for the pinned MF2 syntax and validity/data
model surface. It does not claim full Unicode MessageFormat conformance. The
vendored suite proves 114 well-formed syntax cases, 133 syntax-error cases, and
23 data-model cases from the exact upstream commit on all four MoonBit
backends. Resolution, fallback formatting, bidi isolation, the default
function registry, and full formatting fixtures remain version-gated work.

## Change discipline

Both identifiers are public compatibility contracts. The legacy catalog
identifier participates in every catalog contract hash. Any semantic expansion
or incompatible tightening changes the relevant identifier and updates the
matrix, fixtures, tests, and both language versions of these documents in one
change. CI verifies those sources against the immutable upstream pin.
