///|
test "generated Todo translator formats both locales" {
  let i18n = I18n::new()
  let en = i18n.translator(EnUS)
  let zh = i18n.translator(ZhCN)
  assert_eq(en.t(TodoUi(Title)), "Todos")
  assert_eq(en.t(TodoUi(ActiveCount(1))), "One active")
  assert_eq(en.t(TodoUi(ActiveCount(3))), "3 active")
  assert_eq(zh.t(TodoUi(Title)), "待办事项")
  assert_eq(zh.t(TodoUi(ActiveCount(3))), "3 项待办")
}

///|
test "generated locale metadata is available to the app" {
  let i18n = I18n::new()
  assert_eq(default_locale(), ZhCN)
  assert_eq(i18n.fallback_locale(), EnUS)
  assert_eq(i18n.translator_from_code("zh_cn").locale(), ZhCN)
  assert_eq(locale_from_code("fr", EnUS), EnUS)
}
