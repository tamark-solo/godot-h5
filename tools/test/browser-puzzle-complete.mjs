// tools/test/browser-puzzle-complete.mjs
// H02 — Hoan thanh man 1 cua puzzle, xac minh bang CONSOLE LOG cua game.
//
// BAI HOC QUAN TRONG (da tra gia):
//   Ban dau test DOAN toa do manh/o theo thiet ke 720x1280. Sai.
//   Voi stretch mode 'canvas_items' + aspect 'expand', viewport game RONG HON
//   720 khi canvas browser rong hon ty le thiet ke (canvas 764x485 -> viewport
//   ~2016x1280). Doan toa do la sai phuong phap.
//
//   => Test nay DOC toa do THAT tu log cua game:
//        [PUZZLE] ready level=1 total=3 viewport=WxH
//        [PUZZLE] piece idx=I at=X,Y target=TX,TY
//      roi keo tu (X,Y) -> (TX,TY).
//
// usage: node browser-puzzle-complete.mjs <url> [cdpPort] [shotDir]

import { writeFileSync, mkdirSync } from 'node:fs';

const url = process.argv[2];
const cdpPort = parseInt(process.argv[3] || '9222', 10);
const shotDir = process.argv[4] || 'docs/reports/img';
if (!url) { console.error('usage: node browser-puzzle-complete.mjs <url> [cdpPort] [shotDir]'); process.exit(2); }

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

async function browserWsUrl() {
  for (let i = 0; i < 40; i++) {
    try {
      const r = await fetch(`http://127.0.0.1:${cdpPort}/json/version`);
      const j = await r.json();
      if (j.webSocketDebuggerUrl) return j.webSocketDebuggerUrl;
    } catch {}
    await sleep(500);
  }
  throw new Error('Khong ket noi duoc Chrome CDP');
}

class CDP {
  constructor(ws) {
    this.ws = ws; this.seq = 0; this.pending = new Map(); this.events = [];
    ws.addEventListener('message', (ev) => {
      let m; try { m = JSON.parse(ev.data); } catch { return; }
      if (m.id && this.pending.has(m.id)) {
        const p = this.pending.get(m.id); this.pending.delete(m.id);
        m.error ? p.reject(new Error(JSON.stringify(m.error))) : p.resolve(m.result);
      } else if (m.method) this.events.push(m);
    });
  }
  send(method, params = {}, sessionId) {
    const id = ++this.seq;
    const pl = { id, method, params };
    if (sessionId) pl.sessionId = sessionId;
    return new Promise((res, rej) => {
      this.pending.set(id, { resolve: res, reject: rej });
      this.ws.send(JSON.stringify(pl));
      setTimeout(() => { if (this.pending.has(id)) { this.pending.delete(id); rej(new Error('CDP timeout ' + method)); } }, 90000);
    });
  }
}

const ws = new WebSocket(await browserWsUrl());
await new Promise((res, rej) => { ws.addEventListener('open', res); ws.addEventListener('error', rej); });
const cdp = new CDP(ws);
const { targetId } = await cdp.send('Target.createTarget', { url: 'about:blank' });
const { sessionId } = await cdp.send('Target.attachToTarget', { targetId, flatten: true });
await cdp.send('Page.enable', {}, sessionId);
await cdp.send('Runtime.enable', {}, sessionId);
await cdp.send('Emulation.setDeviceMetricsOverride', { width: 720, height: 1280, deviceScaleFactor: 1, mobile: false }, sessionId);

const shot = async (n) => {
  try { const s = await cdp.send('Page.captureScreenshot', { format: 'png' }, sessionId);
    mkdirSync(shotDir, { recursive: true }); writeFileSync(`${shotDir}/${n}.png`, Buffer.from(s.data, 'base64')); } catch {}
};

const gameLogs = () => cdp.events
  .filter(e => e.method === 'Runtime.consoleAPICalled' && e.sessionId === sessionId)
  .map(e => (e.params.args || []).map(a => a.value ?? a.description ?? '').join(' '))
  .filter(s => s.includes('[PUZZLE]'));

async function click(x, y) {
  await cdp.send('Input.dispatchMouseEvent', { type: 'mouseMoved', x, y, buttons: 0 }, sessionId);
  await sleep(120);
  await cdp.send('Input.dispatchMouseEvent', { type: 'mousePressed', x, y, button: 'left', buttons: 1, clickCount: 1 }, sessionId);
  await sleep(140);
  await cdp.send('Input.dispatchMouseEvent', { type: 'mouseReleased', x, y, button: 'left', buttons: 0, clickCount: 1 }, sessionId);
}

// Keo va XAC MINH bang log "begin_drag" cua chinh manh do
async function dragPiece(from, to, idx, steps = 20) {
  const before = gameLogs().filter(s => s.includes('begin_drag idx=' + idx)).length;
  for (let attempt = 1; attempt <= 4; attempt++) {
    await cdp.send('Input.dispatchMouseEvent', { type: 'mouseMoved', x: from.x, y: from.y, buttons: 0 }, sessionId);
    await sleep(250);
    await cdp.send('Input.dispatchMouseEvent', { type: 'mousePressed', x: from.x, y: from.y, button: 'left', buttons: 1, clickCount: 1 }, sessionId);
    await sleep(300);
    for (let i = 1; i <= steps; i++) {
      const t = i / steps;
      await cdp.send('Input.dispatchMouseEvent', { type: 'mouseMoved',
        x: from.x + (to.x - from.x) * t, y: from.y + (to.y - from.y) * t, button: 'left', buttons: 1 }, sessionId);
      await sleep(35);
    }
    await sleep(300);
    await cdp.send('Input.dispatchMouseEvent', { type: 'mouseReleased', x: to.x, y: to.y, button: 'left', buttons: 0, clickCount: 1 }, sessionId);
    await sleep(900);
    const now = gameLogs().filter(s => s.includes('begin_drag idx=' + idx)).length;
    if (now > before) return true;
    await sleep(400);
  }
  return false;
}

const results = [];
const log = (n, p, d) => { results.push({ n, p }); console.log((p ? '  [PASS] ' : '  [FAIL] ') + n + (d ? ' — ' + d : '')); };

console.log('=== H02: PUZZLE COMPLETION TEST ===');
console.log('url: ' + url);
console.log('');
await cdp.send('Page.navigate', { url }, sessionId);
await sleep(24000);
await shot('h02c-1-menu');

await click(360, 1150);
await sleep(1000);
const ov = await cdp.send('Runtime.evaluate', {
  expression: "!document.getElementById('audio-unlock').classList.contains('visible')", returnByValue: true }, sessionId);
log('Overlay audio da an', ov.result.value === true);

// Vao Man 1 — toa do nut lay tu layout menu (HBox center, nut 1)
await click(150, 515);
await sleep(4000);
await shot('h02c-2-board');

const readyLog = gameLogs().find(s => s.includes('ready'));
log('Vao duoc man choi', !!readyLog, readyLog || '(khong co)');

// DOC toa do THAT tu game
const pieceLogs = gameLogs().filter(s => s.includes('piece idx='));
const pieces = [];
for (const l of pieceLogs) {
  const m = l.match(/piece idx=(\d+) at=(-?\d+),(-?\d+) target=(-?\d+),(-?\d+)/);
  if (m) pieces.push({ idx: +m[1], x: +m[2], y: +m[3], tx: +m[4], ty: +m[5] });
}
console.log('  game bao ' + pieces.length + ' manh:');
for (const p of pieces) console.log('    idx=' + p.idx + '  (' + p.x + ',' + p.y + ') -> (' + p.tx + ',' + p.ty + ')');

log('Game bao du so manh', pieces.length >= 3, pieces.length + ' manh');

console.log('  --- keo tung manh theo toa do THAT ---');
let okCount = 0;
for (const p of pieces) {
  const ok = await dragPiece({ x: p.x, y: p.y }, { x: p.tx, y: p.ty }, p.idx);
  console.log('    idx=' + p.idx + ': ' + (ok ? 'OK' : 'THAT BAI'));
  if (ok) okCount++;
}
await sleep(3000);
await shot('h02c-5-result');

const placed = gameLogs().filter(s => s.includes('placed'));
const finished = gameLogs().filter(s => s.includes('finished'));
console.log('');
console.log('  --- log cuoi tu game ---');
for (const l of gameLogs().slice(-8)) console.log('    ' + l);

const correctCount = placed.filter(s => s.includes('correct=true')).length;
log('Keo duoc ' + pieces.length + ' manh', okCount === pieces.length, okCount + '/' + pieces.length);
log('Manh dat DUNG cho', correctCount >= 3, correctCount + '/3');
log('Man 1 hoan thanh', finished.length > 0, finished[0] || '(khong co)');

const errs = cdp.events.filter(e => e.method === 'Runtime.exceptionThrown' && e.sessionId === sessionId);
log('Khong exception', errs.length === 0, errs.length ? errs[0].params.exceptionDetails.text : '');

console.log('');
const failed = results.filter(r => !r.p);
console.log('tong: ' + results.length + ', that bai: ' + failed.length);
console.log(failed.length === 0 ? 'RESULT: PASS' : 'RESULT: FAIL');
process.exit(failed.length === 0 ? 0 : 1);
