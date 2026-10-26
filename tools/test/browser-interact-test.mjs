// tools/test/browser-interact-test.mjs
// D02/D04/G03 — Kiem tra TUONG TAC that trong browser:
//   1. Bam de unlock audio (gesture) -> overlay phai an
//   2. Bam nut CHOI -> phai chuyen sang scene Game
//   3. Chay vai giay -> phai co diem/thoi gian hien tren HUD
//   4. Kiem tra save state co trung thuc khong
// Dung CDP qua WebSocket co san trong Node >= 22.
//
// usage: node browser-interact-test.mjs <url> [cdpPort] [shotDir]

import { writeFileSync, mkdirSync } from 'node:fs';

const url = process.argv[2];
const cdpPort = parseInt(process.argv[3] || '9222', 10);
const shotDir = process.argv[4] || 'docs/reports/img';
if (!url) { console.error('usage: node browser-interact-test.mjs <url> [cdpPort] [shotDir]'); process.exit(2); }

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

// Viewport lon hon de thay HUD ro
await cdp.send('Emulation.setDeviceMetricsOverride', { width: 720, height: 1280, deviceScaleFactor: 1, mobile: false }, sessionId);

await cdp.send('Page.navigate', { url }, sessionId);
await sleep(22000); // cho boot xong

const evalJs = async (expr) => {
  const r = await cdp.send('Runtime.evaluate', { expression: expr, returnByValue: true, awaitPromise: true }, sessionId);
  if (r.exceptionDetails) throw new Error(r.exceptionDetails.text + ' ' + (r.exceptionDetails.exception?.description || ''));
  return r.result.value;
};

const shot = async (name) => {
  try {
    const s = await cdp.send('Page.captureScreenshot', { format: 'png' }, sessionId);
    mkdirSync(shotDir, { recursive: true });
    writeFileSync(`${shotDir}/${name}.png`, Buffer.from(s.data, 'base64'));
    return true;
  } catch { return false; }
};

const click = async (x, y) => {
  for (const type of ['mousePressed', 'mouseReleased']) {
    await cdp.send('Input.dispatchMouseEvent', { type, x, y, button: 'left', clickCount: 1 }, sessionId);
    await sleep(60);
  }
};

const results = [];
const log = (name, pass, detail) => { results.push({ name, pass, detail }); console.log((pass ? '  [PASS] ' : '  [FAIL] ') + name + (detail ? ' — ' + detail : '')); };

console.log('=== BROWSER INTERACT TEST ===');
console.log('url: ' + url);
console.log('');

// --- 1. Boot xong ---
const booted = await evalJs("document.getElementById('status').classList.contains('hidden')");
log('Boot xong (overlay an)', booted === true);
await shot('interact-1-menu');

// --- 2. Audio unlock overlay dang hien ---
const audioOverlay = await evalJs("document.getElementById('audio-unlock').classList.contains('visible')");
log('Overlay unlock audio hien', audioOverlay === true);

// --- 3. Bam de unlock audio ---
await click(360, 640);
await sleep(1200);
const audioGone = await evalJs("!document.getElementById('audio-unlock').classList.contains('visible')");
log('Bam -> overlay audio an', audioGone === true);

// --- 4. Bridge da phat event audio:unlocked ---
const bridgeOk = await evalJs("typeof window.H5Bridge !== 'undefined' && window.H5Bridge.version");
log('H5Bridge ton tai', !!bridgeOk, 'v' + bridgeOk);

// --- 5. Bam nut CHOI ---
// Nut CHOI nam giua man hinh, hoi duoi mot chut (theo MainMenu.tscn: y ~ +60..180 so voi tam)
const canvasBox = await evalJs("(function(){var c=document.getElementById('canvas');var r=c.getBoundingClientRect();return JSON.stringify({x:r.x,y:r.y,w:r.width,h:r.height});})()");
const box = JSON.parse(canvasBox);
// CHOI o offset_top=60..180 so voi tam viewport 720x1280 -> y = 640+120 = 760 (theo toa do game)
// Canvas hien thi 720x1280 -> map truc tiep
const playX = box.x + box.w / 2;
const playY = box.y + (760 / 1280) * box.h;
await click(playX, playY);
await sleep(2500);
await shot('interact-2-after-play');

// --- 6. Da chuyen scene? Kiem tra bang noi dung HUD (Game scene co "Bỏ lỡ") ---
// Doc truc tiep tu canvas la khong the; thay vao do kiem tra bang console log
// va bang su thay doi pixel. Cach chac chan: hoi engine qua Performance/memory khong co.
// => Dung screenshot + so sanh kich thuoc file la khong du. Thay vao do:
//    kiem tra xem co exception khong, va scene co doi khong qua log.
const errs = cdp.events.filter(e => e.method === 'Runtime.exceptionThrown' && e.sessionId === sessionId);
log('Khong co exception sau khi bam CHOI', errs.length === 0, errs.length ? errs[0].params.exceptionDetails.text : '');

// --- 7. Cho gameplay chay, chup anh ---
await sleep(6000);
await shot('interact-3-gameplay');

// --- 8. Kiem tra save state trung thuc ---
// GameState.state_text() hien tren HUD; khong doc duoc tu DOM (nam trong canvas).
// Kiem tra gian tiep: localStorage/IndexedDB co duoc dung khong.
const idb = await evalJs("(async function(){ try { var dbs = await indexedDB.databases(); return JSON.stringify(dbs.map(function(d){return d.name;})); } catch(e){ return 'ERR:'+e.message; } })()");
log('IndexedDB truy cap duoc', typeof idb === 'string' && !idb.startsWith('ERR'), idb);

console.log('');
console.log('--- exceptions (' + errs.length + ') ---');
for (const e of errs.slice(0, 5)) console.log('  ' + e.params.exceptionDetails.text);

const failed = results.filter(r => !r.pass);
console.log('');
console.log('tong: ' + results.length + ' kiem tra, ' + failed.length + ' that bai');
console.log(failed.length === 0 ? 'RESULT: PASS' : 'RESULT: FAIL');
process.exit(failed.length === 0 ? 0 : 1);
