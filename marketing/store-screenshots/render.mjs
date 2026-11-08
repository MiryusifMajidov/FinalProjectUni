// Renders store.html into separate PNGs with headless Chrome (DevTools
// protocol; Node's own fetch and WebSocket).
//   node render.mjs --w 1290 --h 2796 --out appstore
//   node render.mjs --w 1080 --h 1920 --out googleplay
//   node render.mjs --page feature.html --w 1024 --h 500 --n 1 --out googleplay --name feature-graphic
import { spawn } from 'node:child_process';
import { mkdirSync, writeFileSync, existsSync } from 'node:fs';
import { resolve, dirname } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));
const args = Object.fromEntries(process.argv.slice(2).reduce((acc, a, i, all) => {
  if (a.startsWith('--')) acc.push([a.slice(2), all[i + 1] && !all[i + 1].startsWith('--') ? all[i + 1] : true]);
  return acc;
}, []));
const W = +args.w, H = +args.h, page = args.page ?? 'store.html';
const out = resolve(here, args.out ?? 'out');
mkdirSync(out, { recursive: true });
const exe = ['C:/Program Files/Google/Chrome/Application/chrome.exe',
  'C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe'].find(existsSync);
const port = 9800 + Math.floor(Math.random() * 150);
const proc = spawn(exe, ['--headless=new', `--remote-debugging-port=${port}`,
  `--user-data-dir=${resolve(here, '..', '..', 'build', `chrome-store-${port}`)}`,
  '--hide-scrollbars', '--allow-file-access-from-files', '--force-device-scale-factor=1', 'about:blank'], { stdio: 'ignore' });
const sleep = ms => new Promise(r => setTimeout(r, ms));
let target;
for (let i = 0; i < 100 && !target; i++) {
  try { target = (await (await fetch(`http://127.0.0.1:${port}/json/list`)).json()).find(t => t.type === 'page'); }
  catch { await sleep(150); }
}
const ws = new WebSocket(target.webSocketDebuggerUrl);
await new Promise(r => { ws.onopen = r; });
let id = 1; const pend = new Map();
ws.onmessage = ev => { const m = JSON.parse(ev.data); if (m.id && pend.has(m.id)) { const p = pend.get(m.id); pend.delete(m.id); m.error ? p.rej(new Error(JSON.stringify(m.error))) : p.res(m.result); } };
const send = (method, params = {}) => new Promise((res, rej) => { const i = id++; pend.set(i, { res, rej }); ws.send(JSON.stringify({ id: i, method, params })); });
const evaluate = async e => (await send('Runtime.evaluate', { expression: e, awaitPromise: true, returnByValue: true })).result.value;

await send('Page.enable');
const url = pathToFileURL(resolve(here, page)).href + `?w=${W}&h=${H}` + (args.n ? `&n=${args.n}` : '');
await send('Page.navigate', { url });
for (let i = 0; i < 100; i++) { try { if (await evaluate('!!window.ready')) break; } catch {} await sleep(100); }
const info = await evaluate('window.ready');
const n = info.N;
await send('Emulation.setDeviceMetricsOverride', { width: W * n, height: H, deviceScaleFactor: 1, mobile: false });
await sleep(600);
for (let i = 0; i < n; i++) {
  const shot = await send('Page.captureScreenshot', { format: 'png', clip: { x: i * W, y: 0, width: W, height: H, scale: 1 } });
  const name = args.name ? `${args.name}.png` : `${String(i + 1).padStart(2, '0')}.png`;
  writeFileSync(resolve(out, name), Buffer.from(shot.data, 'base64'));
}
console.log(`wrote ${n} images (${W}x${H}) to ${out}`);
ws.close(); proc.kill();
