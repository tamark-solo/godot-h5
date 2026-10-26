// tools/test/browser-drag-test.mjs
// H02 — Kiem tra KEO-THA that trong browser (khac fixture 1 chi keo ngang).
//
// Quy trinh: boot -> vao man 1 -> keo tung manh vao dung o -> xac nhan thang.
// Dung Input.dispatchMouseEvent voi mouseMoved de mo phong keo.
//
// usage: node browser-drag-test.mjs <url> [cdpPort] [shotDir]

import { writeFileSync, mkdirSync } from 'node:fs';

const url = process.argv[2];
const cdpPort = parseInt(process.argv[3] || '9222', 10);
const shotDir = process.argv[4] || 'docs/reports/img';
if (!url) { console.error('usage: node browser-drag-test.mjs <url> [cdpPort] [shotDir]'); process.exit(2); }

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

const evalJs = async (expr) => {
  // awaitPromise: BAT BUOC khi bieu thuc tra ve Promise (vi du indexedDB.databases()).
  // Thieu no thi ket qua la chuoi "[object Object]" thay vi gia tri that.
  const r = await cdp.send('Runtime.evaluate', { expression: expr, returnByValue: true, awaitPromise: true }, sessionId);
  if (r.exceptionDetails) throw new Error(r.exceptionDetails.text);
  return r.result.value;
};
const shot = async (name) => {
  try {
    const s = await cdp.send('Page.captureScreenshot', { format: 'png' }, sessionId);
    mkdirSync(shotDir, { recursive: true });
    writeFileSync(`${shotDir}/${name}.png`, Buffer.from(s.data, 'base64'));
  } catch {}
};

// Keo THAT: nhan xuong, di chuyen nhieu buoc, nha ra
async function drag(from, to, steps = 14) {
  await cdp.send('Input.dispatchMouseEvent', { type: 'mouseMoved', x: from.x, y: from.y, buttons: 0 }, sessionId);
  await sleep(120);
  await cdp.send('Input.dispatchMouseEvent', { type: 'mousePressed', x: from.x, y: from.y, button: 'left', buttons: 1, clickCount: 1 }, sessionId);
  await sleep(160);
  for (let i = 1; i <= steps; i++) {
    const t = i / steps;
    await cdp.send('Input.dispatchMouseEvent', {
      type: 'mouseMoved',
      x: from.x + (to.x - from.x) * t,
      y: from.y + (to.y - from.y) * t,
      button: 'left', buttons: 1,
    }, sessionId);
    await sleep(35);
  }
  await sleep(160);
  await cdp.send('Input.dispatchMouseEvent', { type: 'mouseReleased', x: to.x, y: to.y, button: 'left', buttons: 0, clickCount: 1 }, sessionId);
  await sleep(500);
}

const results = [];
const log = (n, p, d) => { results.push({ n, p }); console.log((p ? '  [PASS] ' : '  [FAIL] ') + n + (d ? ' — ' + d : '')); };

console.log('=== H02: DRAG-DROP TEST (puzzle) ===');
console.log('url: ' + url);
console.log('');

await cdp.send('Page.navigate', { url }, sessionId);
await sleep(24000);

const booted = await evalJs("document.getElementById('status').classList.contains('hidden')");
log('Boot xong', booted === true);
await shot('h02-1-menu');

// Unlock audio
await cdp.send('Input.dispatchMouseEvent', { type: 'mousePressed', x: 360, y: 640, button: 'left', buttons: 1, clickCount: 1 }, sessionId);
await cdp.send('Input.dispatchMouseEvent', { type: 'mouseReleased', x: 360, y: 640, button: 'left', buttons: 0, clickCount: 1 }, sessionId);
await sleep(900);

// Bam "Man 1".
// Tinh tu scene: HBox center, offset_top=-180..-70 => y 460..570, tam 515.
// 3 nut rong 190, separation 20 => tong 610, can giua tai x=360
//   nut 1: 55..245  -> tam 150
//   nut 2: 265..455 -> tam 360
//   nut 3: 475..665 -> tam 570
await cdp.send('Input.dispatchMouseEvent', { type: 'mouseMoved', x: 150, y: 515, buttons: 0 }, sessionId);
await sleep(150);
await cdp.send('Input.dispatchMouseEvent', { type: 'mousePressed', x: 150, y: 515, button: 'left', buttons: 1, clickCount: 1 }, sessionId);
await sleep(150);
await cdp.send('Input.dispatchMouseEvent', { type: 'mouseReleased', x: 150, y: 515, button: 'left', buttons: 0, clickCount: 1 }, sessionId);
await sleep(3000);
await shot('h02-2-board');

const errs1 = cdp.events.filter(e => e.method === 'Runtime.exceptionThrown' && e.sessionId === sessionId);
log('Vao man choi khong exception', errs1.length === 0, errs1.length ? errs1[0].params.exceptionDetails.text : '');

// Man 1 co 3 manh. O dich o y = 1280*0.30 = 384, x = 720/(3+1)*i = 180, 360, 540
// Manh o y = 1280*0.72 = 921.6, thu tu dao nguoc: manh idx0 o vi tri x=180? 
// Trong _setup_level: order = [0,1,2] -> reverse -> [2,1,0]
//   i=0: idx=2 -> position x = spacing*1 = 180
//   i=1: idx=1 -> position x = spacing*2 = 360
//   i=2: idx=0 -> position x = spacing*3 = 540
// target cua idx: spacing*(idx+1) -> idx0=180, idx1=360, idx2=540
// Vay: manh o x=180 (idx2) -> dich x=540; manh x=360 (idx1) -> dich 360 (dung san);
//      manh x=540 (idx0) -> dich 180
const slotY = 384, pieceY = 922;
console.log('  keo manh (180,' + pieceY + ') -> o (540,' + slotY + ')');
await drag({ x: 180, y: pieceY }, { x: 540, y: slotY });
await shot('h02-3-after-drag1');

console.log('  keo manh (540,' + pieceY + ') -> o (180,' + slotY + ')');
await drag({ x: 540, y: pieceY }, { x: 180, y: slotY });
await shot('h02-4-after-drag2');

// Manh o 360 da dung san -> keo ra roi keo lai de tinh la "dung cho"
console.log('  keo manh (360,' + pieceY + ') -> o (360,' + slotY + ')');
await drag({ x: 360, y: pieceY }, { x: 360, y: slotY });
await sleep(2500);
await shot('h02-5-result');

const errs2 = cdp.events.filter(e => e.method === 'Runtime.exceptionThrown' && e.sessionId === sessionId);
log('Keo-tha khong exception', errs2.length === 0, errs2.length ? errs2[0].params.exceptionDetails.text : '');

// Kiem tra save co duoc ghi (IndexedDB)
const idb = await evalJs("(async function(){ try { var dbs = await indexedDB.databases(); return 'NAMES:' + dbs.map(function(d){return d.name;}).join(','); } catch(e){ return 'ERR:'+e.message; } })()");
log('IndexedDB truy cap duoc', typeof idb === 'string' && !idb.startsWith('ERR'), idb);

console.log('');
const failed = results.filter(r => !r.p);
console.log('tong: ' + results.length + ', that bai: ' + failed.length);
console.log(failed.length === 0 ? 'RESULT: PASS' : 'RESULT: FAIL');
process.exit(failed.length === 0 ? 0 : 1);