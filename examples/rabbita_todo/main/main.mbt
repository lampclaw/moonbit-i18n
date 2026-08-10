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
fn TodoTab::label(self : TodoTab, t : Translator) -> String {
  t.t(
    TodoUi(
      match self {
        All => TabAll
        Active => TabActive
        Done => TabDone
        Stats => TabStats
      },
    ),
  )
}

///|
fn TodoTab::empty_text(self : TodoTab, t : Translator) -> String {
  t.t(
    TodoUi(
      match self {
        All => EmptyAll
        Active => EmptyActive
        Done => EmptyDone
        Stats => EmptyStats
      },
    ),
  )
}

///|
fn Locale::other(self : Locale) -> Locale {
  match self {
    EnUS => ZhCN
    ZhCN => EnUS
  }
}

///|
struct Model {
  title : String
  items : SortedMap[Int, Todo]
  next : Int
  tab : TodoTab
  locale : Locale
} derive(Eq, Debug)

///|
enum Msg {
  TitleChanged(String)
  Add
  Delete(Int)
  Toggle(Int)
  SetTab(TodoTab)
  ToggleLocale
}

///|
fn update(model : Model, msg : Msg) -> Model {
  let { title, items, next, .. } = model
  match msg {
    TitleChanged(title) => { ..model, title, }
    SetTab(tab) => { ..model, tab, }
    ToggleLocale => { ..model, locale: model.locale.other() }
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
fn todo(
  id : Int,
  todo : Val[Todo],
  i18n : I18n,
  locale : Val[Locale],
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
        t.t(TodoUi(if todo.done { StatusDone } else { StatusOpen })),
      ),
      div(class="todo-copy", [
        span(class="todo-title", title),
        if is_long {
          button(
            type_="button",
            class="inline-toggle",
            on_click=set_folded(value => !value),
            t.t(TodoUi(if folded { More } else { Less })),
          )
        } else {
          span(class="inline-placeholder", "")
        },
      ]),
      button(
        type_="button",
        class="delete-button",
        on_click=emit(Delete(id)),
        t.t(TodoUi(Delete)),
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
  t : Translator,
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
  i18n : I18n,
  locale : Val[Locale],
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
  i18n : I18n,
  locale : Val[Locale],
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
  i18n : I18n,
  locale : Val[Locale],
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
  i18n : I18n,
  locale : Val[Locale],
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
  i18n : I18n,
  locale : Val[Locale],
) -> Val[Html] {
  model.map2(locale, (model, locale) => {
    let t = i18n.translator(locale)
    let total = model.items.length()
    let completed = model.items.filter((_, todo) => todo.done).length()
    let active = total - completed
    if total == 0 {
      p(class="empty", t.t(TodoUi(EmptyStats)))
    } else {
      div(class="stats-grid", [
        metric_card(t.t(TodoUi(MetricTotal)), total),
        metric_card(t.t(TodoUi(MetricActive)), active),
        metric_card(t.t(TodoUi(MetricDone)), completed),
      ])
    }
  })
}

///|
fn tab_content(
  current_tab : Val[TodoTab],
  model : Val[Model],
  i18n : I18n,
  locale : Val[Locale],
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
  let i18n = I18n::new()
  let (model, emit) = @rabbita.create_pure_state(
    {
      title: "",
      items: SortedMap::new(),
      next: 0,
      tab: All,
      locale: default_locale(),
    },
    update~,
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
    div(class="panel", [
      div(class="panel-header", [
        div([
          h1(t.t(TodoUi(Title))),
          span(class="panel-kicker", t.t(TodoUi(ActiveCount(active)))),
        ]),
        div(class="language", [
          span("\{t.t(Common(CurrentLanguage))}: \{model.locale.code()}"),
          button(
            type_="button",
            class="language-button",
            on_click=emit(ToggleLocale),
            t.t(Common(SwitchLanguage)),
          ),
        ]),
      ]),
      form(on_submit=emit(Add), [
        input(
          value=title,
          placeholder=t.t(TodoUi(Placeholder)),
          on_input=emit.map(value => TitleChanged(value)),
        ),
        input(input_type=Submit, value=t.t(TodoUi(Add))),
      ]),
      nav(class="tabs", [
        tab_button(emit, model.tab, All, total, t),
        tab_button(emit, model.tab, Active, active, t),
        tab_button(emit, model.tab, Done, completed, t),
        tab_button(emit, model.tab, Stats, total, t),
      ]),
      content,
    ])
  })
}

///|
fn main {
  @rabbita.new(app).mount("app")
}
