///|
test "typed locales expose stable codes" {
  assert_eq(EnUS.code(), "en-US")
  assert_eq(ZhCN.code(), "zh-CN")
}

///|
test "locale_from_code normalizes and falls back" {
  assert_true(locale_from_code("ZH_cn", EnUS) == ZhCN)
  assert_true(locale_from_code("fr-FR", EnUS) == EnUS)
}
