# Security policy

## Supported versions

Before the first stable release, security fixes are provided only on the
latest `0.1.x` release. Older development snapshots are unsupported.

## Reporting a vulnerability

Please use GitHub's private **Report a vulnerability** form in the repository's
Security tab. Do not open a public issue before a fix is available. Include the
affected version, target backend, a minimal reproduction, impact, and any
suggested mitigation.

Maintainers should acknowledge a report within five business days, keep the
reporter informed during triage, and coordinate disclosure after supported
versions have a fix. Never include production catalogs, credentials, or private
translation content in a report; use synthetic reproductions.

## Security boundaries

Catalogs and XLIFF are untrusted inputs. Applications should keep the shipped
size/count limits enabled, render `MessagePart` markup through an allowlisted
component map, and avoid treating translated text as HTML. The generator must
write only to dedicated directories carrying its ownership manifest. CLI and
library integrations must not bypass the per-file, aggregate-input, or
generated-output limits.
