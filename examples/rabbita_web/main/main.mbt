///|
using @html {button, div, h1}

///|
using @rabbita {type Html, type Val}

///|
enum Msg {
  Inc
  Dec
  ToggleLocale
}

///|
struct Model {
  count : Int
  locale : Locale
} derive(Eq, Debug)

///|
fn update(model : Model, msg : Msg) -> Model {
  match msg {
    Inc => { ..model, count: model.count + 1 }
    Dec => { ..model, count: model.count - 1 }
    ToggleLocale => { ..model, locale: model.locale.other() }
  }
}

///|
fn app() -> Val[Html] {
  let i18n = AppI18n::new()
  let (model, emit) = @rabbita.create_pure_state(
    { count: 0, locale: ZhCN },
    update~,
  )
  model.view(model => {
    let t = i18n.translator(model.locale)
    div(class="app") <| [
      div(class="eyebrow", "lampclaw/i18n + Rabbita"),
      h1(class="title", t.t(Counter(Title))),
      div(class="count", model.count.to_string()),
      div(class="description", t.t(Counter(Count(model.count)))),
      div(class="controls", [
        button(
          class="counter-button",
          on_click=emit(Dec),
          t.t(Counter(Decrement)),
        ),
        button(
          class="counter-button",
          on_click=emit(Inc),
          t.t(Counter(Increment)),
        ),
      ]),
      div(
        class="locale",
        "\{t.t(Common(CurrentLanguage))}: \{model.locale.code()}",
      ),
      button(
        class="switch",
        on_click=emit(ToggleLocale),
        t.t(Common(SwitchLanguage)),
      ),
    ]
  })
}

///|
fn main {
  @rabbita.new(app).mount("app")
}
