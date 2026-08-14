///|
using @sorted_map {type SortedMap}

///|
using @vector {type Vector, from_iter}

///|
using @rabbita {type Val, type Emit, type Html}

///|
using @html {button, div, form, h1, input, li, nav, p, span, ul}

///|
struct Todo {
  title : String
  done : Bool
} derive(Eq, Debug)

///|
enum TodoTab {
  All
  Active
  Done
  Stats
} derive(Eq, Debug)

///|
impl @rabbita.Enumerate for TodoTab with fn tag(self) {
  match self {
    All => "all"
    Active => "active"
    Done => "done"
    Stats => "stats"
  }
}

///|
fn TodoTab::label(self : TodoTab, t : @app_i18n.Translator) -> String {
  t.t(
    @app_i18n.TodoUi(
      match self {
        All => @app_i18n.TabAll
        Active => @app_i18n.TabActive
        Done => @app_i18n.TabDone
        Stats => @app_i18n.TabStats
      },
    ),
  )
}

///|
fn TodoTab::empty_text(self : TodoTab, t : @app_i18n.Translator) -> String {
  t.t(
    @app_i18n.TodoUi(
      match self {
        All => @app_i18n.EmptyAll
        Active => @app_i18n.EmptyActive
        Done => @app_i18n.EmptyDone
        Stats => @app_i18n.EmptyStats
      },
    ),
  )
}

///|
fn other_locale(locale : @app_i18n.Locale) -> @app_i18n.Locale {
  match locale {
    @app_i18n.EnUS => @app_i18n.ZhCN
    @app_i18n.ZhCN => @app_i18n.EnUS
  }
}

///|
struct Model {
  title : String
  items : SortedMap[Int, Todo]
  next : Int
  tab : TodoTab
  locale : @app_i18n.Locale
  catalog_state : CatalogState
} derive(Eq, Debug)

///|
enum CatalogState {
  CatalogReady
  CatalogLoading(@app_i18n.Locale, LocaleRequestSource)
  CatalogFailed(@app_i18n.Locale, String)
} derive(Eq, Debug)

///|
enum LocaleRequestSource {
  StartupPreference
  UserPreference
} derive(Eq, Debug)

///|
enum Msg {
  TitleChanged(String)
  Add
  Delete(Int)
  Toggle(Int)
  SetTab(TodoTab)
  ToggleLocale
  CatalogLoaded(
    @app_i18n.Locale,
    @app_i18n.CatalogNamespace,
    Result[String, Error]
  )
}

///|
fn initial_model() -> Model {
  {
    title: "",
    items: SortedMap::new(),
    next: 0,
    tab: All,
    locale: @app_i18n.default_locale(),
    catalog_state: CatalogReady,
  }
}

///|
fn resolve_preferred_locale(
  saved : String,
  browser_codes : Array[String],
) -> @app_i18n.Locale {
  let requested : Array[String] = []
  if !saved.is_empty() {
    requested.push(saved)
  }
  for code in browser_codes {
    requested.push(code)
  }
  @app_i18n.resolve_locale_codes(requested)
}

///|
fn update_todo(model : Model, msg : Msg) -> Model {
  let { title, items, next, .. } = model
  match msg {
    TitleChanged(title) => { ..model, title, }
    SetTab(tab) => { ..model, tab, }
    ToggleLocale | CatalogLoaded(_, _, _) => model
    Add if title == "" => model
    Toggle(id) => {
      let todo = items[id]
      { ..model, items: items.add(id, { ..todo, done: !todo.done }) }
    }
    Add =>
      {
        ..model,
        title: "",
        items: items.add(next, { title, done: false }),
        next: next + 1,
      }
    Delete(id) => { ..model, items: items.remove(id) }
  }
}

///|
fn finish_catalog_load(
  i18n : @app_i18n.I18n,
  model : Model,
  locale : @app_i18n.Locale,
  chunk_namespace : @app_i18n.CatalogNamespace,
  catalog_source : String,
  request_source : LocaleRequestSource,
) -> Model {
  let metadata = match
    @app_i18n.catalog_chunk_metadata(locale, chunk_namespace) {
    Some(value) => value
    None =>
      return {
        ..model,
        catalog_state: CatalogFailed(locale, "chunk metadata is missing"),
      }
  }
  if @utf8.encode(catalog_source).length() != metadata.bytes {
    return {
      ..model,
      catalog_state: CatalogFailed(locale, "chunk byte count mismatch"),
    }
  }
  let digest = @crypto.bytes_to_hex_string(
    @crypto.sha256(@utf8.encode(catalog_source)),
  )
  if digest != metadata.sha256 {
    return {
      ..model,
      catalog_state: CatalogFailed(locale, "chunk SHA-256 mismatch"),
    }
  }
  finish_verified_catalog_load(
    i18n, model, locale, chunk_namespace, catalog_source, request_source,
  )
}

///|
fn finish_verified_catalog_load(
  i18n : @app_i18n.I18n,
  model : Model,
  locale : @app_i18n.Locale,
  chunk_namespace : @app_i18n.CatalogNamespace,
  catalog_source : String,
  request_source : LocaleRequestSource,
) -> Model {
  match
    i18n.install_catalog_chunk_source(locale, chunk_namespace, catalog_source) {
    Ok(_) =>
      if required_namespaces_ready(i18n, locale) {
        commit_locale(model, locale, request_source)
      } else {
        model
      }
    Err(message) => { ..model, catalog_state: CatalogFailed(locale, message) }
  }
}

///|
fn required_catalog_namespaces() -> Array[@app_i18n.CatalogNamespace] {
  [@app_i18n.CatalogCommon, @app_i18n.CatalogTodoUi]
}

///|
fn required_namespaces_ready(
  i18n : @app_i18n.I18n,
  locale : @app_i18n.Locale,
) -> Bool {
  required_catalog_namespaces().all(chunk_namespace => {
    i18n.has_catalog_namespace(locale, chunk_namespace)
  })
}

///|
fn commit_locale(
  model : Model,
  locale : @app_i18n.Locale,
  request_source : LocaleRequestSource,
) -> Model {
  if request_source is UserPreference {
    @browser_preferences.save_locale_code(locale.code())
  }
  { ..model, locale, catalog_state: CatalogReady }
}

///|
fn request_locale(
  i18n : @app_i18n.I18n,
  model : Model,
  target : @app_i18n.Locale,
  request_source : LocaleRequestSource,
  emit : Emit[Msg],
) -> (Model, @rabbita.Cmd) {
  if required_namespaces_ready(i18n, target) {
    (commit_locale(model, target, request_source), @rabbita.none)
  } else {
    let requests : Array[@rabbita.Cmd] = []
    for chunk_namespace in required_catalog_namespaces() {
      if !i18n.has_catalog_namespace(target, chunk_namespace) {
        requests.push(
          @http.get("/i18n/\{target.code()}--\{chunk_namespace.code()}.json").expect_text(
            emit.map(result => CatalogLoaded(target, chunk_namespace, result)),
          ),
        )
      }
    }
    (
      { ..model, catalog_state: CatalogLoading(target, request_source) },
      @rabbita.batch(requests),
    )
  }
}

///|
fn initialize(i18n : @app_i18n.I18n, emit : Emit[Msg]) -> (Model, @rabbita.Cmd) {
  let model = initial_model()
  let target = resolve_preferred_locale(
    @browser_preferences.saved_locale_code(),
    @browser_preferences.browser_locale_codes(),
  )
  request_locale(i18n, model, target, StartupPreference, emit)
}

///|
fn update(
  i18n : @app_i18n.I18n,
  model : Model,
  msg : Msg,
  emit : Emit[Msg],
) -> (Model, @rabbita.Cmd) {
  match msg {
    ToggleLocale => {
      let target = match model.catalog_state {
        CatalogFailed(failed, _) => failed
        _ => other_locale(model.locale)
      }
      request_locale(i18n, model, target, UserPreference, emit)
    }
    CatalogLoaded(locale, chunk_namespace, result) =>
      match model.catalog_state {
        CatalogLoading(expected, request_source) if expected == locale =>
          match result {
            Ok(source) =>
              (
                finish_catalog_load(
                  i18n, model, locale, chunk_namespace, source, request_source,
                ),
                @rabbita.none,
              )
            Err(_) =>
              (
                {
                  ..model,
                  catalog_state: CatalogFailed(locale, "catalog request failed"),
                },
                @rabbita.none,
              )
          }
        _ => (model, @rabbita.none)
      }
    _ => (update_todo(model, msg), @rabbita.none)
  }
}

///|
fn todo(
  id : Int,
  todo : Val[Todo],
  i18n : @app_i18n.I18n,
  locale : Val[@app_i18n.Locale],
  emit : Emit[Msg],
) -> Val[Html] {
  let (folded, set_folded) = @rabbita.create_variable(false)
  let localized = todo.map2(locale, (todo, locale) => (todo, locale))
  folded.map2(localized, (folded, localized) => {
    let (todo, locale) = localized
    let t = i18n.translator(locale)
    let is_long = todo.title.length() > 20
    let title = if is_long && folded {
      todo.title[:20].to_owned()
    } else {
      todo.title
    }
    li(class=if todo.done { "todo-row is-done" } else { "todo-row" }, [
      button(
        type_="button",
        class=if todo.done { "status-toggle is-done" } else { "status-toggle" },
        on_click=emit(Toggle(id)),
        t.t(
          @app_i18n.TodoUi(
            if todo.done {
              @app_i18n.StatusDone
            } else {
              @app_i18n.StatusOpen
            },
          ),
        ),
      ),
      div(class="todo-copy", [
        span(class="todo-title", title),
        if is_long {
          button(
            type_="button",
            class="inline-toggle",
            on_click=set_folded(value => !value),
            t.t(
              @app_i18n.TodoUi(
                if folded {
                  @app_i18n.More
                } else {
                  @app_i18n.Less
                },
              ),
            ),
          )
        } else {
          span(class="inline-placeholder", "")
        },
      ]),
      button(
        type_="button",
        class="delete-button",
        on_click=emit(Delete(id)),
        t.t(@app_i18n.TodoUi(@app_i18n.Delete)),
      ),
    ])
  })
}

///|
fn tab_button(
  emit : Emit[Msg],
  current : TodoTab,
  tab : TodoTab,
  count : Int,
  t : @app_i18n.Translator,
) -> Html {
  let class = if current == tab { "tab is-active" } else { "tab" }
  button(type_="button", class~, on_click=emit(SetTab(tab)), [
    span(class="tab-label", tab.label(t)),
    span(class="tab-count", count.to_string()),
  ])
}

///|
fn metric_card(label : String, value : Int) -> Html {
  div(class="metric-card", [
    span(class="metric-value", value.to_string()),
    span(class="metric-label", label),
  ])
}

///|
fn list_content(
  tab : TodoTab,
  todos : Val[Vector[Html]],
  i18n : @app_i18n.I18n,
  locale : Val[@app_i18n.Locale],
) -> Val[Html] {
  todos.map2(locale, (todos, locale) => {
    let t = i18n.translator(locale)
    if todos.length() == 0 {
      p(class="empty", tab.empty_text(t))
    } else {
      ul(class="todo-list", todos)
    }
  })
}

///|
fn all_content(
  model : Val[Model],
  i18n : @app_i18n.I18n,
  locale : Val[@app_i18n.Locale],
  emit : Emit[Msg],
) -> Val[Html] {
  let entries = model.map(model => from_iter(model.items.iter()))
  let todos = entries.assoc((id, todo_value) => {
    todo(id, todo_value, i18n, locale, emit)
  })
  list_content(All, todos, i18n, locale)
}

///|
fn active_content(
  model : Val[Model],
  i18n : @app_i18n.I18n,
  locale : Val[@app_i18n.Locale],
  emit : Emit[Msg],
) -> Val[Html] {
  let entries = model.map(model => {
    from_iter(model.items.iter().filter(pair => !pair.1.done))
  })
  let todos = entries.assoc((id, todo_value) => {
    todo(id, todo_value, i18n, locale, emit)
  })
  list_content(Active, todos, i18n, locale)
}

///|
fn done_content(
  model : Val[Model],
  i18n : @app_i18n.I18n,
  locale : Val[@app_i18n.Locale],
  emit : Emit[Msg],
) -> Val[Html] {
  let entries = model.map(model => {
    from_iter(model.items.iter().filter(pair => pair.1.done))
  })
  let todos = entries.assoc((id, todo_value) => {
    todo(id, todo_value, i18n, locale, emit)
  })
  list_content(Done, todos, i18n, locale)
}

///|
fn stats_content(
  model : Val[Model],
  i18n : @app_i18n.I18n,
  locale : Val[@app_i18n.Locale],
) -> Val[Html] {
  model.map2(locale, (model, locale) => {
    let t = i18n.translator(locale)
    let total = model.items.length()
    let completed = model.items.filter((_, todo) => todo.done).length()
    let active = total - completed
    if total == 0 {
      p(class="empty", t.t(@app_i18n.TodoUi(@app_i18n.EmptyStats)))
    } else {
      div(class="stats-grid", [
        metric_card(t.t(@app_i18n.TodoUi(@app_i18n.MetricTotal)), total),
        metric_card(t.t(@app_i18n.TodoUi(@app_i18n.MetricActive)), active),
        metric_card(t.t(@app_i18n.TodoUi(@app_i18n.MetricDone)), completed),
      ])
    }
  })
}

///|
fn tab_content(
  current_tab : Val[TodoTab],
  model : Val[Model],
  i18n : @app_i18n.I18n,
  locale : Val[@app_i18n.Locale],
  emit : Emit[Msg],
) -> Val[Html] {
  current_tab.switch(tab => {
    match tab {
      All => all_content(model, i18n, locale, emit)
      Active => active_content(model, i18n, locale, emit)
      Done => done_content(model, i18n, locale, emit)
      Stats => stats_content(model, i18n, locale)
    }
  })
}

///|
fn app() -> Val[Html] {
  let i18n = @app_i18n.I18n::new()
  let (model, emit) = @rabbita.create_state_with_init(
    init=fn(emit) { initialize(i18n, emit) },
    update=fn(model, msg, emit) { update(i18n, model, msg, emit) },
  )
  let locale = model.map(model => model.locale)
  let current_tab = model.map(model => model.tab)
  let content = tab_content(current_tab, model, i18n, locale, emit)
  model.map2(content, (model, content) => {
    let { items, title, .. } = model
    let total = items.length()
    let completed = items.filter((_, todo) => todo.done).length()
    let active = total - completed
    let t = i18n.translator(model.locale)
    let loading = match model.catalog_state {
      CatalogLoading(_, _) => true
      _ => false
    }
    let language_label = match model.catalog_state {
      CatalogLoading(_, _) => t.t(@app_i18n.Common(@app_i18n.CatalogLoading))
      CatalogFailed(_, _) => t.t(@app_i18n.Common(@app_i18n.CatalogRetry))
      CatalogReady => t.t(@app_i18n.Common(@app_i18n.SwitchLanguage))
    }
    let status = match model.catalog_state {
      CatalogReady =>
        @html.span(
          class="catalog-status is-ready",
          attrs=@html.Attrs::build()
            .data_set("testid", "catalog-status")
            .data_set("state", "ready"),
          "",
        )
      CatalogLoading(_, _) =>
        @html.span(
          class="catalog-status is-loading",
          attrs=@html.Attrs::build()
            .role("status")
            .aria_live("polite")
            .data_set("testid", "catalog-status")
            .data_set("state", "loading"),
          t.t(@app_i18n.Common(@app_i18n.CatalogLoading)),
        )
      CatalogFailed(_, detail) =>
        @html.span(
          class="catalog-status is-error",
          attrs=@html.Attrs::build()
            .role("alert")
            .data_set("testid", "catalog-status")
            .data_set("state", "error"),
          "\{t.t(@app_i18n.Common(@app_i18n.CatalogError))} \{detail}",
        )
    }
    div(
      class="panel",
      attrs=@html.Attrs::build()
        .lang(model.locale.html_lang())
        .dir(model.locale.direction())
        .data_set("testid", "todo-app")
        .data_set("locale", model.locale.code()),
      [
        div(class="panel-header", [
          div([
            h1(t.t(@app_i18n.TodoUi(@app_i18n.Title))),
            span(
              class="panel-kicker",
              t.t(@app_i18n.TodoUi(@app_i18n.ActiveCount(active))),
            ),
          ]),
          div(class="language", [
            span(
              "\{t.t(@app_i18n.Common(@app_i18n.CurrentLanguage))}: \{model.locale.code()}",
            ),
            button(
              id="locale-toggle",
              type_="button",
              class="language-button",
              disabled=loading,
              on_click=emit(ToggleLocale),
              language_label,
            ),
            status,
          ]),
        ]),
        form(on_submit=emit(Add), [
          input(
            id="new-todo",
            value=title,
            placeholder=t.t(@app_i18n.TodoUi(@app_i18n.Placeholder)),
            on_input=emit.map(value => TitleChanged(value)),
          ),
          input(
            id="add-todo",
            input_type=Submit,
            value=t.t(@app_i18n.TodoUi(@app_i18n.Add)),
          ),
        ]),
        nav(class="tabs", [
          tab_button(emit, model.tab, All, total, t),
          tab_button(emit, model.tab, Active, active, t),
          tab_button(emit, model.tab, Done, completed, t),
          tab_button(emit, model.tab, Stats, total, t),
        ]),
        content,
        @contract.view(),
      ],
    )
  })
}

///|
fn main {
  @rabbita.new(app).mount("app")
}
