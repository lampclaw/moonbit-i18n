///|
fn run_pseudo(args : Array[String]) -> Unit {
  if args.length() != 6 {
    abort(usage())
  }
  match
    @generator.pseudo_locale(
      read_file(args[1]),
      args[2],
      read_file(args[3]),
      args[4],
    ) {
    Ok(value) => write_file(args[5], text_file_content(value))
    Err(message) => abort(message)
  }
}

///|
fn run_export_xliff(args : Array[String]) -> Unit {
  if args.length() != 7 {
    abort(usage())
  }
  let target = if args[5] == "-" { None } else { Some(read_file(args[5])) }
  match
    @generator.export_xliff(
      read_file(args[1]),
      args[2],
      read_file(args[3]),
      args[4],
      target,
    ) {
    Ok(value) => write_file(args[6], value)
    Err(message) => abort(message)
  }
}

///|
fn run_import_xliff(args : Array[String]) -> Unit {
  if args.length() != 5 {
    abort(usage())
  }
  match
    @generator.import_xliff(read_file(args[1]), args[2], read_file(args[3])) {
    Ok(value) => write_file(args[4], text_file_content(value))
    Err(message) => abort(message)
  }
}
