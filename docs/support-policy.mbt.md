# Support and compatibility policy

[中文](support-policy.zh-CN.mbt.md)

This document defines the supported `0.x` Web release line. A target is supported
only when it is named here and exercised by the release gates.

## Supported matrix

| Surface | Release gate | Support level |
|---|---|---|
| MoonBit toolchain | archive `0.10.6+80dc50f24`, Moon `0.1.20260803`, moonc `0.10.6` | Pinned compatibility and CI release gate |
| JavaScript runtime | Node.js `26.7.0` | Sole server/runtime and product gate |
| Browser runtime | Chromium, Firefox, and WebKit supplied by locked Playwright `1.62.1` | Generated facade and application scenarios |
| CLI operating systems | Ubuntu 24.04, macOS 15, Windows 2025 | Wasm `moonx`, native CLI, and installed launcher |
| Portable core | Native, Wasm, Wasm-GC, JavaScript | Compile and target-independent behavior |
| Locale-sensitive formatter | JavaScript | Product backend, using the host `Intl` implementation |

Playwright engines are the reproducible browser contract. They do not imply a
claim about every branded browser version derived from those engines. Native,
Wasm, and Wasm-GC locale-sensitive formatting remains limited and is outside
the JavaScript product-conformance statement.

## `0.x` compatibility

- Pin every `0.x` dependency exactly. Roadmap minors may intentionally change
  public or generated contracts; their changelog and migration diagnostics
  define the boundary. The approved `0.2.x–0.8.x` sequence uses direct stable
  releases rather than release candidates.
- Patch releases within the same minor line preserve documented public APIs
  and generated-source compatibility by default. A security correction may
  immediately reject previously accepted unsafe input.
- A semantic expansion or incompatible tightening changes the message profile
  identifier and requires regeneration. The catalog version changes only when
  its wire shape or decoding contract changes.
- Generated source, the CLI, and the library must use the same exact version.
  Regenerate committed output when upgrading.
- Before `1.0`, an unavoidable breaking public change normally receives a
  diagnostic and migration path in an earlier minor version. The current
  `0.8.0` standards profile is explicit and versioned. Omitting
  `messageProfile` temporarily selects the frozen strict-v1 compatibility
  profile with diagnostic `I18N1003`; explicit selection becomes mandatory
  before `1.0`. The private `:lampclaw:datetime` function remains compatibility
  only and reports migration diagnostic `I18N3003`.

The exact shipped message syntax and semantics are defined by the
[MF2-derived profile](mf2-profile.mbt.md), not by planned roadmap work.
