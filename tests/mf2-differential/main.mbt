///|
fn json_string(object : Map[String, Json], name : String) -> String {
  match object.get(name) {
    Some(String(value)) => value
    _ => abort("differential fixture field must be a string: \{name}")
  }
}

///|
fn json_number(object : Map[String, Json], name : String) -> Double {
  match object.get(name) {
    Some(Number(value, ..)) => value
    _ => abort("differential fixture field must be a number: \{name}")
  }
}

///|
fn fixture_inputs(raw : Json?) -> Array[@runtime.Mf2Input] {
  let inputs : Array[@runtime.Mf2Input] = []
  guard raw is Some(Object(parameters)) else { return inputs }
  for pair in parameters.iter() {
    let (name, value) = pair
    guard value is Object(parameter) else {
      abort("differential parameter must be an object: \{name}")
    }
    let kind = json_string(parameter, "type")
    let message_value = match kind {
      "string" => @runtime.TextValue(json_string(parameter, "value"))
      "int" => @runtime.IntValue(json_number(parameter, "value").to_int())
      "double" => @runtime.DoubleValue(json_number(parameter, "value"))
      "bool" =>
        match parameter.get("value") {
          Some(True) => @runtime.BoolValue(true)
          Some(False) => @runtime.BoolValue(false)
          _ => abort("differential bool parameter must be boolean: \{name}")
        }
      _ => abort("unsupported differential parameter type: \{kind}")
    }
    inputs.push(@runtime.Mf2Input::new(name, message_value))
  }
  inputs
}

///|
fn error_kind(error : @runtime.Mf2Error) -> String {
  match error.code {
    @runtime.Mf2SyntaxCode => "syntax"
    @runtime.Mf2DataModelCode
    | @runtime.Mf2VariantKeyMismatchCode
    | @runtime.Mf2MissingFallbackVariantCode
    | @runtime.Mf2MissingSelectorAnnotationCode
    | @runtime.Mf2DuplicateDeclarationCode
    | @runtime.Mf2DuplicateOptionNameCode
    | @runtime.Mf2DuplicateVariantCode => "data-model"
    @runtime.Mf2ResolutionCode
    | @runtime.Mf2UnresolvedVariableCode
    | @runtime.Mf2UnknownFunctionCode
    | @runtime.Mf2BadSelectorCode
    | @runtime.Mf2BadOperandCode
    | @runtime.Mf2BadOptionCode
    | @runtime.Mf2BadVariantKeyCode => "resolution"
    @runtime.Mf2UnsupportedOperationCode | @runtime.Mf2FormattingCode =>
      "formatting"
    @runtime.Mf2LimitCode => "limit"
  }
}

///|
fn run_case(raw : Json) -> Json {
  guard raw is Object(object) else {
    abort("differential case must be an object")
  }
  let locale = json_string(object, "locale")
  let isolation = match object.get("bidiIsolation") {
    Some(String("none")) => @runtime.Mf2NoBidiIsolation
    _ => @runtime.Mf2DefaultBidiIsolation
  }
  let context = match
    @runtime.Mf2FormattingContext::new(
      locale~,
      inputs=fixture_inputs(object.get("params")),
      bidi_isolation=isolation,
    ) {
    Ok(value) => value
    Err(error) => abort(error.message)
  }
  let result = @runtime.format_mf2(
    json_string(object, "source"),
    context,
    @runtime.Mf2FunctionRegistry::new(@runtime_js.formatter()),
  )
  Json::object({
    "id": Json::string(json_string(object, "id")),
    "value": Json::string(result.value),
    "errorKinds": Json::array(
      result.errors.map(error => Json::string(error_kind(error))),
    ),
  })
}

///|
fn main {
  let args = @env.args()
  if args.is_empty() {
    abort("missing differential fixture JSON")
  }
  let raw = args[args.length() - 1]
  let parsed = try @json.parse(raw) catch {
    _ => abort("invalid differential fixture JSON")
  } noraise {
    value => value
  }
  guard parsed is Array(cases) else {
    abort("differential fixture root must be an array")
  }
  println(Json::array(cases.map(run_case)).stringify())
}
