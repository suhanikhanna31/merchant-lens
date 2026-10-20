// Dev server: serves this folder and proxies /api and /actuator/health to the
// Spring Boot API, so the browser stays same-origin and CORS never comes into it.
// Usage: API_URL=http://localhost:8080 PORT=3000 node server.mjs

import { createServer, request as httpRequest } from 'node:http';
import { readFile } from 'node:fs/promises';
import { extname, join, normalize, resolve, sep } from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = resolve(fileURLToPath(new URL('.', import.meta.url)));
const API = new URL(process.env.API_URL ?? 'http://localhost:8080');
const PORT = Number(process.env.PORT ?? 3000);
const PUBLIC = new Set(['/index.html', '/styles.css']);
const TYPES = { '.html': 'text/html; charset=utf-8', '.js': 'text/javascript; charset=utf-8', '.css': 'text/css; charset=utf-8' };

function proxy(req, res) {
  const upstream = httpRequest(
    { host: API.hostname, port: API.port, path: req.url, method: req.method, headers: { ...req.headers, host: API.host } },
    (up) => { res.writeHead(up.statusCode ?? 502, up.headers); up.pipe(res); },
  );
  upstream.on('error', () => { res.writeHead(502); res.end('API unreachable'); });
  req.pipe(upstream);
}

async function serveStatic(req, res) {
  const path = new URL(req.url, 'http://localhost').pathname;
  if (path === '/favicon.ico') { res.writeHead(204); return res.end(); }
  const rel = path === '/' ? '/index.html' : path;
  const allowed = PUBLIC.has(rel) || rel.startsWith('/src/');
  const file = normalize(join(ROOT, rel));
  if (!allowed || !file.startsWith(ROOT + sep)) { res.writeHead(404); return res.end('Not found'); }
  try {
    const data = await readFile(file);
    res.writeHead(200, { 'Content-Type': TYPES[extname(file)] ?? 'application/octet-stream', 'X-Content-Type-Options': 'nosniff', 'X-Frame-Options': 'DENY' });
    res.end(data);
  } catch {
    res.writeHead(404); res.end('Not found');
  }
}

createServer((req, res) => {
  if (req.url.startsWith('/api/') || req.url === '/actuator/health') return proxy(req, res);
  return serveStatic(req, res);
}).listen(PORT, () => console.log(`Dashboard on http://localhost:${PORT} -> API ${API.origin}`));
