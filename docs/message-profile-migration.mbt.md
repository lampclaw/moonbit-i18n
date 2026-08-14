# Message-profile migration

[中文](message-profile-migration.zh-CN.mbt.md)

Version `0.8.0` adds an explicit `messageProfile` authoring contract. New
projects should use:

~~~json
{
  "messageProfile": "unicode-mf2-ldml48.2-js-v1"
}
~~~

This profile connects canonical locale JSON to the pinned Unicode MF2
syntax/data model, resolution behavior, default bidi isolation, stable default
registry, and Node 26 JavaScript formatter. Catalog format remains version 2,
but the profile participates in the contract hash. Catalogs and bindings from
different profiles therefore fail closed instead of being mixed.

## Compatibility window

An omitted `messageProfile` currently means
`lampclaw-mf2-strict-v1+lampclaw-datetime-v1`. Generation succeeds and emits
warning `I18N1003`. Add that exact value explicitly if a project needs a
no-semantics-change intermediate commit. An explicit compatibility profile does
not warn merely because it is legacy.

The private `:lampclaw:datetime` function remains valid only in compatibility
mode and emits warning `I18N3003`. Standards mode rejects it with error
`I18N3004`. The omitted-field compatibility default is temporary and will
become an error before `1.0.0`; no exact release for that tightening is implied
until the roadmap and changelog say so.

## Recommended migration

1. Upgrade the library and CLI together to `0.8.0`. Run `generate` once while
   still in compatibility mode and review all warnings.
2. Optionally add the compatibility profile explicitly and commit the updated
   generation manifest. This separates toolchain adoption from message
   semantics.
3. Replace private datetime expressions. Choose the standard function by the
   intended output, not only by the old function name:

   - date-only output:
     `{$when :lampclaw:datetime dateStyle=medium timeZone=UTC}` becomes
     `{$when :date length=medium timeZone=UTC}`;
   - time-only output uses `:time precision=hour|minute|second`;
   - combined output uses `:datetime dateLength=short|medium|long
     timePrecision=hour|minute|second`.

   Standard date/time inputs may be generated `InstantMillis` parameters or
   strict ISO literals. Review `hourCycle` separately: standards-mode draft
   functions expose `hour12=true|false`, so there is no universal textual
   substitution for every previous option set.
4. Set `messageProfile` to `unicode-mf2-ldml48.2-js-v1` and regenerate the
   bindings, generation manifest, deployment manifest, and every catalog
   chunk in one change.
5. Run `check`, JavaScript tests, and the production build. Update assertions
   that compare raw strings: normative bidi isolation may add invisible
   FSI/LRI/RLI and PDI controls around expressions.
6. Deploy the generated JavaScript and all dynamic catalogs as one compatible
   release. Do not serve a standards-profile catalog to an old facade or a
   compatibility catalog to a standards-profile facade.

The typed application calls do not change. `I18n::new`, generated message
enums, `Translator::t`, `try_t`, rich parts, locale negotiation, and namespace
loading retain the same application-facing shape. The generated package adds
`MESSAGE_PROFILE` so application diagnostics and deployment tooling can record
the active contract without duplicating a literal.

## Authoring boundaries

Standards-mode generation validates the complete message model, schema
variables, declared rich-markup names, and the pinned default function
repertoire before emitting catalogs. Generated application messages cannot use
private or application-defined functions. Low-level tooling may register
namespaced custom functions through `Mf2FunctionRegistry`, but that behavior is
outside the generated authoring profile and the Unicode conformance claim.

The stable default functions are `:string`, `:number`, `:integer`, `:offset`,
`:currency`, and `:percent`. `:date`, `:time`, and `:datetime` are implemented
and usable, but remain Draft in the pinned upstream snapshot. Their option/API
surface may require a future explicit profile migration when Unicode
stabilizes a different contract.

## Verification commands

~~~bash
moonx lampclaw/i18n/cmd/i18n@0.8.0 generate \
  localization/config.json localization/schema.json localization/locales \
  i18n public/i18n

moonx lampclaw/i18n/cmd/i18n@0.8.0 check \
  localization/config.json localization/schema.json localization/locales \
  i18n public/i18n

moonx lampclaw/i18n/cmd/i18n@0.8.0 pseudo \
  --message-profile unicode-mf2-ldml48.2-js-v1 \
  localization/schema.json en-US localization/locales/en-US.json \
  en-XA localization/locales/en-XA.json

moon check --target js
~~~

Use `--diagnostic-format=json` for editor or CI integration. Warnings are
written to stderr and do not change a successful command's exit status. The
standalone `pseudo`, `export-xliff`, `import-xliff`, `import-i18next`, and
`import-arb` commands have no config-file argument, so standards-mode projects
must pass the same profile explicitly with `--message-profile`; omitting that
option retains the compatibility profile. Their generator APIs expose the
matching optional `message_profile` argument.
