///|
test "typed translator covers both counter locales" {
  let i18n = AppI18n::new()
  let en = i18n.translator(EnUS)
  let zh = i18n.translator(ZhCN)
  assert_eq(en.t(Counter(Title)), "Rabbita counter")
  assert_eq(en.t(Counter(Count(1))), "One click")
  assert_eq(en.t(Counter(Count(2))), "2 clicks")
  assert_eq(zh.t(Counter(Title)), "Rabbita 计数器")
  assert_eq(zh.t(Counter(Count(2))), "已点击 2 次")
  assert_eq(en.t(Common(SwitchLanguage)), "中文")
  assert_eq(zh.t(Common(SwitchLanguage)), "English")
}

///|
test "locale toggle is reversible" {
  assert_true(EnUS.other() == ZhCN)
  assert_true(ZhCN.other() == EnUS)
}
