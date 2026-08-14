# Strict MF2-derived profile

[中文](mf2-profile.zh-CN.mbt.md)

Version `0.2.0` uses
`lampclaw-mf2-strict-v1+lampclaw-datetime-v1`. This is a versioned project
profile derived from MessageFormat 2 concepts, not a claim of complete Unicode
MessageFormat 2 conformance.

The upstream comparison point is Unicode MessageFormat WG commit
[`d115a614079678850aac8b52742360e888b8f027`](https://github.com/unicode-org/message-format-wg/commit/d115a614079678850aac8b52742360e888b8f027),
dated 2026-06-11. The immutable pin and machine-readable matrix live under
`tests/unicode-mf2/`.

## Compatibility matrix

| Area | `0.2.0` contract |
|---|---|
| Patterns and literals | Text, escapes, quoted literals, and the supported unquoted literal grammar |
| Variables | Generated typed contracts for `String`, `Int`, `Double`, `Bool`, and `InstantMillis` |
| Complex messages | Line-oriented `.input`, `.local`, and `.match`; every matcher requires an all-wildcard fallback |
| Selection | Exact numeric, string, cardinal/ordinal number categories, integer, and offset selection in the declared profile |
| Markup | Balanced open/close tags and standalone tags through structured parts; text formatting rejects markup |
| Functions | `:string`, `:number`, `:integer`, `:offset`, and project extension `:lampclaw:datetime` |
| Errors | Compile/install or structured formatting failure; no Unicode MF2 fallback-value recovery |
| Unicode normalization | No full NFC identifier/key normalization |
| Directionality | Catalog direction metadata, but no Unicode MF2 bidi isolation algorithm |
| Attributes and `u:` options | Rejected |
| Standard date/time registry | `:date`, `:datetime`, and `:time` rejected; the project extension accepts epoch milliseconds |
| Optional/custom registry | `:currency`, `:percent`, test functions, and arbitrary user functions rejected |
| Complex whitespace grammar | Compact declarations and variants are rejected; the project grammar is intentionally line-oriented |

## Change discipline

The profile identifier participates in every catalog contract hash. Any
semantic expansion or incompatible tightening must change the identifier and
regenerate all artifacts. CI checks that the runtime constant, reference pin,
matrix, tests, and documentation stay synchronized.
