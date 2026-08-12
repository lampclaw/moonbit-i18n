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
