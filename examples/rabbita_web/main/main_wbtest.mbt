///|
test "counter update changes count and locale" {
  let model : Model = { count: 0, locale: ZhCN }
  assert_eq(update(model, Inc), { count: 1, locale: ZhCN })
  assert_eq(update(model, Dec), { count: -1, locale: ZhCN })
  assert_eq(update(model, ToggleLocale), { count: 0, locale: EnUS })
}
