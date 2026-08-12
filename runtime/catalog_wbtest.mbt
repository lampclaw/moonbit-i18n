///|
test "generated catalog aggregate budget counts UTF-8 data and entries" {
  let (_, aggregate_error) = generated_entries_map(
    [
      CatalogEntry::{ id: "a", message: "界" },
      CatalogEntry::{ id: "b", message: "x" },
    ],
    2,
    5,
  )
  assert_eq(
    aggregate_error,
    Some("generated catalog exceeds the 5-byte aggregate UTF-8 data limit"),
  )
  let (_, count_error) = generated_entries_map(
    [
      CatalogEntry::{ id: "a", message: "" },
      CatalogEntry::{ id: "b", message: "" },
    ],
    1,
    10,
  )
  assert_eq(count_error, Some("catalog exceeds the 1-message limit"))
}
