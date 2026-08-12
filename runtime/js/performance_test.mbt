///|
test "cached Intl number formatting" (bench : @bench.T) {
  let intl = formatter()
  // Prime the cache so the benchmark measures the steady-state hot path.
  ignore((intl.format_number)("en-US", 1234.5, []))
  bench.bench(name="intl-number-cache-hit", fn() {
    bench.keep((intl.format_number)("en-US", 1234.5, []))
  })
}
