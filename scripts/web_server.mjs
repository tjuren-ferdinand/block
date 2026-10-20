/**
 * Minimal static server for the Godot Web export.
 * Godot 4 web builds REQUIRE cross-origin isolation headers
 * (SharedArrayBuffer) — this server sets them, plus correct MIME types.
 *
 *   node scripts/web_server.mjs [port] [dir]
 */
import { createServer } from "node:http";
import { readFile, stat } from "node:fs/promises";
import { join, extname, resolve } from "node:path";

const port = Number(process.argv[2] ?? 8081);
const root = resolve(process.argv[3] ?? new URL("../client/exports/web", import.meta.url).pathname.replace(/^\/([A-Za-z]:)/, "$1"));

const MIME = {
  ".html": "text/html; charset=utf-8",
  ".js": "application/javascript",
  ".wasm": "application/wasm",
  ".pck": "application/octet-stream",
  ".png": "image/png",
  ".svg": "image/svg+xml",
  ".ico": "image/x-icon",
  ".json": "application/json",
  ".css": "text/css",
  ".audio.worklet.js": "application/javascript",
  ".worker.js": "application/javascript",
};

const server = createServer(async (req, res) => {
  try {
    let path = decodeURIComponent(new URL(req.url, "http://x").pathname);
    if (path.endsWith("/")) path += "index.html";
    const file = join(root, path);
    if (!file.startsWith(root)) {
      res.writeHead(403).end();
      return;
    }
    const st = await stat(file).catch(() => null);
    const target = st?.isDirectory() ? join(file, "index.html") : file;
    const data = await readFile(target);
    res.writeHead(200, {
      "content-type": MIME[extname(target)] ?? "application/octet-stream",
      "cross-origin-opener-policy": "same-origin",
      "cross-origin-embedder-policy": "require-corp",
      "cache-control": "no-cache",
    });
    res.end(data);
  } catch {
    res.writeHead(404).end("not found");
  }
});

server.listen(port, "0.0.0.0", () => {
  console.log(`Web client served at http://localhost:${port}`);
  console.log(`Serving: ${root}`);
});
