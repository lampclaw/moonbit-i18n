# Production Web delivery

`lampclaw/i18n` 0.4 generates independently deployable catalog chunks while
leaving the canonical authoring files unchanged. A top-level schema message
group is a deployment namespace. Locale authors continue to edit one JSON file
per locale; they do not maintain chunk files or hashes.

## Generated layout

For locales `en-US` and `zh-CN` with namespaces `account` and `common`, the CLI
owns this complete output directory:

~~~text
public/i18n/
├── manifest.json
├── en-US--account.json
├── en-US--common.json
├── zh-CN--account.json
└── zh-CN--common.json
~~~

Each chunk remains catalog v2 and adds a `namespace` field. Every message ID in
that chunk must begin with the declared namespace. `manifest.json` records the
catalog version, profile, contract hash, fallback and embedded locales, plus
the path, UTF-8 byte count, SHA-256, message count, direction, locale, and
namespace of every chunk. Arrays and paths are emitted in deterministic order.

The generated facade exposes typed `CatalogNamespace` values. Installation is
data-only:

~~~moonbit nocheck
let i18n = @app_i18n.I18n::new()
match i18n.install_catalog_chunk_source(
  @app_i18n.ZhCN,
  @app_i18n.CatalogAccount,
  verified_source,
) {
  Ok(_) => ()
  Err(message) => println("chunk rejected: \{message}")
}

if i18n.has_catalog_namespace(
  @app_i18n.ZhCN,
  @app_i18n.CatalogAccount,
) {
  // The account route may now use its Chinese messages.
}
~~~

`has_catalog(locale)` becomes true only when every generated namespace is
installed. Applications that need only selected routes should use
`has_catalog_namespace`. A missing namespace or message continues through the
normal locale and fallback chains. A malformed, stale-contract,
wrong-profile, wrong-locale, or wrong-namespace chunk is rejected before it can
replace working data.

Whole-locale catalog v2 parsing and installation remain supported for
compatibility. New CLI output uses chunks and the deployment manifest.

## Application-owned loading recipe

The runtime deliberately contains no HTTP, storage, service-worker, or retry
policy. The application should fetch `manifest.json` with revalidation, select
only the namespaces needed by the current route, verify the exact response
bytes, decode UTF-8, and then pass the source to the generated facade.

This framework-neutral browser helper demonstrates the host side of that
boundary:

~~~javascript
const hex = bytes =>
  [...new Uint8Array(bytes)]
    .map(value => value.toString(16).padStart(2, "0"))
    .join("");

async function fetchVerifiedChunk(baseURL, entry, retry = true) {
  const response = await fetch(new URL(entry.path, baseURL), {
    cache: retry ? "default" : "reload",
  });
  if (!response.ok) throw new Error(`catalog HTTP ${response.status}`);
  const bytes = await response.arrayBuffer();
  if (bytes.byteLength !== entry.bytes) {
    if (retry) return fetchVerifiedChunk(baseURL, entry, false);
    throw new Error("catalog byte count mismatch");
  }
  const digest = hex(await crypto.subtle.digest("SHA-256", bytes));
  if (digest !== entry.sha256) {
    if (retry) return fetchVerifiedChunk(baseURL, entry, false);
    throw new Error("catalog SHA-256 mismatch");
  }
  return new TextDecoder("utf-8", { fatal: true }).decode(bytes);
}

async function loadRouteNamespaces(baseURL, locale, names, install) {
  const response = await fetch(new URL("manifest.json", baseURL), {
    cache: "no-cache",
  });
  if (!response.ok) throw new Error(`manifest HTTP ${response.status}`);
  const manifest = await response.json();
  const entries = names.map(name => {
    const entry = manifest.chunks.find(
      value => value.locale === locale && value.namespace === name,
    );
    if (!entry) throw new Error(`missing catalog chunk: ${locale}/${name}`);
    return entry;
  });
  const sources = await Promise.all(
    entries.map(entry => fetchVerifiedChunk(baseURL, entry)),
  );
  // `install` bridges to install_catalog_chunk_source. Commit the requested
  // locale only after every required call succeeds.
  entries.forEach((entry, index) => install(entry, sources[index]));
}
~~~

Recommended policy:

- keep the embedded fallback locale active while loading;
- revalidate the small manifest and let normal HTTP caching serve chunks;
- on an integrity mismatch, bypass the cache once and then fail visibly;
- install chunks independently, but commit a route or locale switch only after
  all namespaces required for that view succeed;
- retain already validated chunks across retries; and
- record request, integrity, and runtime rejection failures in application
  telemetry without logging translated user data.

The maintained Rabbita Todo example follows this ownership boundary. It embeds
English, requests the `common` and `todo_ui` Chinese chunks independently,
keeps English on failure, retries only missing chunks, and persists an explicit
locale choice only after both required namespaces validate.

## Published raw-byte budgets

The release gate reads the generated manifest, verifies every chunk hash, and
enforces these raw release limits:

| Artifact | Budget |
| --- | ---: |
| Browser release JavaScript | 256 KiB |
| Gzip-compressed browser JavaScript | 64 KiB |
| All chunks for embedded locales | 8 KiB |
| One dynamic namespace chunk | 64 KiB |
| Deployment manifest | 64 KiB |

The 0.4 reference application measures approximately 201 KiB JavaScript,
48 KiB gzip, 2.1 KiB of embedded-locale chunks, a 1.1 KiB largest dynamic
chunk, and a 2.1 KiB manifest. These budgets are regression ceilings, not
promises that every application bundle has the same size.

No framework-specific package is introduced in 0.4. The current evidence does
not yet show two independent consumers needing the same owned lifecycle
adapter and a dedicated maintainer.
