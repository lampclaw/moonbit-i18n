///|
test "update switches the selected locale" {
  let model : Model = { locale: ZhCN }
  assert_true(update(ToggleLocale, model).locale == EnUS)
}
