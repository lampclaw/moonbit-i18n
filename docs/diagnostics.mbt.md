# Authoring diagnostic contract

[中文](diagnostics.zh-CN.mbt.md)

Diagnostic contract version `1` is stable across the `0.x` line. Human output
is intended for terminals; place `--diagnostic-format=json` after the command
name for machine-readable output. Integrations must branch on `code`, never on
the English message.

Every diagnostic contains a severity, caller-visible source path, and a
half-open span. Lines and columns are one-based; `byteOffset` is a zero-based
UTF-8 offset. A parser that cannot safely narrow a location reports the full
bounded source rather than inventing precision.

Successful commands may write migration warnings to stderr. They retain exit
status zero and do not change generated output. JSON mode emits one complete
diagnostic object per warning; consumers should treat stderr as a sequence of
JSON values, not one enclosing array.

## Stable codes

| Code | Severity | Meaning |
|---|---|---|
| `I18N0001` | Error | CLI usage, filesystem, ownership, or transaction failure |
| `I18N1001` | Error | Invalid configuration JSON |
| `I18N1002` | Error | Invalid configuration value or relationship |
| `I18N1003` | Error | Required `messageProfile` is omitted |
| `I18N1004` | Warning | Legacy standards profile v1 is selected; choose stable v2 or the explicit datetime extension |
| `I18N2001` | Error | Invalid schema JSON |
| `I18N2002` | Error | Invalid schema value or generated-name contract |
| `I18N3001` | Error | Invalid message syntax or message contract |
| `I18N3002` | Error | Invalid locale resource or locale relationship |
| `I18N3003` | Warning | Compatibility message uses private `:lampclaw:datetime` |
| `I18N3004` | Error | Standards-mode message contains private `:lampclaw:datetime` |
| `I18N4001` | Error | Release coverage requirement not met |
| `I18N5001` | Error | Other deterministic generation failure |
| `I18N9001` | Error | A configured resource limit was exceeded |

Codes are append-only during `0.x`. Severity may only change when the old
operation could not have succeeded under the new rule, as with the planned
`I18N1003` tightening in `0.9.0`; semantic reassignment requires a new code.
`generator.generate_with_diagnostics` exposes the same structured contract in
memory. Existing string-error generator functions remain compatibility
adapters.

## JSON shape

~~~json
{
  "diagnosticVersion": 1,
  "code": "I18N1003",
  "severity": "error",
  "message": "messageProfile is required; choose an explicit authoring profile",
  "path": "localization/config.json",
  "span": {
    "start": { "byteOffset": 0, "line": 1, "column": 1 },
    "end": { "byteOffset": 128, "line": 8, "column": 1 }
  }
}
~~~
