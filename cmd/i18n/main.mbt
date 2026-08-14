///|
priv suberror CliError {
  CommandFailed(String)
} derive(Debug)

///|
priv struct GeneratedTransaction {
  package_dir : String
  catalog_dir : String
  code : String
  package_manifest : String
  generation_manifest : String
  catalog_names : Array[String]
  catalog_contents : Array[String]
}

///|
priv struct TransactionState {
  package_dir : String
  catalog_dir : String
  package_stage : String
  catalog_stage : String
  package_backup : String
  catalog_backup : String
  had_package : Bool
  had_catalogs : Bool
}

///|
priv struct OwnershipManifest {
  files : Array[String]
}

///|
#cfg(target="native")
extern "C" fn exit(code : Int) = "exit"

///|
#cfg(target="wasm")
fn exit(code : UInt) = "wasi_snapshot_preview1" "proc_exit"

///|
fn[T] cli_fail(message : String) -> T raise CliError {
  raise CommandFailed(message)
}

///|
async fn[T] die(message : String) -> T {
  @stdio.stderr.write("\{message}\n") catch {
    _ => ()
  }
  exit(1)
  panic()
}

///|
const DIAGNOSTIC_ENVELOPE : String = "__LAMPCLAW_I18N_DIAGNOSTIC_V1__\n"

///|
const DIAGNOSTIC_HUMAN_SEPARATOR : String = "\n__LAMPCLAW_I18N_HUMAN_V1__\n"

///|
fn diagnostic_envelope(diagnostic : @generator.Diagnostic) -> String {
  DIAGNOSTIC_ENVELOPE +
  diagnostic.to_json_string() +
  DIAGNOSTIC_HUMAN_SEPARATOR +
  diagnostic.to_human_string()
}

///|
fn as_path(value : String) -> @path.Path {
  @path.Path(value)
}

///|
fn resolved_path(value : String) -> String {
  as_path(value).resolve().to_string()
}

///|
fn path_dirname(value : String) -> String {
  as_path(value).dirname().to_string()
}

///|
fn path_basename(value : String) -> String {
  as_path(value).basename().to_owned()
}

///|
fn path_join(left : String, right : String) -> String {
  as_path(left).join(as_path(right)).to_string()
}

///|
fn is_root_path(value : String) -> Bool {
  let path = as_path(value)
  path.dirname() == path
}

///|
fn path_contains(parent : String, child : String) -> Bool {
  if parent == child {
    return true
  }
  let relative = as_path(child).relative(base=as_path(parent))
  let text = relative.to_string()
  if text.is_empty() || relative.is_absolute() {
    return false
  }
  text != ".." && !text.has_prefix("../") && !text.has_prefix("..\\")
}

///|
fn valid_generated_filename(name : String) -> Bool {
  if !name.has_suffix(".json") || name.length() <= ".json".length() {
    return false
  }
  let chars = name.to_array()
  guard (match chars[0] {
    'a'..='z' | 'A'..='Z' | '0'..='9' => true
    _ => false
  }) else {
    return false
  }
  for char in chars {
    guard (match char {
      'a'..='z' | 'A'..='Z' | '0'..='9' | '.' | '_' | '-' => true
      _ => false
    }) else {
      return false
    }
  }
  true
}

///|
fn valid_nonce(nonce : String) -> Bool {
  if nonce.is_empty() || nonce.length() > 128 {
    return false
  }
  for char in nonce.to_array() {
    guard (match char {
      'a'..='z' | 'A'..='Z' | '0'..='9' | '-' => true
      _ => false
    }) else {
      return false
    }
  }
  true
}

///|
fn transaction_nonce(value : String, target : String, kind : String) -> String? {
  if resolved_path(value) != value ||
    path_dirname(value) != path_dirname(target) {
    return None
  }
  let prefix = ".\{path_basename(target)}.\{kind}-"
  let name = path_basename(value)
  if !name.has_prefix(prefix) {
    return None
  }
  let nonce = name[prefix.length():].to_owned()
  if valid_nonce(nonce) {
    Some(nonce)
  } else {
    None
  }
}

///|
async fn file_kind(path : String) -> @fs.FileKind raise CliError {
  try @fs.kind(path, follow_symlink=false) catch {
    err => cli_fail("cannot inspect \{path}: \{err}")
  } noraise {
    value => value
  }
}

///|
async fn file_exists(path : String) -> Bool raise CliError {
  try @fs.exists(path) catch {
    err => cli_fail("cannot inspect \{path}: \{err}")
  } noraise {
    value => value
  }
}

///|
async fn ensure_directory(path : String) -> Unit raise CliError {
  for attempt = 0; attempt < 8; attempt = attempt + 1 {
    if file_exists(path) {
      if !(file_kind(path) is Directory) {
        cli_fail("\{path} is not a directory")
      }
      return
    }
    try @fs.mkdir(path, recursive=true) catch {
      err => {
        // Concurrent recursive creators can expose an intermediate state in
        // which a parent exists but the target does not yet. Retry only this
        // bounded first-use race; a non-directory target fails immediately.
        if file_exists(path) {
          if !(file_kind(path) is Directory) {
            cli_fail("\{path} is not a directory")
          }
          return
        }
        if attempt == 7 {
          cli_fail("cannot create directory \{path}: \{err}")
        }
        @async.pause() catch {
          _ => ()
        }
      }
    } noraise {
      _ => return
    }
  }
  cli_fail("cannot create directory \{path}")
}

///|
async fn regular_file_size(path : String) -> Int64 raise CliError {
  if !(file_kind(path) is Regular) {
    cli_fail("cannot read \{path}: not a regular file")
  }
  let file = try @fs.open(path, mode=ReadOnly) catch {
    err => cli_fail("cannot open \{path}: \{err}")
  } noraise {
    value => value
  }
  defer file.close()
  try file.size() catch {
    err => cli_fail("cannot inspect \{path}: \{err}")
  } noraise {
    value => value
  }
}

///|
async fn read_file(path : String) -> String raise CliError {
  read_file_limited(path, @generator.I18N_MAX_TOTAL_LOCALE_BYTES)
}

///|
async fn read_file_limited(
  path : String,
  max_bytes : Int,
) -> String raise CliError {
  if max_bytes < 0 {
    cli_fail("invalid negative byte limit for \{path}")
  }
  if !(file_kind(path) is Regular) {
    cli_fail("cannot read \{path}: not a regular file")
  }
  let file = try @fs.open(path, mode=ReadOnly) catch {
    err => cli_fail("cannot open \{path}: \{err}")
  } noraise {
    value => value
  }
  defer file.close()
  let size = try file.size() catch {
    err => cli_fail("cannot inspect \{path}: \{err}")
  } noraise {
    value => value
  }
  if size > max_bytes.to_int64() {
    cli_fail("file exceeds the \{max_bytes}-byte limit: \{path}")
  }
  let bytes = try file.read_exactly_at(size.to_int(), position=0L) catch {
    err => cli_fail("cannot read \{path}: \{err}")
  } noraise {
    value => value
  }
  try @utf8.decode(bytes) catch {
    _ => cli_fail("cannot read \{path}: invalid UTF-8 encoded data")
  } noraise {
    value => value
  }
}

///|
async fn write_file(path : String, content : String) -> Unit raise CliError {
  let parent = path_dirname(resolved_path(path))
  ensure_directory(parent)
  try
    @fs.write_file(path, content, create_mode=CreateOrTruncate, sync=Full)
  catch {
    err => cli_fail("cannot write \{path}: \{err}")
  } noraise {
    _ => ()
  }
}

///|
async fn write_new_file(
  path : String,
  content : String,
  permission : Int,
) -> Unit raise CliError {
  try
    @fs.write_file(path, content, create_mode=CreateNew, permission~, sync=Full)
  catch {
    err => cli_fail("cannot create \{path}: \{err}")
  } noraise {
    _ => ()
  }
}

///|
async fn read_dir(path : String) -> Array[String] raise CliError {
  if !(file_kind(path) is Directory) {
    cli_fail("cannot read directory \{path}: not a directory")
  }
  try @fs.readdir(path, include_hidden=true, sort=true) catch {
    err => cli_fail("cannot read directory \{path}: \{err}")
  } noraise {
    value => value
  }
}

///|
async fn remove_path(path : String) -> Unit raise CliError {
  if !file_exists(path) {
    return
  }
  let kind = file_kind(path)
  if kind is Directory {
    try @fs.rmdir(path, recursive=true) catch {
      err => cli_fail("cannot remove directory \{path}: \{err}")
    } noraise {
      _ => ()
    }
  } else {
    try @fs.remove(path) catch {
      err => cli_fail("cannot remove \{path}: \{err}")
    } noraise {
      _ => ()
    }
  }
}

///|
async fn rename_path(from : String, to : String) -> Unit raise CliError {
  try @fs.rename(from, to, replace=false) catch {
    err => cli_fail("cannot rename \{from} to \{to}: \{err}")
  } noraise {
    _ => ()
  }
}

///|
fn json_string_field(object : Map[String, Json], name : String) -> String? {
  match object.get(name) {
    Some(String(value)) => Some(value)
    _ => None
  }
}

///|
fn json_bool_field(object : Map[String, Json], name : String) -> Bool? {
  match object.get(name) {
    Some(True) => Some(true)
    Some(False) => Some(false)
    _ => None
  }
}

///|
fn json_int_field(object : Map[String, Json], name : String) -> Int? {
  match object.get(name) {
    Some(Number(value, ..)) => {
      let integer = value.to_int()
      if integer.to_double() == value {
        Some(integer)
      } else {
        None
      }
    }
    _ => None
  }
}

///|
#warnings("-deprecated")
fn parse_ownership_manifest(
  source : String,
  expected_kind : String,
) -> OwnershipManifest raise CliError {
  let json = try @json.parse(source, max_nesting_depth=16) catch {
    _ => cli_fail("invalid generated-directory ownership manifest JSON")
  } noraise {
    value => value
  }
  guard json is Object(object) else {
    cli_fail("invalid generated-directory ownership manifest")
  }
  guard json_int_field(object, "version") is Some(version) &&
    (version == 1 || version == 2) &&
    json_string_field(object, "generator") is Some("lampclaw/i18n") &&
    json_string_field(object, "kind") is Some(kind) &&
    kind == expected_kind &&
    object.get("files") is Some(Array(raw_files)) else {
    cli_fail("invalid generated-directory ownership manifest")
  }
  let files : Array[String] = []
  for raw in raw_files {
    guard raw is String(name) else {
      cli_fail("invalid generated-directory ownership manifest")
    }
    if files.contains(name) {
      cli_fail("invalid generated-directory ownership manifest")
    }
    files.push(name)
  }
  if kind == "package" {
    let legacy = files.length() == 2 &&
      files.contains("generated.mbt") &&
      files.contains("moon.pkg")
    let current = files.length() == 3 &&
      files.contains("generated.mbt") &&
      files.contains("moon.pkg") &&
      files.contains("generation-manifest.json")
    if !legacy && !current {
      cli_fail("invalid generated-directory ownership manifest")
    }
  } else {
    for file in files {
      if !valid_generated_filename(file) {
        cli_fail("invalid generated-directory ownership manifest")
      }
    }
  }
  { files, }
}

///|
async fn verify_owned_entries(
  directory : String,
  kind : String,
  entries : Array[String],
  manifest : OwnershipManifest,
) -> Unit raise CliError {
  let expected = manifest.files.copy()
  expected.push(".lampclaw-i18n.json")
  if kind == "package" {
    expected.push("pkg.generated.mbti")
  }
  for entry in entries {
    let entry_path = path_join(directory, entry)
    if !expected.contains(entry) {
      cli_fail("refusing to replace unowned file: \{entry_path}")
    }
    if !(file_kind(entry_path) is Regular) {
      cli_fail("refusing to replace non-file generated artifact: \{entry_path}")
    }
    let limit = if entry == ".lampclaw-i18n.json" {
      64 * 1024
    } else if kind == "package" {
      @generator.I18N_MAX_GENERATED_CODE_BYTES
    } else {
      @runtime.CATALOG_MAX_SOURCE_BYTES
    }
    if regular_file_size(entry_path) > limit.to_int64() {
      cli_fail("generated artifact exceeds size limit: \{entry_path}")
    }
  }
}

///|
async fn verify_unowned_package(
  directory : String,
  entries : Array[String],
) -> Unit raise CliError {
  let allowed = [
    "generated.mbt", "moon.pkg", "generation-manifest.json", "pkg.generated.mbti",
  ]
  for entry in entries {
    let entry_path = path_join(directory, entry)
    if !allowed.contains(entry) ||
      !(file_kind(entry_path) is Regular) ||
      regular_file_size(entry_path) >
      @generator.I18N_MAX_GENERATED_CODE_BYTES.to_int64() {
      cli_fail("refusing to adopt invalid generated artifact: \{entry_path}")
    }
    if entry == "generated.mbt" || entry == "moon.pkg" {
      let source = read_file_limited(
        entry_path,
        @generator.I18N_MAX_GENERATED_CODE_BYTES,
      )
      if !is_generated_content(source) {
        cli_fail("refusing to overwrite unowned i18n file: \{entry_path}")
      }
    } else if entry == "generation-manifest.json" &&
      !looks_like_generation_manifest(
        read_file_limited(entry_path, 1024 * 1024),
      ) {
      cli_fail("refusing to overwrite unowned i18n file: \{entry_path}")
    }
  }
}

///|
#warnings("-deprecated")
fn looks_like_generation_manifest(source : String) -> Bool {
  let json = try @json.parse(source, max_nesting_depth=16) catch {
    _ => return false
  } noraise {
    value => value
  }
  guard json is Object(object) else { return false }
  json_int_field(object, "manifestVersion") is Some(1) &&
  json_string_field(object, "generator") is Some("lampclaw/i18n")
}

///|
#warnings("-deprecated")
fn looks_like_generated_catalog(source : String) -> Bool {
  let json = try @json.parse(source, max_nesting_depth=64) catch {
    _ => return false
  } noraise {
    value => value
  }
  guard json is Object(object) else { return false }
  if json_int_field(object, "manifestVersion") is Some(1) &&
    json_string_field(object, "generator") is Some("lampclaw/i18n") &&
    object.get("chunks") is Some(Array(_)) {
    return true
  }
  guard object.get("catalogVersion") is Some(Number(_, ..)) else {
    return false
  }
  object.get("contractHash") is Some(String(_)) ||
  object.get("schemaHash") is Some(String(_))
}

///|
async fn verify_unowned_catalogs(
  directory : String,
  entries : Array[String],
) -> Unit raise CliError {
  for entry in entries {
    let entry_path = path_join(directory, entry)
    if !valid_generated_filename(entry) ||
      !(file_kind(entry_path) is Regular) ||
      regular_file_size(entry_path) >
      @runtime.CATALOG_MAX_SOURCE_BYTES.to_int64() {
      cli_fail("refusing to adopt invalid generated artifact: \{entry_path}")
    }
    if !looks_like_generated_catalog(
        read_file_limited(entry_path, @runtime.CATALOG_MAX_SOURCE_BYTES),
      ) {
      cli_fail("refusing to adopt non-catalog file: \{entry_path}")
    }
  }
}

///|
async fn verify_generated_directory(
  directory : String,
  kind : String,
) -> Unit raise CliError {
  if !file_exists(directory) {
    return
  }
  if !(file_kind(directory) is Directory) {
    cli_fail("\{directory} is not a directory")
  }
  let entries = read_dir(directory)
  let owner_path = path_join(directory, ".lampclaw-i18n.json")
  if file_exists(owner_path) {
    let manifest = parse_ownership_manifest(
      read_file_limited(owner_path, 64 * 1024),
      kind,
    ) catch {
      CommandFailed(_) =>
        cli_fail(
          "invalid generated-directory ownership manifest: \{owner_path}",
        )
    }
    verify_owned_entries(directory, kind, entries, manifest)
  } else if kind == "package" {
    verify_unowned_package(directory, entries)
  } else {
    verify_unowned_catalogs(directory, entries)
  }
}

///|
fn transaction_state_json(state : TransactionState) -> String {
  Json::object({
    "version": Json::number(2.0),
    "pkg": Json::string(state.package_dir),
    "catalogs": Json::string(state.catalog_dir),
    "pkgStage": Json::string(state.package_stage),
    "catStage": Json::string(state.catalog_stage),
    "pkgBackup": Json::string(state.package_backup),
    "catBackup": Json::string(state.catalog_backup),
    "hadPkg": Json::boolean(state.had_package),
    "hadCatalogs": Json::boolean(state.had_catalogs),
  }).stringify(indent=2) +
  "\n"
}

///|
#warnings("-deprecated")
fn parse_transaction_state(
  source : String,
  package_dir : String,
  catalog_dir : String,
) -> TransactionState raise CliError {
  let json = try @json.parse(source, max_nesting_depth=16) catch {
    _ => cli_fail("invalid i18n transaction journal")
  } noraise {
    value => value
  }
  guard json is Object(object) else {
    cli_fail("invalid i18n transaction journal")
  }
  guard json_int_field(object, "version") is Some(version) &&
    (version == 1 || version == 2) &&
    json_string_field(object, "pkg") is Some(pkg) &&
    json_string_field(object, "catalogs") is Some(catalogs) &&
    json_string_field(object, "pkgStage") is Some(pkg_stage) &&
    json_string_field(object, "catStage") is Some(cat_stage) &&
    json_string_field(object, "pkgBackup") is Some(pkg_backup) &&
    json_string_field(object, "catBackup") is Some(cat_backup) &&
    json_bool_field(object, "hadPkg") is Some(had_pkg) &&
    json_bool_field(object, "hadCatalogs") is Some(had_catalogs) &&
    pkg == package_dir &&
    catalogs == catalog_dir &&
    transaction_nonce(pkg_stage, pkg, "stage") is Some(nonce) &&
    transaction_nonce(cat_stage, catalogs, "stage") is Some(cat_nonce) &&
    transaction_nonce(pkg_backup, pkg, "backup") is Some(pkg_backup_nonce) &&
    transaction_nonce(cat_backup, catalogs, "backup") is Some(cat_backup_nonce) &&
    nonce == cat_nonce &&
    nonce == pkg_backup_nonce &&
    nonce == cat_backup_nonce else {
    cli_fail("invalid i18n transaction journal")
  }
  {
    package_dir: pkg,
    catalog_dir: catalogs,
    package_stage: pkg_stage,
    catalog_stage: cat_stage,
    package_backup: pkg_backup,
    catalog_backup: cat_backup,
    had_package: had_pkg,
    had_catalogs,
  }
}

///|
async fn validate_transaction_artifact(path : String) -> Unit raise CliError {
  let kind = try @fs.kind(path, follow_symlink=false) catch {
    _ => None
  } noraise {
    kind => Some(kind)
  }
  match kind {
    Some(Directory) | None => ()
    Some(_) => cli_fail("invalid i18n transaction artifact: \{path}")
  }
}

///|
async fn settle_transaction(
  state : TransactionState,
  journal : String,
) -> Bool raise CliError {
  for
    artifact in [
      state.package_stage,
      state.catalog_stage,
      state.package_backup,
      state.catalog_backup,
    ] {
    validate_transaction_artifact(artifact)
  }
  let committed = !file_exists(state.package_stage) &&
    !file_exists(state.catalog_stage) &&
    file_exists(state.package_dir) &&
    file_exists(state.catalog_dir)
  if !committed {
    if file_exists(state.package_backup) {
      remove_path(state.package_dir)
      rename_path(state.package_backup, state.package_dir)
    } else if !state.had_package {
      remove_path(state.package_dir)
    }
    if file_exists(state.catalog_backup) {
      remove_path(state.catalog_dir)
      rename_path(state.catalog_backup, state.catalog_dir)
    } else if !state.had_catalogs {
      remove_path(state.catalog_dir)
    }
  }
  remove_path(state.package_stage)
  remove_path(state.catalog_stage)
  remove_path(state.package_backup)
  remove_path(state.catalog_backup)
  remove_path(journal)
  committed
}

///|
async fn recover_transaction(
  journal : String,
  package_dir : String,
  catalog_dir : String,
) -> Unit raise CliError {
  if !file_exists(journal) {
    return
  }
  let state = parse_transaction_state(
    read_file_limited(journal, 64 * 1024),
    package_dir,
    catalog_dir,
  ) catch {
    CommandFailed(_) => cli_fail("invalid i18n transaction journal: \{journal}")
  }
  ignore(settle_transaction(state, journal))
}

///|
fn ownership_manifest(kind : String, files : Array[String]) -> String {
  let quoted = files.map(file => "\"\{file}\"").join(", ")
  "{\n  \"version\": 2,\n  \"generator\": \"lampclaw/i18n\",\n  \"kind\": \"\{kind}\",\n  \"files\": [\{quoted}]\n}\n"
}

///|
fn transaction_journal(package_dir : String) -> String {
  path_join(
    path_dirname(package_dir),
    ".\{path_basename(package_dir)}.lampclaw-journal.json",
  )
}

///|
fn generation_lock_directory_from(
  environment : Map[String, String],
  current_directory : String,
) -> String {
  match environment.get("LAMPCLAW_I18N_STATE_DIR") {
    Some(value) if !value.trim().is_empty() => return resolved_path(value)
    _ => ()
  }
  match environment.get("XDG_CACHE_HOME") {
    Some(value) if !value.trim().is_empty() =>
      return path_join(resolved_path(value), "lampclaw-i18n/locks")
    _ => ()
  }
  match environment.get("LOCALAPPDATA") {
    Some(value) if !value.trim().is_empty() =>
      return path_join(resolved_path(value), "lampclaw/i18n/locks")
    _ => ()
  }
  for name in ["HOME", "USERPROFILE"] {
    match environment.get(name) {
      Some(value) if !value.trim().is_empty() =>
        return path_join(resolved_path(value), ".cache/lampclaw-i18n/locks")
      _ => ()
    }
  }
  for name in ["TMPDIR", "TEMP", "TMP"] {
    match environment.get(name) {
      Some(value) if !value.trim().is_empty() =>
        return path_join(resolved_path(value), "lampclaw-i18n/locks")
      _ => ()
    }
  }
  path_join(current_directory, ".lampclaw-i18n-locks")
}

///|
fn generation_lock_directory() -> String {
  generation_lock_directory_from(@env.get_env_vars(), resolved_path("."))
}

///|
fn transaction_lock_path(directory : String, lock_directory : String) -> String {
  let digest = @crypto.bytes_to_hex_string(
    @crypto.sha256(@utf8.encode(resolved_path(directory))),
  )
  path_join(lock_directory, "\{digest}.lampclaw.lock")
}

///|
fn make_transaction_state(
  transaction : GeneratedTransaction,
  nonce : String,
) -> TransactionState {
  let package_parent = path_dirname(transaction.package_dir)
  let catalog_parent = path_dirname(transaction.catalog_dir)
  let package_name = path_basename(transaction.package_dir)
  let catalog_name = path_basename(transaction.catalog_dir)
  {
    package_dir: transaction.package_dir,
    catalog_dir: transaction.catalog_dir,
    package_stage: path_join(package_parent, ".\{package_name}.stage-\{nonce}"),
    catalog_stage: path_join(catalog_parent, ".\{catalog_name}.stage-\{nonce}"),
    package_backup: path_join(
      package_parent,
      ".\{package_name}.backup-\{nonce}",
    ),
    catalog_backup: path_join(
      catalog_parent,
      ".\{catalog_name}.backup-\{nonce}",
    ),
    had_package: false,
    had_catalogs: false,
  }
}

///|
async fn allocate_transaction_state(
  transaction : GeneratedTransaction,
) -> TransactionState raise CliError {
  for attempt = 0; attempt < 100; attempt = attempt + 1 {
    let nonce = "\{@async.now()}-\{attempt}"
    let candidate = make_transaction_state(transaction, nonce)
    if !file_exists(candidate.package_stage) &&
      !file_exists(candidate.catalog_stage) &&
      !file_exists(candidate.package_backup) &&
      !file_exists(candidate.catalog_backup) {
      return {
        ..candidate,
        had_package: file_exists(transaction.package_dir),
        had_catalogs: file_exists(transaction.catalog_dir),
      }
    }
  }
  cli_fail("cannot allocate unique i18n transaction paths")
}

///|
async fn stage_transaction(
  transaction : GeneratedTransaction,
  state : TransactionState,
) -> Unit raise CliError {
  try @fs.mkdir(state.package_stage) catch {
    err => cli_fail("cannot create \{state.package_stage}: \{err}")
  } noraise {
    _ => ()
  }
  try @fs.mkdir(state.catalog_stage) catch {
    err => cli_fail("cannot create \{state.catalog_stage}: \{err}")
  } noraise {
    _ => ()
  }
  write_new_file(
    path_join(state.package_stage, "generated.mbt"),
    transaction.code,
    0o644,
  )
  write_new_file(
    path_join(state.package_stage, "moon.pkg"),
    transaction.package_manifest,
    0o644,
  )
  let package_files = ["generated.mbt", "moon.pkg"]
  if !transaction.generation_manifest.is_empty() {
    write_new_file(
      path_join(state.package_stage, "generation-manifest.json"),
      transaction.generation_manifest,
      0o644,
    )
    package_files.push("generation-manifest.json")
  }
  write_new_file(
    path_join(state.package_stage, ".lampclaw-i18n.json"),
    ownership_manifest("package", package_files),
    0o644,
  )
  for index = 0; index < transaction.catalog_names.length(); index = index + 1 {
    write_new_file(
      path_join(state.catalog_stage, transaction.catalog_names[index]),
      transaction.catalog_contents[index],
      0o644,
    )
  }
  write_new_file(
    path_join(state.catalog_stage, ".lampclaw-i18n.json"),
    ownership_manifest("catalogs", transaction.catalog_names),
    0o644,
  )
}

///|
async fn commit_transaction(
  state : TransactionState,
  journal : String,
) -> Unit raise CliError {
  try {
    if file_exists(state.package_dir) {
      rename_path(state.package_dir, state.package_backup)
    }
    if file_exists(state.catalog_dir) {
      rename_path(state.catalog_dir, state.catalog_backup)
    }
    rename_path(state.package_stage, state.package_dir)
    rename_path(state.catalog_stage, state.catalog_dir)
    remove_path(state.package_backup)
    remove_path(state.catalog_backup)
    remove_path(journal)
  } catch {
    CommandFailed(message) => {
      let committed = settle_transaction(state, journal) catch {
        CommandFailed(recovery) =>
          cli_fail(
            "i18n transaction failed (\{message}) and recovery failed: \{recovery}",
          )
      }
      if !committed {
        cli_fail("i18n transaction failed and was rolled back: \{message}")
      }
    }
  }
}

///|
async fn open_generation_lock(path : String) -> @fs.File raise CliError {
  if file_exists(path) {
    if !(file_kind(path) is Regular) {
      cli_fail("generation lock is not a regular file: \{path}")
    }
  }
  let file = try
    @fs.open(path, mode=ReadWrite, create_mode=OpenOrCreate, permission=0o600)
  catch {
    err => cli_fail("cannot open generation lock \{path}: \{err}")
  } noraise {
    value => value
  }
  let acquired = try file.try_lock(Exclusive) catch {
    err => {
      file.close()
      cli_fail("cannot acquire generation lock \{path}: \{err}")
    }
  } noraise {
    value => value
  }
  if !acquired {
    file.close()
    cli_fail("another i18n generation transaction is active for: \{path}")
  }
  file
}

///|
async fn generated_file_matches(
  path : String,
  expected : String,
  limit : Int,
) -> Bool raise CliError {
  if !file_exists(path) || !(file_kind(path) is Regular) {
    return false
  }
  if regular_file_size(path) != @utf8.encode(expected).length().to_int64() {
    return false
  }
  read_file_limited(path, limit) == expected
}

///|
async fn generated_transaction_matches(
  transaction : GeneratedTransaction,
) -> Bool raise CliError {
  if !file_exists(transaction.package_dir) ||
    !file_exists(transaction.catalog_dir) {
    return false
  }
  let package_files = ["generated.mbt", "moon.pkg"]
  if !transaction.generation_manifest.is_empty() {
    package_files.push("generation-manifest.json")
  }
  let expected_package_entries = package_files.copy()
  expected_package_entries.push(".lampclaw-i18n.json")
  if file_exists(path_join(transaction.package_dir, "pkg.generated.mbti")) {
    expected_package_entries.push("pkg.generated.mbti")
  }
  expected_package_entries.sort_by((left, right) => left.lexical_compare(right))
  let actual_package_entries = read_dir(transaction.package_dir)
  actual_package_entries.sort_by((left, right) => left.lexical_compare(right))
  if actual_package_entries != expected_package_entries {
    return false
  }
  if !generated_file_matches(
      path_join(transaction.package_dir, "generated.mbt"),
      transaction.code,
      @generator.I18N_MAX_GENERATED_CODE_BYTES,
    ) ||
    !generated_file_matches(
      path_join(transaction.package_dir, "moon.pkg"),
      transaction.package_manifest,
      64 * 1024,
    ) ||
    !generated_file_matches(
      path_join(transaction.package_dir, ".lampclaw-i18n.json"),
      ownership_manifest("package", package_files),
      64 * 1024,
    ) {
    return false
  }
  if !transaction.generation_manifest.is_empty() &&
    !generated_file_matches(
      path_join(transaction.package_dir, "generation-manifest.json"),
      transaction.generation_manifest,
      1024 * 1024,
    ) {
    return false
  }
  let expected_catalog_entries = transaction.catalog_names.copy()
  expected_catalog_entries.push(".lampclaw-i18n.json")
  expected_catalog_entries.sort_by((left, right) => left.lexical_compare(right))
  let actual_catalog_entries = read_dir(transaction.catalog_dir)
  actual_catalog_entries.sort_by((left, right) => left.lexical_compare(right))
  if actual_catalog_entries != expected_catalog_entries ||
    !generated_file_matches(
      path_join(transaction.catalog_dir, ".lampclaw-i18n.json"),
      ownership_manifest("catalogs", transaction.catalog_names),
      64 * 1024,
    ) {
    return false
  }
  for index = 0; index < transaction.catalog_names.length(); index = index + 1 {
    if !generated_file_matches(
        path_join(transaction.catalog_dir, transaction.catalog_names[index]),
        transaction.catalog_contents[index],
        @runtime.CATALOG_MAX_SOURCE_BYTES,
      ) {
      return false
    }
  }
  true
}

///|
async fn run_locked_transaction(
  transaction : GeneratedTransaction,
) -> Unit raise CliError {
  let journal = transaction_journal(transaction.package_dir)
  recover_transaction(journal, transaction.package_dir, transaction.catalog_dir)
  verify_generated_directory(transaction.package_dir, "package")
  verify_generated_directory(transaction.catalog_dir, "catalogs")
  if generated_transaction_matches(transaction) {
    return
  }
  let state = allocate_transaction_state(transaction)
  stage_transaction(transaction, state) catch {
    CommandFailed(message) => {
      remove_path(state.package_stage) catch {
        _ => ()
      }
      remove_path(state.catalog_stage) catch {
        _ => ()
      }
      cli_fail(message)
    }
  }
  write_new_file(journal, transaction_state_json(state), 0o600) catch {
    CommandFailed(message) => {
      remove_path(state.package_stage) catch {
        _ => ()
      }
      remove_path(state.catalog_stage) catch {
        _ => ()
      }
      cli_fail(message)
    }
  }
  commit_transaction(state, journal)
}

///|
async fn with_generation_locks(
  transaction : GeneratedTransaction,
  first : String,
  second : String,
) -> Unit raise CliError {
  let first_lock = open_generation_lock(first)
  defer first_lock.close()
  defer first_lock.unlock()
  let second_lock = open_generation_lock(second)
  defer second_lock.close()
  defer second_lock.unlock()
  run_locked_transaction(transaction)
}

///|
fn validate_transaction(
  transaction : GeneratedTransaction,
) -> Unit raise CliError {
  if is_root_path(transaction.package_dir) ||
    is_root_path(transaction.catalog_dir) ||
    path_contains(transaction.package_dir, transaction.catalog_dir) ||
    path_contains(transaction.catalog_dir, transaction.package_dir) {
    cli_fail(
      "generated package and catalog directories must be distinct dedicated directories",
    )
  }
  if transaction.catalog_names.length() != transaction.catalog_contents.length() {
    cli_fail("catalog artifact arrays have different lengths")
  }
  if @utf8.encode(transaction.code).length() >
    @generator.I18N_MAX_GENERATED_CODE_BYTES {
    cli_fail("generated MoonBit source exceeds the configured size limit")
  }
  if @utf8.encode(transaction.package_manifest).length() > 64 * 1024 {
    cli_fail("generated package manifest exceeds the configured size limit")
  }
  if @utf8.encode(transaction.generation_manifest).length() > 1024 * 1024 {
    cli_fail("generation manifest exceeds the configured size limit")
  }
  let seen : Map[String, Bool] = Map([])
  for index = 0; index < transaction.catalog_names.length(); index = index + 1 {
    let name = transaction.catalog_names[index]
    if !valid_generated_filename(name) || seen.contains(name) {
      cli_fail("invalid generated catalog filename: \{name}")
    }
    if @utf8.encode(transaction.catalog_contents[index]).length() >
      @runtime.CATALOG_MAX_SOURCE_BYTES {
      cli_fail("generated catalog exceeds the configured size limit: \{name}")
    }
    seen[name] = true
  }
}

///|
async fn write_generated_transaction(
  package_dir : String,
  catalog_dir : String,
  code : String,
  package_manifest : String,
  catalog_names : Array[String],
  catalog_contents : Array[String],
  generation_manifest? : String = "",
) -> Unit raise CliError {
  let transaction = GeneratedTransaction::{
    package_dir: resolved_path(package_dir),
    catalog_dir: resolved_path(catalog_dir),
    code,
    package_manifest,
    generation_manifest,
    catalog_names,
    catalog_contents,
  }
  validate_transaction(transaction)
  ensure_directory(path_dirname(transaction.package_dir))
  ensure_directory(path_dirname(transaction.catalog_dir))
  let lock_directory = generation_lock_directory()
  ensure_directory(lock_directory)
  let package_lock = transaction_lock_path(
    transaction.package_dir,
    lock_directory,
  )
  let catalog_lock = transaction_lock_path(
    transaction.catalog_dir,
    lock_directory,
  )
  if package_lock.lexical_compare(catalog_lock) <= 0 {
    with_generation_locks(transaction, package_lock, catalog_lock)
  } else {
    with_generation_locks(transaction, catalog_lock, package_lock)
  }
}

///|
fn format_moonbit_source(source : String) -> String {
  @fmt.format(source)
  .split("\n")
  .map(line => line.trim_end().to_owned())
  .collect()
  .join("\n")
  .trim_end()
  .to_owned() +
  "\n"
}

///|
const CLI_VERSION : String = "0.8.0"

///|
fn usage() -> String {
  "moon-i18n \{CLI_VERSION}\n" +
  (
    #|
    #|usage:
    #|  moonx lampclaw/i18n/cmd/i18n@0.8.0 scaffold <owner/module> <directory>
    #|  moonx lampclaw/i18n/cmd/i18n@0.8.0 generate [--allow-partial] <config-file> <schema-file> <locale-dir> <package-dir> <catalog-dir>
    #|  moonx lampclaw/i18n/cmd/i18n@0.8.0 check [--allow-partial] <config-file> <schema-file> <locale-dir> <package-dir> <catalog-dir>
    #|  moonx lampclaw/i18n/cmd/i18n@0.8.0 coverage <config-file> <schema-file> <locale-dir>
    #|  moonx lampclaw/i18n/cmd/i18n@0.8.0 pseudo [--message-profile <profile>] <schema-file> <source-locale> <source.json> <en-XA|ar-XB> <output.json>
    #|  moonx lampclaw/i18n/cmd/i18n@0.8.0 export-xliff [--message-profile <profile>] [--state <exchange-state.json>] <schema-file> <source-locale> <source.json> <target-locale> <target.json|-> <output.xlf>
    #|  moonx lampclaw/i18n/cmd/i18n@0.8.0 import-xliff [--message-profile <profile>] [--state-output <exchange-state.json>] [--report-output <report.json>] [--id-migrations <map.json>] <schema-file> <source-locale> <source.json> <target-locale> <input.xlf> <output.json>
    #|  moonx lampclaw/i18n/cmd/i18n@0.8.0 import-i18next [--message-profile <profile>] <schema-file> <locale> <input.json> <output.json> <report.json>
    #|  moonx lampclaw/i18n/cmd/i18n@0.8.0 import-arb [--message-profile <profile>] <schema-file> <locale> <input.arb> <output.json> <report.json>
  )
}

///|
fn is_command(arg : String) -> Bool {
  arg == "scaffold" ||
  arg == "generate" ||
  arg == "check" ||
  arg == "coverage" ||
  arg == "pseudo" ||
  arg == "export-xliff" ||
  arg == "import-xliff" ||
  arg == "import-i18next" ||
  arg == "import-arb" ||
  arg == "help" ||
  arg == "--help" ||
  arg == "-h" ||
  arg == "--version" ||
  arg == "-V"
}

///|
fn valid_module_segment(segment : String) -> Bool {
  if segment.is_empty() {
    return false
  }
  let chars = segment.to_array()
  if !((chars[0] >= 'a' && chars[0] <= 'z') ||
    (chars[0] >= 'A' && chars[0] <= 'Z')) {
    return false
  }
  for char in chars {
    if !((char >= 'a' && char <= 'z') ||
      (char >= 'A' && char <= 'Z') ||
      (char >= '0' && char <= '9') ||
      char == '_' ||
      char == '-') {
      return false
    }
  }
  true
}

///|
fn valid_module_name(name : String) -> Bool {
  let segments : Array[String] = name
    .split("/")
    .map(segment => segment.to_owned())
    .collect()
  segments.length() == 2 &&
  valid_module_segment(segments[0]) &&
  valid_module_segment(segments[1])
}

///|
fn scaffold_moon_mod(module_name : String) -> String {
  "name = \"\{module_name}\"\n\n" +
  "version = \"0.8.0\"\n\n" +
  "preferred_target = \"js\"\n\n" +
  "import {\n  \"lampclaw/i18n@\{CLI_VERSION}\",\n}\n"
}

///|
fn scaffold_config() -> String {
  (
    #|{
    #|  "messageProfile": "unicode-mf2-ldml48.2-js-v1",
    #|  "sourceLocale": "en-US",
    #|  "defaultLocale": "en-US",
    #|  "fallbackLocale": "en-US",
    #|  "embeddedLocales": ["en-US"],
    #|  "release": { "minimumCoverage": 1.0 },
    #|  "locales": {
    #|    "en-US": { "direction": "ltr" },
    #|    "zh-CN": { "direction": "ltr" }
    #|  }
    #|}
    #|
  )
}

///|
fn scaffold_schema() -> String {
  (
    #|{
    #|  "messages": { "common": ["hello"] },
    #|  "params": {
    #|    "common.hello": [{ "name": "name", "type": "String" }]
    #|  },
    #|  "descriptions": {
    #|    "common.hello": "Greets a named user."
    #|  }
    #|}
    #|
  )
}

///|
fn scaffold_main_package(module_name : String) -> String {
  "import {\n  \"\{module_name}/i18n\" @app_i18n,\n}\n\n" +
  "supported_targets = \"js\"\n\n" +
  "pkgtype(kind: \"executable\")\n"
}

///|
fn scaffold_main_source() -> String {
  (
    #|///|
    #|fn main {
    #|  let i18n = @app_i18n.I18n::new()
    #|  let translator = i18n.translator(@app_i18n.EnUS)
    #|  println(translator.t(@app_i18n.Common(@app_i18n.Hello("MoonBit"))))
    #|}
    #|
  )
}

///|
fn scaffold_readme(module_name : String) -> String {
  "# \{module_name}\n\n" +
  "Generated by `moon-i18n scaffold`. English is embedded and `zh-CN` " +
  "is emitted as a dynamic catalog.\n\n" +
  "```bash\nmoon update\nmoon check --target js\n" +
  "moon run --target js main\n```\n"
}

///|
async fn write_scaffold_sources(
  root : String,
  module_name : String,
) -> Unit raise CliError {
  write_file(path_join(root, "moon.mod"), scaffold_moon_mod(module_name))
  write_file(path_join(root, "README.md"), scaffold_readme(module_name))
  write_file(path_join(root, "localization/config.json"), scaffold_config())
  write_file(path_join(root, "localization/schema.json"), scaffold_schema())
  write_file(
    path_join(root, "localization/locales/en-US.json"),
    "{\"common\":{\"hello\":\"Hello {$name}\"}}\n",
  )
  write_file(
    path_join(root, "localization/locales/zh-CN.json"),
    "{\"common\":{\"hello\":\"你好，{$name}\"}}\n",
  )
  write_file(
    path_join(root, "main/moon.pkg"),
    scaffold_main_package(module_name),
  )
  write_file(path_join(root, "main/main.mbt"), scaffold_main_source())
}

///|
async fn remove_scaffold_stage_locks(stage : String) -> Unit raise CliError {
  let lock_directory = generation_lock_directory()
  for directory in [path_join(stage, "i18n"), path_join(stage, "public/i18n")] {
    let lock_path = transaction_lock_path(directory, lock_directory)
    if file_exists(lock_path) {
      if !(file_kind(lock_path) is Regular) {
        cli_fail("scaffold generation lock is not a regular file: \{lock_path}")
      }
      remove_path(lock_path)
    }
  }
}

///|
async fn run_scaffold(args : Array[String]) -> Unit raise CliError {
  if args.length() != 3 {
    cli_fail(usage())
  }
  let module_name = args[1]
  if !valid_module_name(module_name) {
    cli_fail("module name must be owner/module with portable ASCII segments")
  }
  let destination = resolved_path(args[2])
  if is_root_path(destination) {
    cli_fail("refusing to scaffold into a filesystem root")
  }
  if file_exists(destination) {
    cli_fail(
      "refusing to overwrite existing scaffold destination: \{destination}",
    )
  }
  let parent = path_dirname(destination)
  ensure_directory(parent)
  let stage = path_join(
    parent,
    ".\{path_basename(destination)}.scaffold-\{@async.now()}",
  )
  if file_exists(stage) {
    cli_fail("cannot allocate scaffold staging directory: \{stage}")
  }
  ensure_directory(stage)
  try {
    write_scaffold_sources(stage, module_name)
    run_generate(
      [
        "generate",
        path_join(stage, "localization/config.json"),
        path_join(stage, "localization/schema.json"),
        path_join(stage, "localization/locales"),
        path_join(stage, "i18n"),
        path_join(stage, "public/i18n"),
      ],
      false,
    )
    remove_scaffold_stage_locks(stage)
    rename_path(stage, destination)
  } catch {
    CommandFailed(message) => {
      remove_path(stage) catch {
        _ => ()
      }
      cli_fail(message)
    }
  }
  println("scaffolded \{module_name} at \{destination}")
}

///|
fn user_args(args : Array[String]) -> Array[String] {
  for i = 0; i < args.length(); i = i + 1 {
    if args[i] == "--" {
      return args[i + 1:].to_owned()
    }
  }
  for i = 0; i < args.length(); i = i + 1 {
    if is_command(args[i]) {
      return args[i:].to_owned()
    }
  }
  []
}

///|
fn without_allow_partial(args : Array[String]) -> Array[String] {
  args.filter(arg => {
    arg != "--allow-partial" &&
    arg != "--diagnostic-format=json" &&
    arg != "--diagnostic-format=human"
  })
}

///|
async fn locale_sources(
  input_dir : String,
) -> Array[@generator.LocaleSource] raise CliError {
  locale_sources_with_limit(input_dir, @generator.I18N_MAX_TOTAL_LOCALE_BYTES)
}

///|
async fn locale_sources_with_limit(
  input_dir : String,
  max_total_bytes : Int,
) -> Array[@generator.LocaleSource] raise CliError {
  let files = read_dir(input_dir)
  files.sort_by((left, right) => left.lexical_compare(right))
  let sources : Array[@generator.LocaleSource] = []
  let mut total_bytes = 0
  for file in files {
    if file.has_suffix(".json") &&
      file != "config.json" &&
      file != "schema.json" &&
      file != ".lampclaw-i18n.json" {
      if sources.length() >= @generator.I18N_MAX_LOCALES {
        cli_fail(
          "locale directory exceeds the \{@generator.I18N_MAX_LOCALES}-file limit: \{input_dir}",
        )
      }
      let source = read_file_limited(
        path_join(input_dir, file),
        @runtime.CATALOG_MAX_SOURCE_BYTES,
      )
      let source_bytes = @utf8.encode(source).length()
      if source_bytes > max_total_bytes ||
        total_bytes > max_total_bytes - source_bytes {
        cli_fail(
          "locale directory exceeds the \{max_total_bytes}-byte aggregate UTF-8 limit: \{input_dir}",
        )
      }
      total_bytes = total_bytes + source_bytes
      sources.push({
        code: file[:file.length() - ".json".length()].to_owned(),
        source,
      })
    }
  }
  sources
}

///|
fn text_file_content(source : String) -> String {
  if source.has_suffix("\n") {
    source
  } else {
    source + "\n"
  }
}

///|
async fn check_file(
  path : String,
  expected : String,
  kind : String,
) -> Unit raise CliError {
  if !file_exists(path) || read_file(path) != expected {
    cli_fail("i18n \{kind} is out of date: \{path}")
  }
}

///|
async fn check_catalog_set(
  catalog_dir : String,
  expected : Array[String],
) -> Unit raise CliError {
  for file in read_dir(catalog_dir) {
    if file.has_suffix(".json") &&
      file != ".lampclaw-i18n.json" &&
      !expected.contains(file) {
      cli_fail("unexpected i18n catalog: \{path_join(catalog_dir, file)}")
    }
  }
}

///|
async fn check_exact_generated_set(
  directory : String,
  expected : Array[String],
  kind : String,
) -> Unit raise CliError {
  if !file_exists(directory) {
    cli_fail("i18n \{kind} directory is missing: \{directory}")
  }
  let actual = read_dir(directory)
  actual.sort_by((left, right) => left.lexical_compare(right))
  let sorted_expected = expected.copy()
  sorted_expected.sort_by((left, right) => left.lexical_compare(right))
  if actual != sorted_expected {
    cli_fail("i18n \{kind} file set is out of date: \{directory}")
  }
}

///|
async fn load_artifacts(
  config_file : String,
  schema_file : String,
  locale_dir : String,
  enforce_coverage : Bool,
) -> @generator.Artifacts raise CliError {
  let sources = locale_sources(locale_dir)
  if sources.is_empty() {
    cli_fail("no locale JSON files found in: \{locale_dir}")
  }
  let config_source = read_file_limited(
    config_file,
    @runtime.CATALOG_MAX_SOURCE_BYTES,
  )
  let schema_source = read_file_limited(
    schema_file,
    @runtime.CATALOG_MAX_SOURCE_BYTES,
  )
  match
    @generator.generate_with_diagnostics(
      config_source,
      schema_source,
      sources,
      config_path=config_file,
      schema_path=schema_file,
      locale_directory=locale_dir,
      enforce_coverage~,
    ) {
    Ok(value) => value
    Err(diagnostics) => cli_fail(diagnostic_envelope(diagnostics[0]))
  }
}

///|
fn sha256_text(source : String) -> String {
  @crypto.bytes_to_hex_string(@crypto.sha256(@utf8.encode(source)))
}

///|
fn manifest_path(root : String, path : String) -> String {
  let relative = as_path(resolved_path(path)).relative(base=as_path(root))
  let value = relative.to_string().replace_all(old="\\", new="/")
  if value.is_empty() {
    "."
  } else {
    value
  }
}

///|
fn manifest_file(kind : String, path : String, source : String) -> Json {
  Json::object({
    "kind": Json::string(kind),
    "path": Json::string(path),
    "sha256": Json::string(sha256_text(source)),
    "bytes": Json::number(@utf8.encode(source).length().to_double()),
  })
}

///|
async fn generation_manifest(
  config_file : String,
  schema_file : String,
  locale_dir : String,
  package_dir : String,
  catalog_dir : String,
  code : String,
  package_manifest : String,
  catalogs : Array[(String, String)],
  catalog_chunks : Array[@generator.CatalogChunkArtifact],
  deployment_manifest : String,
  contract_hash : String,
  message_profile : String,
) -> String raise CliError {
  let root = path_dirname(resolved_path(config_file))
  let inputs : Array[Json] = [
    manifest_file(
      "config",
      manifest_path(root, config_file),
      read_file_limited(config_file, @runtime.CATALOG_MAX_SOURCE_BYTES),
    ),
    manifest_file(
      "schema",
      manifest_path(root, schema_file),
      read_file_limited(schema_file, @runtime.CATALOG_MAX_SOURCE_BYTES),
    ),
  ]
  for catalog in catalogs {
    let locale_file = path_join(locale_dir, catalog.0 + ".json")
    inputs.push(
      manifest_file(
        "locale",
        manifest_path(root, locale_file),
        read_file_limited(locale_file, @runtime.CATALOG_MAX_SOURCE_BYTES),
      ),
    )
  }
  let outputs : Array[Json] = [
    manifest_file(
      "moonbit",
      manifest_path(root, path_join(package_dir, "generated.mbt")),
      code,
    ),
    manifest_file(
      "moon-package",
      manifest_path(root, path_join(package_dir, "moon.pkg")),
      package_manifest,
    ),
  ]
  outputs.push(
    manifest_file(
      "deployment-manifest",
      manifest_path(root, path_join(catalog_dir, "manifest.json")),
      deployment_manifest,
    ),
  )
  for catalog in catalog_chunks {
    outputs.push(
      manifest_file(
        "catalog-chunk",
        manifest_path(root, path_join(catalog_dir, catalog.path)),
        catalog.source,
      ),
    )
  }
  Json::object({
    "manifestVersion": Json::number(1.0),
    "generator": Json::string("lampclaw/i18n"),
    "generatorVersion": Json::string(CLI_VERSION),
    "profile": Json::string(message_profile),
    "contractHash": Json::string(contract_hash),
    "inputs": Json::array(inputs),
    "outputs": Json::array(outputs),
  }).stringify(indent=2) +
  "\n"
}

///|
async fn run_generate(
  args : Array[String],
  check_mode : Bool,
  diagnostic_json? : Bool = false,
) -> Unit raise CliError {
  let allow_partial = args.contains("--allow-partial")
  let values = without_allow_partial(args)
  if values.length() != 6 {
    cli_fail(usage())
  }
  let artifacts = load_artifacts(
    values[1],
    values[2],
    values[3],
    !allow_partial,
  )
  let code = format_moonbit_source(artifacts.code)
  let manifest = text_file_content(artifacts.package_manifest)
  let package_dir = values[4]
  let generated_manifest = generation_manifest(
    values[1],
    values[2],
    values[3],
    package_dir,
    values[5],
    code,
    manifest,
    artifacts.catalogs,
    artifacts.catalog_chunks,
    artifacts.deployment_manifest,
    artifacts.contract_hash,
    artifacts.message_profile,
  )
  if check_mode {
    check_file(
      path_join(package_dir, "generated.mbt"),
      code,
      "generated bindings",
    )
    check_file(
      path_join(package_dir, "moon.pkg"),
      manifest,
      "generated package manifest",
    )
    let package_files = [
      "generated.mbt", "moon.pkg", "generation-manifest.json",
    ]
    check_file(
      path_join(package_dir, ".lampclaw-i18n.json"),
      ownership_manifest("package", package_files),
      "package ownership manifest",
    )
    check_file(
      path_join(package_dir, "generation-manifest.json"),
      generated_manifest,
      "generation manifest",
    )
    let expected_package_files = [
      ".lampclaw-i18n.json", "generated.mbt", "generation-manifest.json", "moon.pkg",
    ]
    if file_exists(path_join(package_dir, "pkg.generated.mbti")) {
      expected_package_files.push("pkg.generated.mbti")
    }
    check_exact_generated_set(
      package_dir, expected_package_files, "generated package",
    )
    check_file(
      path_join(values[5], "manifest.json"),
      artifacts.deployment_manifest,
      "deployment manifest",
    )
    for catalog in artifacts.catalog_chunks {
      check_file(
        path_join(values[5], catalog.path),
        catalog.source,
        "catalog chunk",
      )
    }
    let catalog_files : Array[String] = ["manifest.json"]
    for catalog in artifacts.catalog_chunks {
      catalog_files.push(catalog.path)
    }
    check_catalog_set(values[5], catalog_files)
    check_file(
      path_join(values[5], ".lampclaw-i18n.json"),
      ownership_manifest("catalogs", catalog_files),
      "catalog ownership manifest",
    )
    let expected_catalog_files = catalog_files.copy()
    expected_catalog_files.push(".lampclaw-i18n.json")
    check_exact_generated_set(values[5], expected_catalog_files, "catalog")
  } else {
    let catalog_names : Array[String] = ["manifest.json"]
    let catalog_contents : Array[String] = [artifacts.deployment_manifest]
    for catalog in artifacts.catalog_chunks {
      catalog_names.push(catalog.path)
      catalog_contents.push(catalog.source)
    }
    write_generated_transaction(
      package_dir,
      values[5],
      code,
      manifest,
      catalog_names,
      catalog_contents,
      generation_manifest=generated_manifest,
    )
  }
  write_artifact_diagnostics(artifacts.diagnostics, diagnostic_json)
  println(artifacts.coverage_report)
}

///|
async fn run_coverage(
  args : Array[String],
  diagnostic_json? : Bool = false,
) -> Unit raise CliError {
  if args.length() != 4 {
    cli_fail(usage())
  }
  let artifacts = load_artifacts(args[1], args[2], args[3], false)
  write_artifact_diagnostics(artifacts.diagnostics, diagnostic_json)
  println(artifacts.coverage_report)
}

///|
async fn run_command(
  args : Array[String],
  diagnostic_json? : Bool = false,
) -> Unit raise CliError {
  if args.is_empty() {
    cli_fail(usage())
  }
  match args[0] {
    "--help" | "-h" | "help" => println(usage())
    "--version" | "-V" => println("moon-i18n \{CLI_VERSION}")
    "scaffold" => run_scaffold(args)
    "generate" => run_generate(args, false, diagnostic_json~)
    "check" => run_generate(args, true, diagnostic_json~)
    "coverage" => run_coverage(args, diagnostic_json~)
    "pseudo" => run_pseudo(args)
    "export-xliff" => run_export_xliff(args)
    "import-xliff" => run_import_xliff(args)
    "import-i18next" => run_import_i18next(args)
    "import-arb" => run_import_arb(args)
    _ => cli_fail(usage())
  }
}

///|
async fn write_artifact_diagnostics(
  diagnostics : Array[@generator.Diagnostic],
  json : Bool,
) -> Unit raise CliError {
  for diagnostic in diagnostics {
    let rendered = if json {
      diagnostic.to_json_string()
    } else {
      diagnostic.to_human_string()
    }
    try @stdio.stderr.write(rendered + "\n") catch {
      error => cli_fail("cannot write i18n diagnostic: \{error}")
    } noraise {
      _ => ()
    }
  }
}

///|
fn diagnostic_json_enabled(args : Array[String]) -> Bool {
  args.contains("--diagnostic-format=json")
}

///|
fn without_diagnostic_format(args : Array[String]) -> Array[String] {
  args.filter(arg => {
    arg != "--diagnostic-format=json" && arg != "--diagnostic-format=human"
  })
}

///|
fn cli_diagnostic(
  message : String,
  args : Array[String],
) -> @generator.Diagnostic {
  let values = without_diagnostic_format(args)
  let path = if values.length() > 1 { values[1] } else { "<command>" }
  {
    code: "I18N0001",
    severity: Error,
    message,
    path,
    span: {
      start: { byte_offset: 0, line: 1, column: 1 },
      end: { byte_offset: 0, line: 1, column: 1 },
    },
  }
}

///|
fn render_cli_error(message : String, args : Array[String]) -> String {
  let json = diagnostic_json_enabled(args)
  if message.has_prefix(DIAGNOSTIC_ENVELOPE) {
    let body = message[DIAGNOSTIC_ENVELOPE.length():].to_owned()
    let pieces : Array[String] = body
      .split(DIAGNOSTIC_HUMAN_SEPARATOR)
      .map(piece => piece.to_owned())
      .collect()
    if pieces.length() == 2 {
      return if json { pieces[0] } else { pieces[1] }
    }
  }
  let diagnostic = cli_diagnostic(message, args)
  if json {
    diagnostic.to_json_string()
  } else {
    diagnostic.to_human_string()
  }
}

///|
fn is_generated_content(source : String) -> Bool {
  source.has_prefix(
    "///|\n/// Generated by lampclaw/i18n. Do not edit by hand.",
  ) ||
  source.has_prefix("/// Generated by lampclaw/i18n. Do not edit by hand.") ||
  source.has_prefix("// Generated by lampclaw/i18n. Do not edit by hand.")
}

///|
async fn main {
  let args = user_args(@env.args())
  let json = diagnostic_json_enabled(args)
  run_command(without_diagnostic_format(args), diagnostic_json=json) catch {
    CommandFailed(message) => die(render_cli_error(message, args))
  }
}
