import { createReadStream } from "node:fs";
import { stat } from "node:fs/promises";
import { createServer } from "node:http";
import { extname, resolve, sep } from "node:path";

const root = resolve(process.argv[2] ?? "");
const port = Number.parseInt(process.argv[3] ?? "4173", 10);

if (!Number.isSafeInteger(port) || port < 1 || port > 65_535) {
  throw new Error(`invalid port: ${process.argv[3] ?? ""}`);
}

const contentTypes = new Map([
  [".css", "text/css; charset=utf-8"],
  [".html", "text/html; charset=utf-8"],
  [".js", "text/javascript; charset=utf-8"],
  [".json", "application/json; charset=utf-8"],
  [".map", "application/json; charset=utf-8"],
  [".wasm", "application/wasm"],
]);

function resolveRequest(url) {
  const pathname = decodeURIComponent(new URL(url, "http://localhost").pathname);
  const relative = pathname === "/" ? "index.html" : pathname.slice(1);
  const file = resolve(root, relative);
  if (file !== root && !file.startsWith(`${root}${sep}`)) {
    return null;
  }
  return file;
}

const server = createServer(async (request, response) => {
  let file;
  try {
    file = resolveRequest(request.url ?? "/");
  } catch {
    response.writeHead(400).end("Bad request");
    return;
  }
  if (file === null) {
    response.writeHead(403).end("Forbidden");
    return;
  }
  try {
    const metadata = await stat(file);
    if (!metadata.isFile()) throw new Error("not a file");
    response.writeHead(200, {
      "cache-control": "no-store",
      "content-length": metadata.size,
      "content-type": contentTypes.get(extname(file)) ?? "application/octet-stream",
    });
    createReadStream(file).pipe(response);
  } catch {
    response.writeHead(404).end("Not found");
  }
});

server.listen(port, "127.0.0.1", () => {
  process.stdout.write(`serving ${root} on http://127.0.0.1:${port}\n`);
});

for (const signal of ["SIGINT", "SIGTERM"]) {
  process.on(signal, () => server.close(() => process.exit(0)));
}
