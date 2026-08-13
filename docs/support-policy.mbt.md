# Support and compatibility policy

[中文](support-policy.zh-CN.mbt.md)

This document defines the supported `0.1.x` Web baseline. A target is supported
only when it is named here and exercised by the release gates.

## Supported matrix

| Surface | Release gate | Support level |
|---|---|---|
| MoonBit toolchain | archive `0.10.6+80dc50f24`, Moon `0.1.20260803`, moonc `0.10.6` | Pinned and required for `0.1.x` releases |
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

- Pin release candidates exactly. An `0.1.0-rc.N` may contain a documented
  source break required to correct the release contract.
- After `0.1.0`, patch releases in the `0.1.x` line preserve documented public
  APIs and generated-source compatibility by default. A security correction
  may immediately reject previously accepted unsafe input.
- A semantic expansion or incompatible tightening changes the message profile
  identifier and requires regeneration. The catalog version changes only when
  its wire shape or decoding contract changes.
- Generated source, the CLI, and the library must use the same exact version.
  Regenerate committed output when upgrading.
- Before `1.0`, an unavoidable breaking public change normally receives a
  diagnostic and migration path in an earlier minor version. The current
  strict-v1 profile remains frozen through the `0.1.x` line.

The exact shipped message syntax and semantics are defined by the
[MF2-derived profile](mf2-profile.mbt.md), not by planned roadmap work.
