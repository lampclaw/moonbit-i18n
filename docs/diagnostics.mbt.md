# Authoring diagnostic contract

[中文](diagnostics.zh-CN.mbt.md)

Version `0.2.0` introduces diagnostic contract version `1`. Human output is
intended for terminals; JSON output is selected by placing
`--diagnostic-format=json` after the command name. Integrations must branch on
`code`, never on the English message.

Every diagnostic contains a severity, caller-visible source path, and a
half-open span. Lines and columns are one-based; `byteOffset` is a zero-based
UTF-8 offset. A parser that cannot safely narrow a location reports the full
bounded source rather than inventing precision.

## Stable error codes

| Code | Meaning |
|---|---|
| `I18N0001` | CLI usage, filesystem, ownership, or transaction failure |
| `I18N1001` | Invalid configuration JSON |
| `I18N1002` | Invalid configuration value or relationship |
| `I18N2001` | Invalid schema JSON |
| `I18N2002` | Invalid schema value or generated-name contract |
| `I18N3001` | Invalid message syntax or message contract |
| `I18N3002` | Invalid locale resource or locale relationship |
| `I18N4001` | Release coverage requirement not met |
| `I18N5001` | Other deterministic generation failure |
| `I18N9001` | A configured resource limit was exceeded |

Codes are append-only during the `0.x` line. Severity and span precision may
become more specific without changing a code; a semantic reassignment requires
a new code. `generator.generate_with_diagnostics` exposes the same structured
contract in memory. The existing string-returning generator functions remain
compatibility adapters.

## JSON shape

~~~json
{
  "diagnosticVersion": 1,
  "code": "I18N3001",
  "severity": "error",
  "message": "invalid MF2 message: zh-CN.common.hello: unknown variable: name",
  "path": "localization/locales/zh-CN.json",
  "span": {
    "start": { "byteOffset": 0, "line": 1, "column": 1 },
    "end": { "byteOffset": 42, "line": 2, "column": 1 }
  }
}
~~~
