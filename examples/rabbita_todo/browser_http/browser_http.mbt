///|
using @cmd {type Cmd, trait Scheduler, type Emit}

///|
pub(all) suberror RequestError {
  RequestError(String)
}

///|
pub fn get_text(url : String, emit : Emit[Result[String, Error]]) -> Cmd {
  @cmd.custom_cmd(fn(scheduler : &Scheduler) {
    fetch_text(url, succeed=text => scheduler.add(emit(Ok(text))), failed=detail => {
      scheduler.add(
        emit(Err(RequestError("Catalog request failed: \{detail}"))),
      )
    })
  })
}

///|
extern "js" fn fetch_text(
  url : String,
  succeed~ : (String) -> Unit,
  failed~ : (String) -> Unit,
) =
  #| (url, succeed, failed) => {
  #|   fetch(url)
  #|     .then((response) => {
  #|       if (!response.ok) {
  #|         const suffix = response.statusText ? ` ${response.statusText}` : "";
  #|         throw new Error(`HTTP ${response.status}${suffix}`);
  #|       }
  #|       return response.text();
  #|     })
  #|     .then(succeed, (error) => failed(String(error)));
  #| }
