///|
async fn run_pseudo(args : Array[String]) -> Unit raise CliError {
  if args.length() != 6 {
    cli_fail(usage())
  }
  match
    @generator.pseudo_locale(
      read_file_limited(args[1], @runtime.CATALOG_MAX_SOURCE_BYTES),
      args[2],
      read_file_limited(args[3], @runtime.CATALOG_MAX_SOURCE_BYTES),
      args[4],
    ) {
    Ok(value) => write_file(args[5], text_file_content(value))
    Err(message) => cli_fail(message)
  }
}

///|
async fn run_export_xliff(args : Array[String]) -> Unit raise CliError {
  if args.length() != 7 {
    cli_fail(usage())
  }
  let target = if args[5] == "-" {
    None
  } else {
    Some(read_file_limited(args[5], @runtime.CATALOG_MAX_SOURCE_BYTES))
  }
  match
    @generator.export_xliff(
      read_file_limited(args[1], @runtime.CATALOG_MAX_SOURCE_BYTES),
      args[2],
      read_file_limited(args[3], @runtime.CATALOG_MAX_SOURCE_BYTES),
      args[4],
      target,
    ) {
    Ok(value) => write_file(args[6], value)
    Err(message) => cli_fail(message)
  }
}

///|
async fn run_import_xliff(args : Array[String]) -> Unit raise CliError {
  if args.length() != 7 {
    cli_fail(usage())
  }
  match
    @generator.import_xliff(
      read_file_limited(args[1], @runtime.CATALOG_MAX_SOURCE_BYTES),
      args[2],
      read_file_limited(args[3], @runtime.CATALOG_MAX_SOURCE_BYTES),
      args[4],
      read_file_limited(args[5], @generator.I18N_MAX_TOTAL_LOCALE_BYTES),
    ) {
    Ok(value) => write_file(args[6], text_file_content(value))
    Err(message) => cli_fail(message)
  }
}
