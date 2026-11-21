#!/usr/bin/env node
// Static server for the mockup. No dependencies.
//   node design/mockup-v8/serve.mjs [port]        default 8800, loopback only
// Share it on the tailnet with:  tailscale serve --bg --https=8800 http://127.0.0.1:8800
import { createServer } from 'node:http'
import { readFile } from 'node:fs/promises'
import { dirname, extname, join, normalize, sep } from 'node:path'
import { fileURLToPath } from 'node:url'

const root = dirname(fileURLToPath(import.meta.url))
const port = Number(process.argv[2] ?? 8800)
const types = {
  '.html': 'text/html; charset=utf-8', '.css': 'text/css; charset=utf-8', '.js': 'text/javascript; charset=utf-8',
  '.mjs': 'text/javascript; charset=utf-8', '.woff2': 'font/woff2', '.png': 'image/png', '.svg': 'image/svg+xml', '.md': 'text/plain; charset=utf-8', '.ttf': 'font/ttf',
}

createServer(async (req, res) => {
  const path = decodeURIComponent(new URL(req.url, 'http://x').pathname)
  const file = normalize(join(root, path.endsWith('/') ? path + 'index.html' : path))
  if (file !== root && !file.startsWith(root + sep)) { res.writeHead(403).end(); return }
  try {
    const body = await readFile(file)
    // no-store: a mockup under review must never be served stale
    res.writeHead(200, { 'content-type': types[extname(file)] ?? 'application/octet-stream', 'cache-control': 'no-store' }).end(body)
  } catch {
    res.writeHead(404, { 'content-type': 'text/plain' }).end('not found')
  }
}).listen(port, '127.0.0.1', () => console.log(`mockup on http://127.0.0.1:${port}/`))
