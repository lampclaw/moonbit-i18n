///|
test "derived methods remain callable from a consumer package" {
  let value = @runtime.TextValue("catalog")
  assert_true(value.equal(@runtime.TextValue("catalog")))
  assert_true(value.not_equal(@runtime.TextValue("other")))
  assert_eq(value.to_repr().to_string(), "TextValue(\"catalog\")")
}
