///|
test "typed runtime installs exhaustive catalogs" {
  let i18n = I18n::new(fallback_locale=EnUS)
  assert_true(i18n.fallback_locale() == EnUS)
  let en = i18n.translator(EnUS)
  let zh = i18n.translator(ZhCN)
  for text in all_texts() {
    assert_eq(en.t(text), translate_en_us(text))
    assert_eq(zh.t(text), translate_zh_cn(text))
  }
}

///|
test "translator exposes the concise typed t api" {
  let i18n = I18n::new(fallback_locale=EnUS)
  let t = i18n.translator(ZhCN)
  assert_true(t.locale() == ZhCN)
  assert_eq(t.t(Common(Hello)), "你好")
  assert_eq(t.t(Auth(Login)), "登录")
}
