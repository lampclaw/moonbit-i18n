///|
fn empty_model() -> Model {
  { title: "", items: SortedMap::new(), next: 0, tab: All, locale: ZhCN }
}

///|
test "Todo update adds, toggles, and deletes an item" {
  let titled = update(TitleChanged("Ship i18n"), empty_model())
  let added = update(Add, titled)
  assert_eq(added.items.length(), 1)
  assert_eq(added.items[0], { title: "Ship i18n", done: false })
  let toggled = update(Toggle(0), added)
  assert_eq(toggled.items[0].done, true)
  assert_eq(update(Delete(0), toggled).items.length(), 0)
}

///|
test "Todo update changes tab and locale without losing items" {
  let added = update(Add, update(TitleChanged("Keep me"), empty_model()))
  let changed = update(ToggleLocale, update(SetTab(Active), added))
  assert_eq(changed.tab, Active)
  assert_eq(changed.locale, EnUS)
  assert_eq(changed.items.length(), 1)
}
