///|
test "typed runtime installs exhaustive catalogs" {
  let i18n = I18n::new(fallback_locale=EnUS)
  assert_true(i18n.fallback_locale() == EnUS)
  let en = i18n.translator(EnUS)
  let zh = i18n.translator(ZhCN)
  for text in all_texts() {
    assert_eq(translate_text(en, text), Some(translate_en_us(text)))
    assert_eq(translate_text(zh, text), Some(translate_zh_cn(text)))
  }
}
