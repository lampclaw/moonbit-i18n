///|
fn empty_model() -> Model {
  initial_model()
}

///|
test "Todo update adds, toggles, and deletes an item" {
  let titled = update_todo(empty_model(), TitleChanged("Ship i18n"))
  let added = update_todo(titled, Add)
  assert_eq(added.items.length(), 1)
  assert_eq(added.items[0], { title: "Ship i18n", done: false })
  let toggled = update_todo(added, Toggle(0))
  assert_eq(toggled.items[0].done, true)
  assert_eq(update_todo(toggled, Delete(0)).items.length(), 0)
}

///|
test "Todo update changes tab without losing items" {
  let added = update_todo(
    update_todo(empty_model(), TitleChanged("Keep me")),
    Add,
  )
  let changed = update_todo(added, SetTab(Active))
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
  assert_eq(zh.t(@app_i18n.TodoUi(@app_i18n.Title)), "Todos")
  assert_eq(zh.t(@app_i18n.TodoUi(@app_i18n.ActiveCount(3))), "3 active")
  assert_eq(i18n.default_translator().locale(), @app_i18n.EnUS)
  assert_eq(i18n.translator_from_code("zh_cn").locale(), @app_i18n.ZhCN)
  assert_eq(
    i18n.translator_from_codes(["fr-FR", "en-US"]).locale(),
    @app_i18n.EnUS,
  )
  assert_eq(@app_i18n.resolve_locale_codes(["fr-FR", "zh-CN"]), @app_i18n.ZhCN)
  assert_true(i18n.has_catalog(@app_i18n.EnUS))
  assert_false(i18n.has_catalog(@app_i18n.ZhCN))
  assert_eq(i18n.installed_locales(), [@app_i18n.EnUS])
  assert_false(i18n.take_diagnostics().entries.is_empty())
}

///|
test "locale preference resolution uses saved, browser, then default order" {
  assert_eq(resolve_preferred_locale("zh-CN", ["en-US"]), @app_i18n.ZhCN)
  assert_eq(
    resolve_preferred_locale("fr-FR", ["de-DE", "zh_cn"]),
    @app_i18n.ZhCN,
  )
  assert_eq(resolve_preferred_locale("", ["zh-CN"]), @app_i18n.ZhCN)
  assert_eq(resolve_preferred_locale("", ["fr-FR"]), @app_i18n.EnUS)
}

///|
test "generated facade installs catalogs and exposes app diagnostics" {
  let i18n = @app_i18n.I18n::new()
  let catalog = "{\"catalogVersion\":2,\"profile\":\"lampclaw-mf2-strict-v1+lampclaw-datetime-v1\",\"contractHash\":\"" +
    @app_i18n.CONTRACT_HASH +
    "\",\"locale\":\"zh-CN\",\"messages\":{\"todo_ui.title\":\"任务\"}}"
  assert_true(i18n.install_catalog_source(@app_i18n.ZhCN, catalog) is Ok(_))
  assert_eq(
    i18n.translator(@app_i18n.ZhCN).t(@app_i18n.TodoUi(@app_i18n.Title)),
    "任务",
  )
  assert_eq(
    i18n.translator(@app_i18n.ZhCN).t(@app_i18n.TodoUi(@app_i18n.Add)),
    "Add",
  )
  let diagnostics = i18n.take_diagnostics()
  assert_eq(diagnostics.entries.length(), 1)
  assert_eq(diagnostics.entries[0].message_id, "todo_ui.add")
  let wrong_version = catalog.replace_all(
    old="\"catalogVersion\":2",
    new="\"catalogVersion\":3",
  )
  assert_true(
    i18n.install_catalog_source(@app_i18n.EnUS, wrong_version)
    is Err("unsupported catalogVersion: 3"),
  )
  let wrong_schema = catalog.replace_all(
    old=@app_i18n.CONTRACT_HASH,
    new="bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
  )
  assert_true(
    i18n.install_catalog_source(@app_i18n.EnUS, wrong_schema) is Err(_),
  )
  let wrong_locale = catalog.replace_all(old="zh-CN", new="fr")
  assert_true(
    i18n.install_catalog_source(@app_i18n.ZhCN, wrong_locale)
    is Err("catalog locale mismatch: expected zh-CN, got fr"),
  )
}

///|
test "catalog completion is atomic and preserves the current locale on failure" {
  let i18n = @app_i18n.I18n::new()
  let loading = {
    ..empty_model(),
    catalog_state: CatalogLoading(@app_i18n.ZhCN, StartupPreference),
  }
  let invalid = finish_catalog_load(
    i18n,
    loading,
    @app_i18n.ZhCN,
    "{not a catalog",
    StartupPreference,
  )
  assert_eq(invalid.locale, @app_i18n.EnUS)
  assert_true(invalid.catalog_state is CatalogFailed(@app_i18n.ZhCN, _))
  assert_false(i18n.has_catalog(@app_i18n.ZhCN))

  let source = "{\"catalogVersion\":2,\"profile\":\"lampclaw-mf2-strict-v1+lampclaw-datetime-v1\",\"contractHash\":\"" +
    @app_i18n.CONTRACT_HASH +
    "\",\"locale\":\"zh-CN\",\"messages\":{\"todo_ui.title\":\"任务\"}}"
  let ready = finish_catalog_load(
    i18n,
    invalid,
    @app_i18n.ZhCN,
    source,
    StartupPreference,
  )
  assert_eq(ready.locale, @app_i18n.ZhCN)
  assert_eq(ready.catalog_state, CatalogReady)
  assert_true(i18n.has_catalog(@app_i18n.ZhCN))
}
