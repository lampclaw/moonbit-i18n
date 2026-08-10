///|
fn empty_model() -> Model {
  {
    title: "",
    items: SortedMap::new(),
    next: 0,
    tab: All,
    locale: @app_i18n.ZhCN,
  }
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
  assert_eq(changed.locale, @app_i18n.EnUS)
  assert_eq(changed.items.length(), 1)
}

///|
test "generated Todo facade formats and negotiates locales" {
  let i18n = @app_i18n.I18n::new()
  let en = i18n.translator(@app_i18n.EnUS)
  let zh = i18n.translator(@app_i18n.ZhCN)
  assert_eq(en.t(@app_i18n.TodoUi(@app_i18n.Title)), "Todos")
  assert_eq(en.t(@app_i18n.TodoUi(@app_i18n.ActiveCount(1))), "One active")
  assert_eq(en.t(@app_i18n.TodoUi(@app_i18n.ActiveCount(3))), "3 active")
  assert_eq(zh.t(@app_i18n.TodoUi(@app_i18n.Title)), "待办事项")
  assert_eq(zh.t(@app_i18n.TodoUi(@app_i18n.ActiveCount(3))), "3 项待办")
  assert_eq(i18n.default_translator().locale(), @app_i18n.ZhCN)
  assert_eq(i18n.translator_from_code("zh_cn").locale(), @app_i18n.ZhCN)
  assert_true(i18n.has_catalog(@app_i18n.EnUS))
  assert_true(i18n.has_catalog(@app_i18n.ZhCN))
  assert_eq(i18n.installed_locales(), [@app_i18n.EnUS, @app_i18n.ZhCN])
  assert_eq(i18n.take_diagnostics(), [])
}

///|
test "generated facade installs catalogs and exposes app diagnostics" {
  let i18n = @app_i18n.I18n::new()
  let catalog = "{\"catalogVersion\":1,\"schemaHash\":\"" +
    @app_i18n.SCHEMA_HASH +
    "\",\"locale\":\"en-US\",\"messages\":{\"todo_ui.title\":\"Tasks\"}}"
  assert_true(i18n.install_catalog_source(@app_i18n.EnUS, catalog) is Ok(_))
  assert_eq(
    i18n.translator(@app_i18n.EnUS).t(@app_i18n.TodoUi(@app_i18n.Title)),
    "Tasks",
  )
  assert_eq(
    i18n.translator(@app_i18n.EnUS).t(@app_i18n.TodoUi(@app_i18n.Add)),
    "[missing: todo_ui.add]",
  )
  assert_eq(i18n.take_diagnostics(), [
    @app_i18n.MissingMessage("en-US", "todo_ui.add"),
  ])
  let wrong_version = catalog.replace_all(
    old="\"catalogVersion\":1",
    new="\"catalogVersion\":2",
  )
  assert_true(
    i18n.install_catalog_source(@app_i18n.EnUS, wrong_version)
    is Err("unsupported catalogVersion: 2"),
  )
  let wrong_schema = catalog.replace_all(
    old=@app_i18n.SCHEMA_HASH,
    new="stale-schema",
  )
  assert_true(
    i18n.install_catalog_source(@app_i18n.EnUS, wrong_schema) is Err(_),
  )
  let wrong_locale = catalog.replace_all(old="en-US", new="zh-CN")
  assert_true(
    i18n.install_catalog_source(@app_i18n.EnUS, wrong_locale)
    is Err("catalog locale mismatch: expected en-US, got zh-CN"),
  )
}
