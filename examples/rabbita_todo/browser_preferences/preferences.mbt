///|
/// Returns the locale code explicitly saved by this example, or an empty
/// string when no preference exists or browser storage is unavailable.
pub extern "js" fn saved_locale_code() -> String =
  #| () => {
  #|   try {
  #|     return globalThis.window?.localStorage?.getItem(
  #|       "lampclaw.i18n.rabbita-todo.locale",
  #|     ) ?? ""
  #|   } catch (_) {
  #|     return ""
  #|   }
  #| }

///|
/// Returns the browser's preferred locale codes in negotiation order.
pub extern "js" fn browser_locale_codes() -> Array[String] =
  #| () => {
  #|   try {
  #|     return Array.from(globalThis.navigator?.languages ?? [])
  #|   } catch (_) {
  #|     return []
  #|   }
  #| }

///|
/// Saves an explicit locale choice when browser storage is available.
///
/// Persistence is best effort: privacy settings and storage policies must not
/// prevent the application from switching locale in the current session.
pub extern "js" fn save_locale_code(code : String) -> Unit =
  #| (code) => {
  #|   try {
  #|     globalThis.window?.localStorage?.setItem(
  #|       "lampclaw.i18n.rabbita-todo.locale",
  #|       code,
  #|     )
  #|   } catch (_) {
  #|     // Locale switching remains usable when persistence is unavailable.
  #|   }
  #| }
