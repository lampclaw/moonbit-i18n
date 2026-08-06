///|
fn main {
  let i18n = I18n::new(fallback_locale=EnUS)
  let t = i18n.translator(ZhCN)
  println(t.t(Common(Hello)))
  println(t.t(Auth(Login)))
}
