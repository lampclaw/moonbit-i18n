///|
fn empty_model() -> Model {
  { title: "", items: SortedMap::new(), next: 0, tab: All, locale: ZhCN }
}

///|
test "Todo update adds, toggles, and deletes an item" {
  let titled = update(empty_model(), TitleChanged("Ship i18n"))
  let added = update(titled, Add)
  assert_eq(added.items.length(), 1)
  assert_eq(added.items[0], { title: "Ship i18n", done: false })
  let toggled = update(added, Toggle(0))
  assert_eq(toggled.items[0].done, true)
  assert_eq(update(toggled, Delete(0)).items.length(), 0)
}

///|
test "Todo update changes tab and locale without losing items" {
  let added = update(update(empty_model(), TitleChanged("Keep me")), Add)
  let changed = update(update(added, SetTab(Active)), ToggleLocale)
  assert_eq(changed.tab, Active)
  assert_eq(changed.locale, EnUS)
  assert_eq(changed.items.length(), 1)
}
