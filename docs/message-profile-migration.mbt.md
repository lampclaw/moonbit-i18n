# Message-profile migration

[中文](message-profile-migration.zh-CN.mbt.md)

Version `0.9.0` makes the message contract explicit and separates stable MF2
from experimental date/time behavior. New projects that do not author
date/time functions should use:

~~~json
{
  "messageProfile": "unicode-mf2-ldml48.2-js-v2"
}
~~~

Projects that deliberately use the pinned Draft `:date`, `:time`, or
`:datetime` functions must use:

~~~json
{
  "messageProfile": "unicode-mf2-ldml48.2-js-v2+experimental-datetime-v1"
}
~~~

Both profiles connect canonical locale JSON to the frozen LDML 48.2 MF2
grammar, data model, resolution, default bidi isolation, and Node 26
JavaScript formatter. Catalog format remains version 2, while the profile is
part of the contract hash. A mismatched facade and catalog therefore fail
closed.

## What changed in 0.9

- Omitting `messageProfile` is now error `I18N1003`; generation no longer
  guesses compatibility semantics.
- The `0.8.x` profile `unicode-mf2-ldml48.2-js-v1` remains accepted but emits
  warning `I18N1004`, because it combined stable and Draft functions.
- Stable v2 rejects `:date`, `:time`, and `:datetime`. The explicitly named
  experimental extension accepts them.
- The original `lampclaw-mf2-strict-v1+lampclaw-datetime-v1` profile remains
  available for deliberate compatibility. Private `:lampclaw:datetime`
  continues to emit warning `I18N3003`; standards profiles reject that private
  name with `I18N3004`.
- Standalone `pseudo`, `export-xliff`, `import-xliff`, `import-i18next`, and
  `import-arb` commands require `--message-profile`.

## Migration from 0.8.x standards authoring

1. Inspect locale sources for `:date`, `:time`, and `:datetime`.
2. If none are present, change the config to
   `unicode-mf2-ldml48.2-js-v2`.
3. If any are intentional, choose
   `unicode-mf2-ldml48.2-js-v2+experimental-datetime-v1` and record that the
   authoring surface may change when Unicode stabilizes those functions.
4. Upgrade the library and CLI together to `0.9.0`, then regenerate bindings,
   the generation manifest, the deployment manifest, and every catalog chunk
   in one change.
5. Run `check`, JavaScript tests, browser/application tests, and the production
   build before deploying generated code and catalogs together.

Keeping the old v1 profile is a short migration bridge, not the recommended
steady state. Warning `I18N1004` is designed to keep that debt visible.

## Migration from the compatibility profile

The compatibility identifier may remain explicit if preserving old behavior
is the immediate goal. To move to standards authoring:

1. Replace private datetime expressions according to output intent:

   - date-only output uses `{$when :date length=medium timeZone=UTC}`;
   - time-only output uses `:time precision=hour|minute|second`;
   - combined output uses `:datetime dateLength=short|medium|long
     timePrecision=hour|minute|second`.

2. Select the experimental datetime profile while these Draft functions are
   present. Select stable v2 only after removing all three functions.
3. Review `hour12`, `timeZone`, and input types rather than applying a blind
   textual rename. Inputs may be generated `InstantMillis` parameters or
   strict ISO literals.
4. Regenerate and deploy the facade and all catalog chunks atomically.

Typed application calls do not change. `I18n::new`, generated message enums,
`Translator::t`, `try_t`, rich parts, locale negotiation, and namespace
loading retain the same application-facing shape. The generated package
exports `MESSAGE_PROFILE` for diagnostics and deployment metadata.

## Verification commands

~~~bash
moon add lampclaw/i18n@0.9.0
moon add --bin lampclaw/i18n/cmd/i18n@0.9.0

moonx lampclaw/i18n/cmd/i18n@0.9.0 generate \
  localization/config.json localization/schema.json localization/locales \
  i18n public/i18n

moonx lampclaw/i18n/cmd/i18n@0.9.0 check \
  localization/config.json localization/schema.json localization/locales \
  i18n public/i18n

moonx lampclaw/i18n/cmd/i18n@0.9.0 pseudo \
  --message-profile unicode-mf2-ldml48.2-js-v2 \
  localization/schema.json en-US localization/locales/en-US.json \
  en-XA localization/locales/en-XA.json

moon check --target js
~~~

Use `--diagnostic-format=json` for editor or CI integration. Warnings are
written to stderr and retain exit status zero. The low-level generator APIs
still default their optional `message_profile` argument to compatibility for
source compatibility; new API callers should always pass an explicit value.
