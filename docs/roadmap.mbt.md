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

The stable `0.1.0` baseline is beyond a prototype:

- application code consumes a generated, typed MoonBit facade instead of raw
  string message identifiers;
- schema, locale resources, generated source, catalogs, and ownership
  manifests form a deterministic authoring and deployment workflow;
- the runtime supports locale negotiation, embedded and dynamic catalogs,
  structured failures and diagnostics, rich parts, and bounded resource use;
- the CLI supports generation, checking, coverage, pseudo-locales, and XLIFF
  2.1 exchange;
- release gates cover multiple MoonBit targets, coverage, performance,
  packaging, API documentation, and clean-module consumption.

The current generated application facade is a Web/JavaScript product. It uses
the host's `Intl` implementation behind an explicit formatter boundary. The
portable runtime compiles on other MoonBit targets, but its locale-sensitive
formatting is deliberately limited. The shipped
`lampclaw-mf2-strict-v1+lampclaw-datetime-v1` profile is a strict
MessageFormat 2-derived subset, not full Unicode MessageFormat 2 conformance.

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

## Lessons from other ecosystems

| Ecosystem | Adopt | Do not copy |
|---|---|---|
| [Unicode MF2 and ICU](https://www.unicode.org/reports/tr35/tr35-messageFormat.html) | Normative syntax and data-model terminology, default functions, error and fallback behavior, Unicode/CLDR semantics, and traceable conformance tests. | Describing a partial grammar as “MF2 compliant”, or silently approximating a function that the selected profile does not implement. |
| [Paraglide JS](https://inlang.com/m/gerre34r/library-inlang-paraglideJs) | Compile-time validation, typed message functions, deterministic generation, and output that can be eliminated when unreachable. | A JavaScript-only runtime model or framework assumptions inside the portable MoonBit core. |
| [Flutter `gen_l10n`](https://docs.flutter.dev/ui/internationalization) | An explicit resource contract, stable generated APIs, deferred locale loading, and inspectable input/output manifests. | A second canonical ARB authoring model or coupling the core package to one UI framework. |
| [FormatJS](https://formatjs.github.io/docs/getting-started/message-extraction/), [gettext](https://www.gnu.org/software/gettext/manual/gettext.html), and [Babel](https://babel.pocoo.org/en/latest/messages.html) | Translator context, machine-readable diagnostics, stale/obsolete translation handling, deterministic merge workflows, and TMS interchange. | Regex-based source extraction replacing the typed schema, or lossy round trips hidden from users. |
| [Fluent](https://projectfluent.org/fluent/guide/terms.html) | Translator-facing context, reusable terminology, and rich UI-oriented messages. | A parallel message language; reusable concepts must be represented through MF2 and the typed schema. |
| [i18next](https://www.i18next.com/overview/plugins-and-utils) | Clear boundaries for locale detection, loading, caching, and framework adapters. | Global mutable locale state, an unbounded plugin surface in the core runtime, or mandatory network/storage dependencies. |

The canonical authoring model remains the project JSON schema, configuration,
and locale resources. Other formats are migration or interchange edges unless
a future roadmap revision explicitly changes that decision.

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

## Long term: `0.9.x` and `1.0.0`

### `0.9.x` — conformance release candidate

- Pin the exact latest stable Unicode MF2/LDML and CLDR versions selected at
  the start of the phase. Draft features remain separately named
  experimental extensions.
- Freeze that target through the `1.0.0` release-candidate cycle instead of
  following moving upstream drafts.
- Require every normative item to be `passed`, `not applicable` with a public
  rationale, or an explicit release blocker.
- Run upstream fixtures, project regression tests, and differential tests on
  the supported Node.js, Chromium, Firefox, and WebKit matrix.
- Freeze the 1.0 public runtime, generator, authoring, catalog, registry, and
  generated-facade contracts and complete consumer migrations.

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
- Expand TMS, editor, and framework integrations without changing the
  framework-neutral application facade.
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
