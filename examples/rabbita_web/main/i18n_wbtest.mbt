///|
test "typed translator covers both web locales" {
  let i18n = AppI18n::new()
  let en = i18n.translator(EnUS)
  let zh = i18n.translator(ZhCN)
  assert_eq(en.t(Common(Hello)), "Hello")
  assert_eq(en.t(Web(SwitchLanguage)), "Switch language")
  assert_eq(zh.t(Common(Hello)), "你好")
  assert_eq(zh.t(Web(SwitchLanguage)), "切换语言")
}

///|
test "locale toggle is reversible" {
  assert_true(EnUS.other() == ZhCN)
  assert_true(ZhCN.other() == EnUS)
}
