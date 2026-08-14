///|
test "compiled MF2 text formatting" (bench : @bench.T) {
  let compiled = match
    compile_mf2_message(
      "Hello {$name}; total {$count :number}",
      MessageContract::new([
        { name: "name", typ: "String" },
        { name: "count", typ: "Double" },
      ]),
    ) {
    Ok(value) => value
    Err(_) => fail("benchmark message must compile")
  }
  let args : Array[MessageArg] = [
    { name: "name", value: TextValue("MoonBit") },
    { name: "count", value: DoubleValue(1234.5) },
  ]
  bench.bench(name="compiled-format", fn() {
    bench.keep(format_text(compiled, "en-US", args, Formatter::basic()))
  })
}

///|
test "standalone MF2 model resolution and structured formatting" (
  bench : @bench.T,
) {
  let model = match parse_valid_mf2_model("Hello {$name}; code {42}") {
    Ok(value) => value
    Err(_) => fail("standalone benchmark model must parse")
  }
  let context = match
    Mf2FormattingContext::new(
      locale="en-US",
      inputs=[Mf2Input::new("name", TextValue("MoonBit"))],
      direction=Mf2LeftToRight,
      bidi_isolation=Mf2NoBidiIsolation,
    ) {
    Ok(value) => value
    Err(_) => fail("standalone benchmark context must be valid")
  }
  bench.bench(name="standalone-model-format", fn() {
    bench.keep(format_mf2_model_standalone(model, context))
  })
}

///|
test "indexed catalog lookup at ten thousand messages" (bench : @bench.T) {
  let entries = Array::makei(10000, index => CatalogEntry::{
    id: "message.\{index}",
    message: "value \{index}",
  })
  let catalog = Catalog::from_generated_entries(
    locale_code="en-US",
    contract_hash="aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
    entries~,
  )
  bench.bench(name="catalog-lookup-10k", fn() {
    bench.keep(catalog.find("message.9999"))
  })
}
