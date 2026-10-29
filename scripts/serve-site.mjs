import { createServer } from 'node:http';
import { readFile, stat } from 'node:fs/promises';
import { resolve, sep, extname } from 'node:path';

const root = resolve('_site');
const types = { '.html': 'text/html; charset=utf-8', '.json': 'application/json', '.log': 'text/plain; charset=utf-8', '.png': 'image/png', '.txt': 'text/plain', '.xml': 'application/xml' };
createServer(async (request, response) => {
  try {
    const path = decodeURIComponent(new URL(request.url, 'http://localhost').pathname);
    let file = resolve(root, `.${path}`);
    if (file !== root && !file.startsWith(root + sep)) {
      response.writeHead(403).end();
      return;
    }
    if ((await stat(file)).isDirectory()) file = resolve(file, 'index.html');
    const body = await readFile(file);
    response.writeHead(200, { 'Content-Type': types[extname(file)] || 'application/octet-stream', 'Content-Length': body.length });
    response.end(body);
  } catch {
    response.writeHead(404).end('Not found');
  }
}).listen(4178, '127.0.0.1');
