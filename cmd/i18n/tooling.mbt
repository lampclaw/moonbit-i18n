///|
async fn run_pseudo(args : Array[String]) -> Unit raise CliError {
  let values : Array[String] = [args[0]]
  let mut message_profile = @runtime.CATALOG_PROFILE
  let mut profile_seen = false
  let mut cursor = 1
  while cursor < args.length() {
    if args[cursor] == "--message-profile" {
      if profile_seen || cursor + 1 >= args.length() {
        cli_fail(usage())
      }
      message_profile = args[cursor + 1]
      profile_seen = true
      cursor = cursor + 2
    } else {
      values.push(args[cursor])
      cursor = cursor + 1
    }
  }
  if values.length() != 6 ||
    !@runtime.is_supported_message_profile(message_profile) {
    cli_fail(usage())
  }
  match
    @generator.pseudo_locale(
      read_file_limited(values[1], @runtime.CATALOG_MAX_SOURCE_BYTES),
      values[2],
      read_file_limited(values[3], @runtime.CATALOG_MAX_SOURCE_BYTES),
      values[4],
      message_profile~,
    ) {
    Ok(value) => write_file(values[5], text_file_content(value))
    Err(message) => cli_fail(message)
  }
}

///|
async fn run_export_xliff(args : Array[String]) -> Unit raise CliError {
  let values : Array[String] = [args[0]]
  let mut state_path : String? = None
  let mut message_profile = @runtime.CATALOG_PROFILE
  let mut profile_seen = false
  let mut cursor = 1
  while cursor < args.length() {
    if args[cursor] == "--state" {
      if state_path is Some(_) || cursor + 1 >= args.length() {
        cli_fail(usage())
      }
      state_path = Some(args[cursor + 1])
      cursor = cursor + 2
    } else if args[cursor] == "--message-profile" {
      if profile_seen || cursor + 1 >= args.length() {
        cli_fail(usage())
      }
      message_profile = args[cursor + 1]
      profile_seen = true
      cursor = cursor + 2
    } else {
      values.push(args[cursor])
      cursor = cursor + 1
    }
  }
  if values.length() != 7 ||
    !@runtime.is_supported_message_profile(message_profile) {
    cli_fail(usage())
  }
  let target = if values[5] == "-" {
    None
  } else {
    Some(read_file_limited(values[5], @runtime.CATALOG_MAX_SOURCE_BYTES))
  }
  let state = match state_path {
    Some("-") | None => None
    Some(path) =>
      Some(read_file_limited(path, @generator.I18N_MAX_TOTAL_LOCALE_BYTES))
  }
  match
    @generator.export_xliff_with_state(
      read_file_limited(values[1], @runtime.CATALOG_MAX_SOURCE_BYTES),
      values[2],
      read_file_limited(values[3], @runtime.CATALOG_MAX_SOURCE_BYTES),
      values[4],
      target,
      state,
      message_profile~,
    ) {
    Ok(value) => write_file(values[6], value)
    Err(message) => cli_fail(message)
  }
}

///|
async fn run_import_xliff(args : Array[String]) -> Unit raise CliError {
  let values : Array[String] = [args[0]]
  let mut state_output : String? = None
  let mut report_output : String? = None
  let mut migrations_path : String? = None
  let mut message_profile = @runtime.CATALOG_PROFILE
  let mut profile_seen = false
  let mut cursor = 1
  while cursor < args.length() {
    let option = args[cursor]
    if option == "--state-output" ||
      option == "--report-output" ||
      option == "--id-migrations" ||
      option == "--message-profile" {
      if cursor + 1 >= args.length() {
        cli_fail(usage())
      }
      let value = args[cursor + 1]
      if option == "--state-output" {
        if state_output is Some(_) {
          cli_fail(usage())
        }
        state_output = Some(value)
      } else if option == "--report-output" {
        if report_output is Some(_) {
          cli_fail(usage())
        }
        report_output = Some(value)
      } else if option == "--id-migrations" {
        if migrations_path is Some(_) {
          cli_fail(usage())
        }
        migrations_path = Some(value)
      } else {
        if profile_seen {
          cli_fail(usage())
        }
        message_profile = value
        profile_seen = true
      }
      cursor = cursor + 2
    } else {
      values.push(option)
      cursor = cursor + 1
    }
  }
  if values.length() != 7 ||
    !@runtime.is_supported_message_profile(message_profile) {
    cli_fail(usage())
  }
  let resolved_state_output = state_output.unwrap_or(
    values[6] + ".xliff-state.json",
  )
  let resolved_report_output = report_output.unwrap_or(
    values[6] + ".xliff-report.json",
  )
  if resolved_state_output == values[6] ||
    resolved_report_output == values[6] ||
    resolved_state_output == resolved_report_output {
    cli_fail("XLIFF locale, state, and report outputs must be distinct paths")
  }
  let migrations = match migrations_path {
    Some("-") | None => None
    Some(path) =>
      Some(read_file_limited(path, @runtime.CATALOG_MAX_SOURCE_BYTES))
  }
  match
    @generator.import_xliff_with_state(
      read_file_limited(values[1], @runtime.CATALOG_MAX_SOURCE_BYTES),
      values[2],
      read_file_limited(values[3], @runtime.CATALOG_MAX_SOURCE_BYTES),
      values[4],
      read_file_limited(values[5], @generator.I18N_MAX_TOTAL_LOCALE_BYTES),
      migrations,
      message_profile~,
    ) {
    Ok(result) => {
      write_file(values[6], text_file_content(result.locale_source))
      write_file(
        resolved_state_output,
        text_file_content(result.exchange_state),
      )
      write_file(resolved_report_output, text_file_content(result.report))
    }
    Err(message) => cli_fail(message)
  }
}

///|
async fn run_import_i18next(args : Array[String]) -> Unit raise CliError {
  let values : Array[String] = [args[0]]
  let mut message_profile = @runtime.CATALOG_PROFILE
  let mut profile_seen = false
  let mut cursor = 1
  while cursor < args.length() {
    if args[cursor] == "--message-profile" {
      if profile_seen || cursor + 1 >= args.length() {
        cli_fail(usage())
      }
      message_profile = args[cursor + 1]
      profile_seen = true
      cursor = cursor + 2
    } else {
      values.push(args[cursor])
      cursor = cursor + 1
    }
  }
  if values.length() != 6 ||
    !@runtime.is_supported_message_profile(message_profile) {
    cli_fail(usage())
  }
  if values[4] == values[5] {
    cli_fail("migration locale and report outputs must be distinct paths")
  }
  match
    @generator.import_i18next_json(
      read_file_limited(values[1], @runtime.CATALOG_MAX_SOURCE_BYTES),
      values[2],
      read_file_limited(values[3], @generator.I18N_MAX_TOTAL_LOCALE_BYTES),
      message_profile~,
    ) {
    Ok(result) => {
      write_file(values[4], text_file_content(result.locale_source))
      write_file(values[5], text_file_content(result.report))
    }
    Err(message) => cli_fail(message)
  }
}

///|
async fn run_import_arb(args : Array[String]) -> Unit raise CliError {
  let values : Array[String] = [args[0]]
  let mut message_profile = @runtime.CATALOG_PROFILE
  let mut profile_seen = false
  let mut cursor = 1
  while cursor < args.length() {
    if args[cursor] == "--message-profile" {
      if profile_seen || cursor + 1 >= args.length() {
        cli_fail(usage())
      }
      message_profile = args[cursor + 1]
      profile_seen = true
      cursor = cursor + 2
    } else {
      values.push(args[cursor])
      cursor = cursor + 1
    }
  }
  if values.length() != 6 ||
    !@runtime.is_supported_message_profile(message_profile) {
    cli_fail(usage())
  }
  if values[4] == values[5] {
    cli_fail("migration locale and report outputs must be distinct paths")
  }
  match
    @generator.import_flutter_arb(
      read_file_limited(values[1], @runtime.CATALOG_MAX_SOURCE_BYTES),
      values[2],
      read_file_limited(values[3], @generator.I18N_MAX_TOTAL_LOCALE_BYTES),
      message_profile~,
    ) {
    Ok(result) => {
      write_file(values[4], text_file_content(result.locale_source))
      write_file(values[5], text_file_content(result.report))
    }
    Err(message) => cli_fail(message)
  }
}
