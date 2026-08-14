# Translation lifecycle and interchange

[中文](translation-lifecycle.zh-CN.mbt.md)

This document defines the stable translation-exchange workflow. Canonical
locale JSON remains the only authored message-content format. XLIFF lifecycle
state and metadata live in a versioned sidecar, so generation and runtime
catalogs do not acquire tool-specific workflow fields.

## XLIFF 2.1 workflow

Export a target locale for a translation system:

~~~bash
moon-i18n export-xliff \
  localization/schema.json \
  en-US localization/locales/en-US.json \
  fr localization/locales/fr.json \
  build/fr.xlf
~~~

After translation, import the XLIFF document:

~~~bash
moon-i18n import-xliff \
  localization/schema.json \
  en-US localization/locales/en-US.json \
  fr build/fr.xlf \
  localization/locales/fr.json
~~~

The command always writes three distinct files. Unless overridden, the two
sidecars are placed beside the locale output:

~~~text
localization/locales/fr.json
localization/locales/fr.json.xliff-state.json
localization/locales/fr.json.xliff-report.json
~~~

Use `--state-output` and `--report-output` before the positional arguments to
select other paths. On the next export, restore the reviewed lifecycle state
and translator context:

~~~bash
moon-i18n export-xliff \
  --state localization/locales/fr.json.xliff-state.json \
  localization/schema.json \
  en-US localization/locales/en-US.json \
  fr localization/locales/fr.json \
  build/fr.xlf
~~~

The state file has `stateVersion: 1` and profile
`xliff-2.1-lampclaw-v1`. Each unit records its canonical identity, exact source,
source SHA-256, target payload, XLIFF state, notes, and the supported metadata
needed for a later export. It is an exchange artifact and should be committed
when a project uses XLIFF lifecycle state.

The standard `initial`, `translated`, `reviewed`, and `final` states are stored
on `segment@state`. The importer accepts the older Lampclaw
`target@state` shape, reports the normalization, and exports the standard
shape. Source and target MF2 fields are text-only; inline XML is rejected.

## Identity and stale-source safety

Every XLIFF unit ID is a source identity. Import fails if the current source
text differs byte-for-byte from the unit source. Export with a sidecar fails if
the sidecar source/hash or target no longer matches the canonical resources.
Changing text therefore requires an explicit translation lifecycle update; an
old reviewed translation cannot silently retain its status.

Renames and removals require a versioned map:

~~~json
{
  "version": 1,
  "renames": {
    "legacy.save": "common.save"
  },
  "removed": ["legacy.delete"]
}
~~~

Pass it as `--id-migrations migrations.json` to `import-xliff`. A rename target
must exist in the current schema, a rename source must no longer exist, targets
cannot collide, and a current schema ID cannot be marked removed. Removed unit
payload is intentionally discarded and appears as a loss in the report.

## Metadata and loss report

The exchange sidecar preserves file identity/original path, unit name and
translation flags, segment identity/state/substate, `xml:space`, and note text
plus `id`, `category`, `appliesTo`, and `priority`. Schema descriptions are
exported as source description notes. Translator-added notes survive an
import/export round trip.

Unsupported attributes, extension namespace declarations, comments,
processing instructions, and explicitly removed units are not silently
dropped. Each becomes an entry in the versioned report with a stable code,
location field, human message, and `loss: true`. Unsupported elements are
rejected because preserving their ordering and semantics cannot be guaranteed.

The public `import_xliff_with_state` API returns locale content, exchange state,
and the report together. `import_xliff` remains a content-only compatibility
adapter; lifecycle-aware library integrations should use the structured API.

## i18next and Flutter ARB migration

The one-way migration commands always require a separate report output:

~~~bash
moon-i18n import-i18next \
  localization/schema.json fr legacy/fr.json \
  localization/locales/fr.json build/fr-i18next-report.json

moon-i18n import-arb \
  localization/schema.json fr legacy/app_fr.arb \
  localization/locales/fr.json build/fr-arb-report.json
~~~

The i18next importer accepts common nested or dotted string keys and converts
`{{name}}` to a typed `{$name}` variable when `name` is declared by the schema.
Plural/context suffixes, formatted interpolation, unknown keys, and non-string
values are omitted with explicit loss entries; they are not approximated.

The ARB importer accepts exact dotted identities or a globally unambiguous
schema key, validates `@@locale`, and converts simple `{name}` placeholders.
ARB metadata and ICU plural/select syntax have no direct canonical locale-JSON
representation and are reported rather than silently approximated.

PO/POT migration is deliberately absent. It will be considered only after a
written MF2 mapping and a real consumer demonstrate a sufficiently low-loss
workflow.

## Security and operational limits

Interchange input is bounded to 64 MiB, 100,000 units, 16 element levels, and
64 notes per unit. XML `DOCTYPE`, external/internal entities, non-XLIFF element
namespaces, duplicate identities, invalid state values, unsafe hierarchy, and
inline XML in MF2 payloads fail closed. Output is validated against the same
size budget before it is returned.
