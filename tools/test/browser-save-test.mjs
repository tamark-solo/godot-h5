// tools/test/browser-save-test.mjs
// D06/G08 — Kiem tra save TON TAI qua reload (yeu cau cot loi).
// Quy trinh: boot -> choi -> ket thuc (de commit save) -> RELOAD -> kiem tra diem cao con.
// Khong the doc text trong canvas, nen dung anh chup + kiem tra IndexedDB /userfs.

import { writeFileSync, mkdirSync } from 'node:fs';

const url = process.argv[2];
const cdpPort = parseInt(process.argv[3] || '9222', 10);
const shotDir = process.argv[4] || 'docs/reports/img';
if (!url) { console.error('usage: node browser-save-test.mjs <url> [cdpPort] [shotDir]'); process.exit(2); }

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
const click = async (x, y) => {
  for (const type of ['mousePressed', 'mouseReleased']) {
    await cdp.send('Input.dispatchMouseEvent', { type, x, y, button: 'left', clickCount: 1 }, sessionId);
    await sleep(60);
  }
};

const results = [];
const log = (n, p, d) => { results.push({ n, p }); console.log((p ? '  [PASS] ' : '  [FAIL] ') + n + (d ? ' — ' + d : '')); };

console.log('=== BROWSER SAVE PERSISTENCE TEST ===');
console.log('url: ' + url);
console.log('');

// ---------- LAN 1: choi cho den khi ket thuc de commit save ----------
console.log('--- LAN 1: boot + choi ---');
await cdp.send('Page.navigate', { url }, sessionId);
await sleep(22000);

const booted1 = await evalJs("document.getElementById('status').classList.contains('hidden')");
log('Lan 1: boot xong', booted1 === true);

// unlock audio
await click(360, 640);
await sleep(800);

// bam CHOI (y ~ 760/1280)
await click(360, 760);
await sleep(2000);
await shot('save-1-playing');

// Cho game ket thuc (bo lo 3 sao hoac het 45s). Cho toi da 60s.
console.log('  ... cho game ket thuc (toi da 60s)');
let finished = false;
for (let i = 0; i < 30; i++) {
  await sleep(2000);
  // Ket thuc khi khong con HUD "Bỏ lỡ" — doan qua viec canvas doi. Thay vao do
  // cu cho du lau roi kiem tra IndexedDB.
  if (i === 14) { finished = true; break; }
}
await shot('save-2-result');

// Kiem tra IndexedDB co du lieu save khong
const idbInfo = await evalJs(`(async function(){
  try {
    var dbs = await indexedDB.databases();
    var names = dbs.map(function(d){ return d.name; });
    return JSON.stringify({ names: names });
  } catch(e) { return JSON.stringify({ err: e.message }); }
})()`);
console.log('  IndexedDB: ' + idbInfo);

// ---------- RELOAD ----------
console.log('');
console.log('--- RELOAD trang ---');
await cdp.send('Page.reload', {}, sessionId);
await sleep(22000);

const booted2 = await evalJs("document.getElementById('status').classList.contains('hidden')");
log('Sau reload: boot xong', booted2 === true);

await click(360, 640); // unlock audio
await sleep(1000);
await shot('save-3-after-reload-menu');

// Kiem tra /userfs con du lieu sau reload khong (day la bang chung save ton tai)
const userfs = await evalJs(`(async function(){
  try {
    var db = await new Promise(function(res, rej){
      var r = indexedDB.open('/userfs');
      r.onsuccess = function(){ res(r.result); };
      r.onerror = function(){ rej(r.error); };
    });
    var stores = Array.from(db.objectStoreNames);
    if (stores.length === 0) return JSON.stringify({ stores: [], note: 'khong co object store' });
    var tx = db.transaction(stores, 'readonly');
    var st = tx.objectStore(stores[0]);
    var keys = await new Promise(function(res, rej){
      var rq = st.getAllKeys();
      rq.onsuccess = function(){ res(rq.result); };
      rq.onerror = function(){ rej(rq.error); };
    });
    return JSON.stringify({ stores: stores, keyCount: keys.length, keys: keys.slice(0, 10) });
  } catch(e) { return JSON.stringify({ err: String(e) }); }
})()`);
console.log('  /userfs: ' + userfs);

const parsed = JSON.parse(userfs);
const hasData = !parsed.err && parsed.keyCount > 0;
log('Save ton tai trong IndexedDB sau reload', hasData, hasData ? (parsed.keyCount + ' key') : userfs);

const errs = cdp.events.filter(e => e.method === 'Runtime.exceptionThrown' && e.sessionId === sessionId);
log('Khong co exception', errs.length === 0, errs.length ? errs[0].params.exceptionDetails.text : '');

console.log('');
const failed = results.filter(r => !r.p);
console.log('tong: ' + results.length + ', that bai: ' + failed.length);
console.log(failed.length === 0 ? 'RESULT: PASS' : 'RESULT: FAIL');
process.exit(failed.length === 0 ? 0 : 1);
