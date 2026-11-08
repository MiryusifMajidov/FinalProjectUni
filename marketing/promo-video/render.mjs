// Renders promo.html frame by frame with headless Chrome (DevTools protocol,
// no npm packages: Node's own fetch and WebSocket).
//
//   node render.mjs --out <dir> [--fps 60] [--from 0] [--to 40] [--times 1,5.5,12]
//                   [--scale 1] [--sfx sfx.json]
//
// --times renders just those moments (for checking a layout); otherwise every
// frame from --from to --to. --sfx writes the sound cues for music.py.
import { spawn } from 'node:child_process';
import { mkdirSync, writeFileSync, existsSync } from 'node:fs';
import { resolve, dirname } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));
const args = Object.fromEntries(process.argv.slice(2).reduce((acc, a, i, all) => {
  if (a.startsWith('--')) acc.push([a.slice(2), all[i + 1] && !all[i + 1].startsWith('--') ? all[i + 1] : true]);
  return acc;
}, []));
const fps = +(args.fps ?? 60);
const out = resolve(args.out ?? 'frames');
const scale = +(args.scale ?? 1);
mkdirSync(out, { recursive: true });

const chromes = [
  'C:/Program Files/Google/Chrome/Application/chrome.exe',
  'C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe',
];
const exe = chromes.find(existsSync);
const port = 9400 + Math.floor(Math.random() * 400);
const profile = resolve(out, '..', `chrome-profile-${port}`);
const proc = spawn(exe, [
  '--headless=new', `--remote-debugging-port=${port}`, `--user-data-dir=${profile}`,
  '--hide-scrollbars', '--allow-file-access-from-files', '--force-device-scale-factor=1',
  '--disable-background-timer-throttling', '--disable-renderer-backgrounding',
  '--window-size=1080,1920', 'about:blank',
], { stdio: 'ignore' });

const sleep = ms => new Promise(r => setTimeout(r, ms));
let target;
for (let i = 0; i < 100 && !target; i++) {
  try {
    const list = await (await fetch(`http://127.0.0.1:${port}/json/list`)).json();
    target = list.find(t => t.type === 'page');
  } catch { await sleep(150); }
}
if (!target) { proc.kill(); throw new Error('Chrome did not start'); }

const ws = new WebSocket(target.webSocketDebuggerUrl);
await new Promise((r, j) => { ws.onopen = r; ws.onerror = j; });
let nextId = 1;
const pending = new Map();
ws.onmessage = ev => {
  const msg = JSON.parse(ev.data);
  if (msg.id && pending.has(msg.id)) {
    const { res, rej } = pending.get(msg.id); pending.delete(msg.id);
    msg.error ? rej(new Error(JSON.stringify(msg.error))) : res(msg.result);
  }
};
const send = (method, params = {}) => new Promise((res, rej) => {
  const id = nextId++; pending.set(id, { res, rej });
  ws.send(JSON.stringify({ id, method, params }));
});
const evaluate = async expr => {
  const r = await send('Runtime.evaluate', { expression: expr, awaitPromise: true, returnByValue: true });
  if (r.exceptionDetails) throw new Error(JSON.stringify(r.exceptionDetails));
  return r.result.value;
};

await send('Page.enable');
await send('Runtime.enable');
await send('Emulation.setDeviceMetricsOverride', { width: 1080, height: 1920, deviceScaleFactor: 1, mobile: false });
await send('Page.navigate', { url: pathToFileURL(resolve(here, 'promo.html')).href });
for (let i = 0; i < 100; i++) {
  try { if (await evaluate('!!window.ready')) break; } catch {}
  await sleep(100);
}
await evaluate('window.ready');
await sleep(300);

if (args.sfx) {
  writeFileSync(resolve(args.sfx), await evaluate('JSON.stringify(window.SFX)'));
  console.log('cues written to', args.sfx);
}

const times = args.times
  ? String(args.times).split(',').map(Number)
  : (() => {
      const from = +(args.from ?? 0), to = +(args.to ?? 40), list = [];
      for (let f = Math.round(from * fps); f < Math.round(to * fps); f++) list.push(f / fps);
      return list;
    })();

const t0 = Date.now();
for (let i = 0; i < times.length; i++) {
  const t = times[i];
  await evaluate(`render(${t}); new Promise(r => requestAnimationFrame(() => requestAnimationFrame(r)))`);
  const shot = await send('Page.captureScreenshot', {
    format: 'jpeg', quality: 94,
    clip: { x: 0, y: 0, width: 1080, height: 1920, scale },
  });
  const name = args.times ? `t_${t.toFixed(2)}.jpg` : `f${String(Math.round(t * fps)).padStart(5, '0')}.jpg`;
  writeFileSync(resolve(out, name), Buffer.from(shot.data, 'base64'));
  if (i % 120 === 0) console.log(`${i}/${times.length} frames, ${((Date.now() - t0) / 1000).toFixed(0)} s`);
}
console.log(`done: ${times.length} frames in ${((Date.now() - t0) / 1000).toFixed(0)} s`);
ws.close();
proc.kill();
