# Product roadmap

[中文](roadmap.zh-CN.mbt.md)

This document defines the product direction for `lampclaw/i18n`. It is an
engineering roadmap, not a calendar commitment. Milestones advance only when
their acceptance gates are met; version ranges express ordering and
compatibility boundaries rather than delivery dates.

The English and Chinese versions of this document are one public contract and
must change together. The [current MF2 profile](mf2-profile.mbt.md), rather
than this roadmap, remains authoritative for behavior shipped by a particular
release. A planned item never authorizes a conformance claim.

## Product position and current baseline

`lampclaw/i18n` is intended to be MoonBit-native, generator-first, typed,
standards-driven internationalization infrastructure with a portable core and
replaceable target formatters.

The current stable `0.9.0` release is beyond a prototype and freezes the 1.0
candidate baseline:

- application code consumes a generated, typed MoonBit facade instead of raw
  string message identifiers;
- schema, locale resources, generated source, catalogs, and ownership
  manifests form a deterministic authoring and deployment workflow;
- the runtime supports locale negotiation, embedded and dynamic catalogs,
  structured failures and diagnostics, rich parts, and bounded resource use;
- the CLI supports generation, checking, coverage, pseudo-locales, XLIFF 2.1
  exchange, and one-way i18next/ARB migration;
- the stable `unicode-mf2-ldml48.2-js-v2` profile has a traceable Unicode MF2
  requirement matrix, independent differential evidence, and Node.js plus
  three-browser conformance gates;
- release gates cover multiple MoonBit targets, coverage, performance,
  packaging, API documentation, and clean-module consumption.

The current generated application facade is a Web/JavaScript product. It uses
the host's `Intl` implementation behind an explicit formatter boundary. The
portable runtime compiles on other MoonBit targets, but its locale-sensitive
formatting is deliberately limited. Stable authoring now uses
`unicode-mf2-ldml48.2-js-v2`; Draft date/time behavior is available only in a
separately named experimental profile, while the earlier
`lampclaw-mf2-strict-v1+lampclaw-datetime-v1` remains a compatibility profile.

The primary near-term audience is MoonBit Web applications that need
production-grade localization. Framework and tooling authors are a secondary
audience through the documented runtime and generator interfaces. Full
multi-backend locale formatting is a long-term extension and does not block
the JavaScript conformance target.

## MoonBit-native design principles

1. **Make illegal application calls difficult.** Generate enums, typed
   parameters, and exhaustive matches. Raw string IDs remain a low-level
   integration surface, not the normal application API.
2. **Use package boundaries deliberately.** Applications import their
   generated package. Portable evaluation stays separate from target-specific
   formatters, and framework integration stays outside the core runtime.
3. **Share logic; specialize hosts.** Parsing, validation, selection, catalog
   contracts, and diagnostics remain portable. JavaScript `Intl`, future CLDR
   providers, storage, and network integration live behind explicit packages
   or application-owned adapters.
4. **Generate deterministically and commit the result.** Dependency
   installation must not execute an untrusted downstream generator. Generated
   MoonBit and catalogs must be reproducible, reviewable, and usable with
   frozen dependency resolution.
5. **Prefer explicit data and errors.** Public boundaries use typed values,
   `Result`, stable error categories, and bounded diagnostics instead of
   ambient global state or silent approximation.
6. **Respect reachability and artifact size.** Development tooling may resolve
   in the same module, but application packages must not link parser, XML,
   async, or CLI code unless it is reachable. Generated and deployed artifacts
   retain measured size and performance budgets.
7. **Treat Mooncakes as the product surface.** Exact dependency versions,
   `moonx` authoring, `README.mbt.md`, public API comments, package contents,
   and clean-module smoke tests are release requirements.
8. **Version semantics, not only files.** MF2 profiles, catalog wire formats,
   generated APIs, and authoring schemas have explicit identifiers and
   migration rules. Unsupported standard behavior is rejected rather than
   guessed.

These principles follow MoonBit's package-level build model, target-specific
files, and shared-core/multiple-target workflow. See the official
[package configuration](https://docs.moonbitlang.com/en/latest/toolchain/moon/package.html)
and
[multiple-target workflow](https://www.moonbitlang.com/blog/moonbit-multiple-targets).

## Product architecture reference and reference portfolio

### Primary product architecture reference: Flutter `gen_l10n`

If only one product architecture reference is selected, this project chooses
[Flutter `gen_l10n`](https://docs.flutter.dev/ui/internationalization). Like
MoonBit, it belongs to a compiled-language toolchain. Its explicit resource
contract, stable typed generated API, deferred locale loading, and inspectable
input/output manifest align with generator-first MoonBit design, committed
deterministic artifacts, and making illegal application calls difficult.

This choice does not imply ARB or Flutter API compatibility. `gen_l10n` gains
mature framework integration and low-friction code generation at the cost of
coupling canonical ARB, delegate/context lifecycle, and generation to the
Flutter build system; that generated and runtime model is not directly
portable across languages. `lampclaw/i18n` retains these differences:

- canonical authoring is the typed schema, explicit configuration, and MF2
  locale JSON rather than a second ARB authoring model;
- `moonx` explicitly generates and commits an application-specific MoonBit
  package, deployment manifest, and catalogs; dependency installation does not
  implicitly run a generator;
- locale deployment uses namespace chunks whose byte length, SHA-256, profile,
  and contract are verified rather than only framework-delegate loading; and
- networking, storage, retry, and locale commit belong to the application or a
  bounded adapter, while the portable core remains independent of a UI
  framework and ambient host state.

### Reference portfolio

Flutter is the primary product architecture reference, but it is not the sole
answer for normative semantics, translation workflow, or integration. Each
ecosystem has a distinct reference role:

| Role | Ecosystem | Adopt | Do not copy |
|---|---|---|---|
| Normative semantics | [Unicode MF2 and ICU](https://www.unicode.org/reports/tr35/tr35-messageFormat.html) | Normative syntax and data model, default functions, errors and fallback, Unicode/CLDR semantics, and traceable conformance. | Claiming a partial grammar as full MF2 or silently approximating an unimplemented function. |
| Product architecture | [Flutter `gen_l10n`](https://docs.flutter.dev/ui/internationalization) | Explicit resource contracts, typed codegen, deferred locales, and input/output manifests. | ARB as a second canonical format, implicit generation, or core/UI-framework coupling. |
| Compile-time DX | [Paraglide JS](https://inlang.com/m/gerre34r/library-inlang-paraglideJs) | Compile-time validation, typed message functions, deterministic generation, and unreachable-output elimination. | A JavaScript-only runtime model or treating a younger ecosystem as the semantic authority. |
| Application integration | [i18next](https://www.i18next.com/overview/plugins-and-utils) | Clear boundaries for locale detection, loading, caching, SSR, and framework adapters. | Global mutable locale state, an unbounded core plugin surface, or mandatory network/storage dependencies. |
| Translation lifecycle | [FormatJS](https://formatjs.github.io/docs/getting-started/message-extraction/), [gettext](https://www.gnu.org/software/gettext/manual/gettext.html), and [Babel](https://babel.pocoo.org/en/latest/messages.html) | Translator context, machine-readable diagnostics, stale/obsolete translations, deterministic merge, and TMS interchange. | Regex extraction replacing the typed schema or hidden lossy round trips. |
| Translator expression | [Fluent](https://projectfluent.org/fluent/guide/terms.html) | Reusable terminology, grammatical attributes, translator context, and rich UI messages. | A parallel message language; reusable concepts must be represented through MF2 and the typed schema. |

The canonical authoring model remains the project JSON schema, configuration,
and locale resources. Other formats are migration or interchange edges unless
a future roadmap revision explicitly changes that decision; a reference role
also does not promise API or file-format compatibility.

## Milestone and compatibility policy

Roadmap items use the states `planned`, `experimental`, `stable`, `deferred`,
or `rejected`. New work follows this order:

1. correctness, security, and regressions in the currently active milestone;
2. acceptance gates required to finish that milestone;
3. prerequisites for the next milestone;
4. later-stage work only when it unblocks a measured consumer need.

During `0.x`, public APIs are still pre-1.0, but compatibility is intentional:

- removal or incompatible renaming normally receives at least one minor
  release of diagnostics and a documented migration path;
- a semantic expansion or incompatible tightening changes the MF2 profile
  identifier and regenerates every dependent artifact;
- the catalog version changes only when its wire shape or decoding contract
  changes, not for every profile expansion;
- generated APIs remain deterministic, and unavoidable source breaks include
  generated-code migration instructions;
- security fixes may reject previously accepted unsafe input immediately, with
  the reason recorded in the changelog and profile documentation.

## Short term: `0.1.x` — freeze the Web baseline

**Status: stable in `0.1.0`.** The release candidate graduated into the
non-prerelease Web baseline after every gate below passed. No new MF2 syntax or
framework package was part of this phase.

### Deliverables

- Fix defects in the existing authoring schema, strict-v1 profile, generated
  facade, catalog v2, XLIFF profile, runtime boundaries, and CLI.
- Run exact-version Registry smoke tests on Linux, macOS, and Windows,
  including `moon add`, pinned `moonx`, optional `moon add --bin`,
  generation, JavaScript execution, and dynamic catalog installation.
- Add browser coverage for Chromium, Firefox, and WebKit: locale negotiation,
  switching, embedded and dynamic catalogs, number/datetime formatting, rich
  parts, fallback, and diagnostics.
- Keep the maintained browser example and at least two independent real
  consumers passing their localization checks and JavaScript builds.
- Publish the supported MoonBit, Node.js, and browser matrix and the `0.x`
  compatibility policy.
- Preserve the current security, coverage, performance, documentation, and
  archive-content gates.

### Exit gate

`0.1.0` was released after:

- there are no known P0/P1 Web release blockers;
- the complete clean-module flow succeeds against the exact registry version
  on all supported desktop CI systems;
- supported browsers pass the observable application scenarios;
- Mooncakes rendered the README, metadata, and every public library API page
  correctly, while the executable-only CLI passed exact-version installation
  and execution checks;
- the current strict profile is frozen and documented without claiming full
  Unicode MF2 conformance;
- maintained consumers require no unpublished workspace or submodule source.

## Medium term: `0.2.x–0.4.x` — authoring and Web delivery

### `0.2.x` — authoring and diagnostics

**Status: stable in `0.2.1`.** The canonical JSON format and strict-v1 runtime
profile remain unchanged. This release adds only explicit authoring workflow,
diagnostic, and reproducibility contracts.

- Add a CLI scaffold for a minimal bilingual module using the canonical JSON
  authoring layout and a generated application package.
- Add stable diagnostic codes, source paths and spans, human output, and
  machine-readable JSON output for CI and editor integrations.
- Record deterministic input/output manifests and make unchanged generation a
  verified no-op.
- Keep generation explicit and commit-friendly; do not depend on a consumer's
  dependency installation running project code.

Exit gate: a new user can scaffold, generate, diagnose an invalid message,
repair it, and build the application on every supported CLI platform; repeated
generation produces no diff.

`0.2.1` met this gate with an atomically published bilingual scaffold, stable
human/JSON diagnostics carrying paths and spans, a versioned SHA-256
input/output manifest, byte-for-byte check mode, and a locked true no-op path
that preserves generated interfaces. The clean-module scenario is part of the
package and cross-platform Registry smoke gates.

The initial `0.2.0` registry artifact passed build and documentation checks,
but exact-version smoke found that scaffold staging locks remained in the user
cache. It was not overwritten; `0.2.1` removes those unreachable locks and is
the accepted `0.2.x` release.

### `0.3.x` — translation lifecycle and interchange

**Status: stable in `0.3.0`.** Canonical locale JSON remains the message-content
source of truth. XLIFF lifecycle metadata is carried by a versioned sidecar and
every intentional loss is machine-reported.

- Extend XLIFF exchange with translation state, source identity, translator
  notes, stale-source detection, and safe ID rename/removal handling.
- Provide deterministic, one-way importers from common i18next JSON and Flutter
  ARB into the canonical project model, with explicit reports for semantics
  that cannot be represented.
- Add PO/POT migration only after a written MF2 mapping and a real consumer
  demonstrate that it can be non-lossy enough for the intended workflow.
- Preserve unknown, supported XLIFF metadata where possible and report every
  intentionally discarded field.

Exit gate: export/import round trips preserve message identity, source text,
translator context, state, and MF2 payloads; stale translations cannot be
accepted silently.

`0.3.0` meets this gate with standard segment states, source SHA-256 identity,
translator notes, strict stale-source/target checks, explicit versioned
rename/removal maps, and deterministic i18next/ARB migration reports. PO/POT
remains excluded because no written low-loss MF2 mapping and real-consumer
evidence exists yet.

### `0.4.x` — production Web delivery

**Status: stable in `0.4.0`.** Canonical authoring remains one JSON resource
per locale. Schema groups become independently installable catalog-v2 chunks,
and a deterministic deployment manifest carries exact byte and SHA-256
identity. Fetching, cache, integrity retry, persistence, and locale commit stay
application-owned.

- Generate namespace-oriented catalog chunks and a deterministic deployment
  manifest without changing the canonical locale source format.
- Document application-owned loading, caching, integrity checking, retry, and
  fallback recipes. Core runtime APIs accept data; they do not fetch or store
  it.
- Maintain framework-neutral browser examples and measure generated
  JavaScript, embedded locale, and dynamic chunk size budgets.
- Add a framework-specific package only when at least two independent
  consumers need the same lifecycle integration and a maintainer owns it.

Exit gate: an application can embed its fallback locale, lazy-load independent
chunks, reject an incompatible or corrupt chunk, recover through documented
fallback, and remain within published size budgets.

`0.4.0` meets this gate with typed namespace metadata, atomic chunk merging,
message-level fallback, a framework-neutral loading recipe, application-side
integrity checks in the maintained browser example, corrupt/stale replacement
tests, and enforced raw/gzip size ceilings. No framework package was added
because the two-consumer and maintainer gate has not been met.

## Medium term: `0.5.x–0.8.x` — converge on Unicode MF2

Each phase introduces a new versioned message profile. Old profiles remain
readable for the documented migration window; their private extensions never
become implicit standard behavior.

### `0.5.x` — syntax and data model

**Status: stable in `0.5.0`.** The standalone
`unicode-mf2-ldml48.2-syntax-v1` profile implements the pinned complete
grammar, the well-formed/valid split, Unicode 16 NFC-equivalent name handling,
the normative public/JSON interchange model, and deterministic functional
syntax serialization. Vendored upstream coverage includes all 114 accepted
syntax, 133 syntax-error, and 23 data-model cases. Existing catalogs remain on
strict-v1 so this phase does not pre-empt the explicit authoring switch planned
for `0.8.x`.

- Implement the pinned stable specification's complete grammar and its
  well-formed versus valid distinction.
- Cover compact messages, declarations, expressions, options, attributes,
  markup, reserved syntax, quoted forms, and the normative interchange data
  model.
- Apply required NFC-equivalent name handling and reject ambiguous or invalid
  names deterministically.

### `0.6.x` — resolution, errors, and Unicode behavior

**Status: stable in `0.6.0`.** The standalone
`unicode-mf2-ldml48.2-resolution-v1` profile implements source-ordered,
at-most-once declaration resolution, normative multi-selector ranking,
best-effort fallback and typed errors, default bidi isolation, `u:id`/`u:dir`,
and renderer-independent markup/attribute parts. Strict locale APIs use a
pinned IANA registry for RFC 5646 canonicalization and RFC 4647 lookup while
the pre-0.6 locale API retains its documented compatibility surface. All 67
pinned fallback, pattern-selection, bidi, and Unicode-option fixtures pass on
all four MoonBit backends. That release deliberately handed the stable default
and public registry work to the next phase.

- Implement normative declaration resolution, matcher selection, fallback
  values, error categories, and best-effort formatting behavior.
- Complete BCP 47 locale canonicalization and negotiation boundaries.
- Implement the MF2 bidirectional-isolation requirements for text and
  structured parts.
- Preserve rich markup and attributes through structured output without
  allowing unsafe renderer behavior.

### `0.7.x` — default functions and registry

**Status: stable in `0.7.0`.** The profile
`unicode-mf2-ldml48.2-default-functions-v1` implements all pinned stable
required functions (`:string`, `:number`, `:integer`, `:offset`, `:currency`,
and `:percent`) and every required option, operand, selection rule, and output
boundary. The roadmap-required `:date`, `:time`, and `:datetime` functions are
implemented but remain explicitly Draft in the pin; Draft `:unit` is deferred.
All 124 pinned function cases pass with the Node 26 JavaScript provider.

- Implement every function, option, operand, selection rule, and output
  required by the pinned stable default registry.
- Define a portable formatter/selector registry interface and a complete
  JavaScript provider backed by `Intl` plus narrowly scoped compatibility
  code where the host lacks required semantics.
- Support namespaced custom functions without treating any custom repertoire
  as part of the Unicode conformance claim.

### `0.8.x` — compatibility and conformance closure

**Status: stable in `0.8.0`.** The aggregate
`unicode-mf2-ldml48.2-js-v1` profile now connects explicit canonical authoring,
profile-specific contract hashes, catalog-v2 installation, generated facades,
and the Node 26 standards runtime. Omitted settings retain compatibility with
warning `I18N1003`; private datetime remains compatibility-only with dedicated
migration diagnostics. New scaffolds and the repository-maintained Rabbita
consumer use standards mode without private functions. A checked matrix maps
20 scoped normative rows, 6 stable functions, and 40 stable options to tests.
Twenty-four independent differential cases report no unexplained semantic gap
on Node 26.7.0, while retaining a separate CLDR-text classification. The
standards-profile Rabbita build measures 429 KiB raw and 116 KiB gzip; explicit
448/128 KiB ceilings account for the runtime validator and formatter while
continuing to fail future unreviewed growth.

- Add an explicit `messageProfile` authoring setting. Existing projects without
  it initially mean strict-v1 and receive a migration diagnostic; it becomes
  required before `1.0.0`.
- Retain `:lampclaw:datetime` only in its legacy profile and provide a
  diagnostic migration to standard `:datetime`.
- Maintain a machine-readable matrix mapping every normative requirement and
  stable default-registry item to tests.
- Add upstream fixtures and differential tests against an independent
  conforming implementation; classify host CLDR text differences separately
  from semantic failures.

The exit gate for this range is zero unexplained conformance gaps on
JavaScript, successful migration of maintained consumers, and no private
extension required by standards-mode messages.

`0.8.0` meets this scoped gate through the generated scaffold, Rabbita browser
consumer, pinned upstream suites, machine-readable requirement matrix, and
independent differential report. This does not pre-empt the `0.9.x` task of
selecting and freezing the exact final stable target for the 1.0 claim.

## Conformance candidate: `0.9.x`

### `0.9.x` — conformance release candidate

**Status: stable in `0.9.0`.** The conformance-candidate gate is implemented
with these frozen boundaries:

- official Unicode MessageFormat WG `LDML48.2` commit
  `7f142fb4f1f5ea6ab1eb34ce2b87e918ca9fd331`, CLDR 48.2, CLDR JSON
  48.2.0, IANA registry 2026-08-08, and Node 26.7.0 host policy;
- stable `unicode-mf2-ldml48.2-js-v2`, separately named experimental datetime,
  warned legacy v1, and explicit compatibility profiles; omission is
  `I18N1003` instead of an inferred default;
- 77 individually anchored normative rows, each `passed` or publicly justified
  `not-applicable`, with zero blockers;
- upstream syntax/data-model, resolution, stable/experimental function, and
  differential suites on Node.js, Chromium, Firefox, and WebKit; and
- the 1.0 candidate public runtime, generator, authoring, catalog, registry,
  CLI, diagnostics, manifest, and generated-facade contracts frozen in
  `docs/contracts/1.0-candidate.json`.

The maintained Rabbita application deliberately selects the experimental
datetime profile; stable consumers without Draft functions migrate to v2. The
release gate also requires three independent consumers to pin exact `0.9.0`
and pass generation, JavaScript build, and application checks.

## Promotion strategy from `0.9.x` to `1.0.0`

Architecture references, tradeoffs, and long-term responsibilities must be
recorded in the roadmap now. Non-blocking capabilities inspired by those
references are developed after `1.0.0` by default. Work during `0.9.x` is
limited to real-consumer use, manual API and authoring review, migration
rehearsal, and correctness, security, conformance, performance, and
compatibility fixes.

`1.0.0` is a stability promotion, not a new feature milestone. Unless a
blocker is found, the public interfaces, generator template, profiles, CLI,
and wire contracts frozen in 0.9 advance unchanged. If a real consumer finds
a P0/P1 blocker that requires breaking the candidate contract, update the
roadmap and migration policy and publish `0.10.0` first; do not silently
change the candidate in `1.0.0`.

A Rabbita adapter, TMS/editor integration, compiler-aware reference analysis,
reusable terminology model, new locale formatters, and cross-backend CLDR
providers are not prerequisites for the JavaScript MF2 `1.0.0`. They move
earlier only when they unblock a measured 1.0 requirement; otherwise they
belong to `1.x`.

## Long term: `1.0.0`

### Definition of “full MF2” for `1.0.0`

The `1.0.0` claim is deliberately scoped:

> The JavaScript backend of `lampclaw/i18n` conforms to the exact stable
> Unicode MessageFormat 2 version identified by the release.

That release requires all of the following:

- complete required syntax, validity, data-model, resolution, formatting,
  fallback, and error behavior;
- every stable required default function, option, operand, selector, and
  output behavior in the pinned registry;
- required Unicode normalization, locale, number/date/time, plural, and
  bidirectional behavior;
- traceable conformance tests with no unexplained normative gaps;
- standard mode that does not depend on `lampclaw:*` functions or other
  private extensions;
- typed custom-function and structured-parts extension points whose additional
  behavior is clearly outside the Unicode conformance statement;
- documented compatibility, deprecation, profile, and catalog migration
  policies for the public 1.0 surface.

The portable core must continue to compile and pass target-neutral behavior on
all supported MoonBit backends. Native, Wasm, and Wasm-GC formatters may remain
limited or experimental and are excluded from the 1.0 full-MF2 claim until
their own conformance gates pass.

### `1.x` and later

- Stabilize an optional Native CLDR provider before equivalent Wasm/Wasm-GC
  providers; do not embed an unbounded CLDR payload in the core runtime.
- Add a bounded Rabbita adapter only after multiple maintained consumers
  measure the same lifecycle duplication; detectors, loaders, caches, retry,
  and persistence remain replaceable and outside the core.
- Expand TMS, editor, and framework integrations without changing the
  framework-neutral application facade.
- Add compiler-aware message references, rename, and unused-message analysis
  only after MoonBit exposes stable compiler or LSP interfaces; do not use
  regex extraction or unstable compiler internals.
- Evaluate reusable terminology and translator context expressed through MF2
  and the typed schema, without a parallel Fluent authoring language or
  private stable semantics.
- Let measured bundle evidence decide finer-grained codegen and tree shaking;
  every new stable MF2 function or formatter adopts a new profile with a full
  migration.
- Re-evaluate splitting runtime and authoring tools into separate Mooncakes
  modules only with measured dependency-resolution harm or version conflicts
  from real consumers.
- Adopt later stable MF2 versions through explicit profiles, compatibility
  tests, and migrations rather than silently changing `1.0` semantics.

## Deferred and rejected directions

The following are not near-term product work:

- automatic or AI translation and a hosted translation-management service;
- runtime-owned networking, browser storage, or global mutable locale state;
- ARB, PO, Fluent, or i18next JSON as parallel canonical authoring formats;
- regex extraction from MoonBit source or dependence on unstable compiler
  internals;
- complete CLDR formatting on every MoonBit backend as a precondition for the
  JavaScript-focused `1.0.0`;
- multiple published modules without evidence that the current single-module
  dependency model causes material engineering harm.

These items are `deferred` unless a future roadmap revision promotes them.
Global mutable state, silent standards approximation, and unreported lossy
conversion are `rejected` design choices.

## Governance for future development

Before changing a public API, authoring format, MF2 profile, catalog contract,
runtime, generator, CLI, or supported target, a proposal must state:

1. the roadmap milestone and user problem it serves;
2. the MoonBit package and target boundary;
3. the ecosystem precedent being adopted and what is intentionally not copied;
4. public API, compatibility, catalog/profile, and migration impact;
5. tests, performance/size budgets, consumer validation, and release gate.

A change outside the active milestone needs a measured blocker or consumer
requirement. A deliberate deviation updates both roadmap languages and the
changelog before or with its implementation. Release reviews verify that
README claims, the MF2 matrix, implementation status, and this roadmap do not
contradict one another.

This document is reviewed at every release boundary. Completed work changes
from `planned` or `experimental` to `stable` only after its acceptance gate is
recorded; unfinished work moves forward without weakening the gate.
