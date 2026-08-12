///|
fn render_rich(parts : Array[@runtime.MessagePart]) -> @rabbita.Html {
  let children : Array[@rabbita.Html] = []
  let mut strong_text = ""
  let mut inside_strong = false
  for part in parts {
    match part {
      @runtime.Text(value) =>
        if inside_strong {
          strong_text = strong_text + value
        } else {
          children.push(@html.span(value))
        }
      @runtime.Open("strong", _) => inside_strong = true
      @runtime.Close("strong") => {
        children.push(@html.strong(strong_text))
        strong_text = ""
        inside_strong = false
      }
      @runtime.Open(_, _) | @runtime.Close(_) | @runtime.Standalone(_, _) => ()
    }
  }
  @html.span(id="contract-rich", children)
}

///|
/// Renders a browser-only acceptance fixture through the generated facade.
///
/// The requested locale is intentionally not installed so this also proves
/// fallback behavior and observable diagnostics in an actual JS runtime.
pub fn view() -> @rabbita.Html {
  let i18n = @app_i18n.I18n::new()
  let translator = i18n.translator(@app_i18n.ZhCN)
  let number = translator.t(
    @app_i18n.Contract(@app_i18n.FormattedNumber(1234567)),
  )
  let date = translator.t(
    @app_i18n.Contract(@app_i18n.LastUpdated(1710000000000L)),
  )
  let rich = translator.t_parts(@app_i18n.Contract(@app_i18n.RichNotice))
  let diagnostics = i18n.take_diagnostics()
  @html.section(
    id="browser-contract",
    class="browser-contract",
    attrs=@html.Attrs::build()
      .data_set("diagnostics", diagnostics.entries.length().to_string())
      .data_set("requested-locale", "zh-CN")
      .data_set("used-locale", "en-US"),
    [
      @html.span(id="contract-number", number),
      @html.span(id="contract-date", date),
      render_rich(rich),
    ],
  )
}
