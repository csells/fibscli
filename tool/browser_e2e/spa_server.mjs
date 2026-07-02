import { createReadStream, existsSync, statSync } from 'node:fs';
import { createServer } from 'node:http';
import { extname, join, normalize, resolve, sep } from 'node:path';

const port = Number(process.argv[2] ?? 18088);
const root = resolve(process.argv[3] ?? 'build/web');
const indexPath = join(root, 'index.html');

const contentTypes = new Map([
  ['.css', 'text/css; charset=utf-8'],
  ['.html', 'text/html; charset=utf-8'],
  ['.ico', 'image/x-icon'],
  ['.js', 'application/javascript; charset=utf-8'],
  ['.json', 'application/json; charset=utf-8'],
  ['.otf', 'font/otf'],
  ['.png', 'image/png'],
  ['.ttf', 'font/ttf'],
  ['.wasm', 'application/wasm'],
]);

const fileFor = (requestUrl) => {
  const url = new URL(requestUrl, 'http://localhost');
  const requested = normalize(decodeURIComponent(url.pathname));
  const relative = requested === sep ? 'index.html' : requested.slice(1);
  const candidate = resolve(root, relative);
  if (!candidate.startsWith(root + sep) && candidate !== root) {
    return indexPath;
  }
  if (existsSync(candidate) && statSync(candidate).isFile()) return candidate;
  return indexPath;
};

createServer((req, res) => {
  const file = fileFor(req.url ?? '/');
  res.setHeader(
    'Content-Type',
    contentTypes.get(extname(file)) ?? 'application/octet-stream',
  );
  createReadStream(file)
    .on('error', () => {
      res.writeHead(404);
      res.end('not found');
    })
    .pipe(res);
}).listen(port, '127.0.0.1', () => {
  console.log(`serving ${root} at http://127.0.0.1:${port}`);
});
