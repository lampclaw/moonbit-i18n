///|
test "each locale translates every typed message" {
  let texts = all_texts()
  assert_eq(texts.length(), 3)
  assert_eq(texts.map(text => translate_for_locale(EnUS, text)), [
    "Hello", "Save", "Log in",
  ])
  assert_eq(texts.map(text => translate_for_locale(ZhCN, text)), [
    "你好", "保存", "登录",
  ])
}
