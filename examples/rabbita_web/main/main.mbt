///|
using @html {button, div, h1}

///|
using @rabbita {type Html, type Val}

///|
enum Msg {
  ToggleLocale
}

///|
struct Model {
  locale : Locale
} derive(Eq)

///|
fn update(msg : Msg, model : Model) -> Model {
  match msg {
    ToggleLocale => { locale: model.locale.other() }
  }
}

///|
fn app() -> Val[Html] {
  let i18n = AppI18n::new()
  let (model, emit) = @rabbita.create_pure_state({ locale: ZhCN }, update=fn(
    msg,
    model,
  ) {
    update(msg, model)
  })
  model.view(model => {
    let t = i18n.translator(model.locale)
    div(class="app") <| [
      div(class="eyebrow", "lampclaw/i18n + Rabbita"),
      h1(class="title", t.t(Common(Hello))),
      div(class="description", t.t(Web(Description))),
      div(
        class="locale",
        "\{t.t(Web(CurrentLanguage))}: \{model.locale.code()}",
      ),
      button(
        class="switch",
        on_click=emit(ToggleLocale),
        t.t(Web(SwitchLanguage)),
      ),
    ]
  })
}

///|
fn main {
  @rabbita.new(app).mount("app")
}
