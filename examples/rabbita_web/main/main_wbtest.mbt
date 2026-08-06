///|
test "counter update changes count and locale" {
  let model : Model = { count: 0, locale: ZhCN }
  assert_eq(update(Inc, model), { count: 1, locale: ZhCN })
  assert_eq(update(Dec, model), { count: -1, locale: ZhCN })
  assert_eq(update(ToggleLocale, model), { count: 0, locale: EnUS })
}
