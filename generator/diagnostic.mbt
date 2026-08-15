///|
/// A one-based source location plus its zero-based UTF-8 byte offset.
pub(all) struct SourcePosition {
  /// Zero-based UTF-8 byte offset.
  byte_offset : Int
  /// One-based source line.
  line : Int
  /// One-based Unicode-scalar column.
  column : Int
} derive(Eq, Debug)

///|
/// A half-open source range carried by an authoring diagnostic.
pub(all) struct SourceSpan {
  /// Inclusive beginning of the range.
  start : SourcePosition
  /// Exclusive end of the range.
  end : SourcePosition
} derive(Eq, Debug)

///|
/// Stable severity for an authoring diagnostic.
pub(all) enum DiagnosticSeverity {
  /// Generation cannot continue until the problem is repaired.
  Error
  /// Generation can continue, but migration or review is recommended.
  Warning
} derive(Eq, Debug)

///|
/// A stable, path-aware authoring diagnostic suitable for editors and CI.
pub(all) struct Diagnostic {
  /// Stable code. Code meanings are append-only within the `0.x` line.
  code : String
  /// Diagnostic severity.
  severity : DiagnosticSeverity
  /// Human-readable detail; tooling should branch on `code`, not this text.
  message : String
  /// Source path supplied by the caller.
  path : String
  /// Half-open range within `path`.
  span : SourceSpan
} derive(Eq, Debug)

///|
/// Returns the lowercase wire spelling of this severity.
pub fn DiagnosticSeverity::to_string(self : DiagnosticSeverity) -> String {
  match self {
    Error => "error"
    Warning => "warning"
  }
}

///|
/// Formats a diagnostic for a terminal without losing its stable code.
pub fn Diagnostic::to_human_string(self : Diagnostic) -> String {
  "\{self.path}:\{self.span.start.line}:\{self.span.start.column}: \{self.severity.to_string()}[\{self.code}]: \{self.message}"
}

///|
/// Serializes a diagnostic to the versioned JSON diagnostic contract.
pub fn Diagnostic::to_json_string(self : Diagnostic) -> String {
  Json::object({
    "diagnosticVersion": Json::number(1.0),
    "code": Json::string(self.code),
    "severity": Json::string(self.severity.to_string()),
    "message": Json::string(self.message),
    "path": Json::string(self.path),
    "span": Json::object({
      "start": position_json(self.span.start),
      "end": position_json(self.span.end),
    }),
  }).stringify(indent=2)
}

///|
fn position_json(position : SourcePosition) -> Json {
  Json::object({
    "byteOffset": Json::number(position.byte_offset.to_double()),
    "line": Json::number(position.line.to_double()),
    "column": Json::number(position.column.to_double()),
  })
}

///|
fn full_source_span(source : String) -> SourceSpan {
  let mut line = 1
  let mut column = 1
  for char in source.to_array() {
    if char == '\n' {
      line = line + 1
      column = 1
    } else {
      column = column + 1
    }
  }
  {
    start: { byte_offset: 0, line: 1, column: 1 },
    end: { byte_offset: @utf8.encode(source).length(), line, column },
  }
}

///|
fn diagnostic_code(message : String) -> String {
  if message.contains("messageProfile is required") {
    "I18N1003"
  } else if message.contains("limit") || message.contains("exceed") {
    "I18N9001"
  } else if message.contains("invalid i18n config JSON") {
    "I18N1001"
  } else if message.contains("config") ||
    message.contains("messageProfile") ||
    message.contains("sourceLocale") ||
    message.contains("defaultLocale") ||
    message.contains("fallbackLocale") ||
    message.contains("embedded locale") ||
    message.contains("release.minimumCoverage") {
    "I18N1002"
  } else if message.contains("invalid i18n schema JSON") {
    "I18N2001"
  } else if message.contains("schema") {
    "I18N2002"
  } else if message.contains("private function :lampclaw:datetime") {
    "I18N3004"
  } else if message.contains("invalid MF2 message") {
    "I18N3001"
  } else if message.contains("locale coverage") {
    "I18N4001"
  } else if message.contains("locale") || message.contains("message group") {
    "I18N3002"
  } else {
    "I18N5001"
  }
}

///|
fn diagnostic_source(
  message : String,
  config_path : String,
  config_source : String,
  schema_path : String,
  schema_source : String,
  locale_directory : String,
  sources : Array[LocaleSource],
) -> (String, String) {
  if message.contains("config") ||
    message.contains("messageProfile") ||
    message.contains("sourceLocale") ||
    message.contains("defaultLocale") ||
    message.contains("fallbackLocale") ||
    message.contains("embedded locale") ||
    message.contains("release.minimumCoverage") {
    return (config_path, config_source)
  }
  if message.contains("schema") {
    return (schema_path, schema_source)
  }
  for source in sources {
    if message.contains(source.code) {
      let separator = if locale_directory.has_suffix("/") ||
        locale_directory.has_suffix("\\") {
        ""
      } else {
        "/"
      }
      return (
        "\{locale_directory}\{separator}\{source.code}.json",
        source.source,
      )
    }
  }
  if message.contains("locale") || message.contains("message group") {
    return (locale_directory, "")
  }
  (config_path, config_source)
}

///|
/// Runs generation with stable structured diagnostics. The original
/// `generate` function remains the string-error compatibility adapter.
pub fn generate_with_diagnostics(
  config_source : String,
  schema_source : String,
  sources : Array[LocaleSource],
  config_path? : String = "<config>",
  schema_path? : String = "<schema>",
  locale_directory? : String = "<locales>",
  enforce_coverage? : Bool = true,
) -> Result[Artifacts, Array[Diagnostic]] {
  match generate(config_source, schema_source, sources, enforce_coverage~) {
    Ok(artifacts) => {
      let diagnostics : Array[Diagnostic] = []
      for diagnostic in artifacts.diagnostics {
        let path = if diagnostic.code == "I18N1003" ||
          diagnostic.code == "I18N1004" {
          config_path
        } else {
          let separator = if locale_directory.has_suffix("/") ||
            locale_directory.has_suffix("\\") {
            ""
          } else {
            "/"
          }
          "\{locale_directory}\{separator}\{diagnostic.path}"
        }
        diagnostics.push({ ..diagnostic, path, })
      }
      Ok({ ..artifacts, diagnostics, })
    }
    Err(message) => {
      let (path, source) = diagnostic_source(
        message, config_path, config_source, schema_path, schema_source, locale_directory,
        sources,
      )
      Err([
        {
          code: diagnostic_code(message),
          severity: Error,
          message,
          path,
          span: full_source_span(source),
        },
      ])
    }
  }
}
