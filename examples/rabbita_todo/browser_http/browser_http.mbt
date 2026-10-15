///|
using @cmd {type Cmd, trait Scheduler, type Emit}

///|
pub(all) suberror RequestError {
  RequestError(String)
}

///|
pub fn get_text(
  url : String,
  expected_bytes~ : Int32,
  emit : Emit[Result[String, Error]],
) -> Cmd {
  @cmd.custom_cmd(fn(scheduler : &Scheduler) {
    fetch_text(
      url,
      expected_bytes,
      succeed=text => scheduler.add(emit(Ok(text))),
      failed=detail => {
        scheduler.add(
          emit(Err(RequestError("Catalog request failed: \{detail}"))),
        )
      },
    )
  })
}

///|
extern "js" fn fetch_text(
  url : String,
  expected_bytes : Int32,
  succeed~ : (String) -> Unit,
  failed~ : (String) -> Unit,
) =
  #| (url, expectedBytes, succeed, failed) => {
  #|   const controller = new AbortController();
  #|   let settled = false;
  #|   let reader;
  #|   const finish = (callback, value) => {
  #|     if (settled) return;
  #|     settled = true;
  #|     clearTimeout(timer);
  #|     callback(value);
  #|   };
  #|   const fail = (error) => {
  #|     finish(failed, String(error));
  #|     controller.abort();
  #|     if (reader) void reader.cancel().catch(() => {});
  #|   };
  #|   const timer = setTimeout(() => fail(new Error("request timed out")), 10000);
  #|   void (async () => {
  #|     try {
  #|       if (!Number.isInteger(expectedBytes) || expectedBytes < 1 || expectedBytes > 65536) {
  #|         throw new Error("invalid catalog byte limit");
  #|       }
  #|       const response = await fetch(url, { signal: controller.signal });
  #|       if (settled) return;
  #|       if (!response.ok) throw new Error(`HTTP ${response.status}`);
  #|       if (!response.body) throw new Error("missing response body");
  #|       reader = response.body.getReader();
  #|       const decoder = new TextDecoder("utf-8", { fatal: true, ignoreBOM: true });
  #|       let bytes = 0;
  #|       let text = "";
  #|       for (;;) {
  #|         const { done, value } = await reader.read();
  #|         if (settled) return;
  #|         if (done) break;
  #|         bytes += value.byteLength;
  #|         if (bytes > expectedBytes) throw new Error("catalog response too large");
  #|         text += decoder.decode(value, { stream: true });
  #|       }
  #|       text += decoder.decode();
  #|       if (bytes !== expectedBytes) throw new Error("catalog byte count mismatch");
  #|       finish(succeed, text);
  #|     } catch (error) {
  #|       fail(error);
  #|     } finally {
  #|       if (reader) reader.releaseLock();
  #|     }
  #|   })();
  #| }
