///|
test "generator derived methods remain callable from a consumer package" {
  let param : @generator.Param = { name: "name", typ: "String", }
  assert_true(param.equal({ name: "name", typ: "String", }))
  assert_true(param.not_equal({ name: "count", typ: "Int", }))
  assert_eq(param.to_repr().to_string(), "{ name: \"name\", typ: \"String\" }")
}
