// tools/test/browser-error-test.mjs
// G02 — Kiem tra shell BAO LOI dung trong cac nhanh hong.
//
// Yeu cau G02: "shell tu bao loi WebGL2/secure-context/thieu file;
//               co retry, khong spinner vo han".
//
// Cach lam: phuc vu artifact that, nhung PHA HOAI co chu dich tung nhanh:
//   1. Thieu index.wasm      -> phai hien loi, KHONG spinner vo han
//   2. Thieu index.js        -> phai hien loi (Engine undefined)
//   3. WebGL2 bi tat         -> phai hien loi WebGL2 (dung Chrome flag)
//   4. Binh thuong           -> doi chung: phai boot duoc
//
// usage: node browser-error-test.mjs <baseUrl> [cdpPort]

import { mkdirSync, writeFileSync } from 'node:fs';

const baseUrl = process.argv[2];
const cdpPort = parseInt(process.argv[3] || '9222', 10);
if (!baseUrl) { console.error('usage: node browser-error-test.mjs <baseUrl> [cdpPort]'); process.exit(2); }

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

const results = [];
const log = (n, p, d) => { results.push({ n, p }); console.log((p ? '  [PASS] ' : '  [FAIL] ') + n + (d ? ' — ' + d : '')); };

async function openPage(url, waitMs, opts = {}) {
  const { targetId } = await cdp.send('Target.createTarget', { url: 'about:blank' });
  const { sessionId } = await cdp.send('Target.attachToTarget', { targetId, flatten: true });
  await cdp.send('Page.enable', {}, sessionId);
  await cdp.send('Runtime.enable', {}, sessionId);
  await cdp.send('Log.enable', {}, sessionId);
  await cdp.send('Network.enable', {}, sessionId);
  if (opts.disableWebGL) {
    // Chan WebGL2 o tang JS de mo phong thiet bi khong ho tro
    await cdp.send('Page.addScriptToEvaluateOnNewDocument', {
      source: `(function(){
        const orig = HTMLCanvasElement.prototype.getContext;
        HTMLCanvasElement.prototype.getContext = function(type, ...rest) {
          if (String(type).indexOf('webgl') === 0) return null;
          return orig.call(this, type, ...rest);
        };
      })();`,
    }, sessionId);
  }
  await cdp.send('Page.navigate', { url }, sessionId);
  await sleep(waitMs);
  return sessionId;
}

const probe = async (sessionId) => {
  const r = await cdp.send('Runtime.evaluate', {
    expression: `(function(){
      var st = document.getElementById('status');
      var eb = document.getElementById('error-box');
      var rb = document.getElementById('retry');
      return JSON.stringify({
        statusHidden: st ? st.classList.contains('hidden') : null,
        title: (document.getElementById('status-title')||{}).textContent || null,
        detail: (document.getElementById('status-detail')||{}).textContent || null,
        errorShown: eb ? eb.style.display !== 'none' && eb.textContent.length > 0 : null,
        errorText: eb ? eb.textContent.slice(0, 300) : null,
        retryVisible: rb ? rb.style.display !== 'none' : null,
        hasEngine: typeof Engine !== 'undefined',
        hasBridge: typeof window.H5Bridge !== 'undefined'
      });
    })()`,
    returnByValue: true,
  }, sessionId);
  return JSON.parse(r.result.value);
};

console.log('=== G02: SHELL ERROR BRANCH TESTS ===');
console.log('base: ' + baseUrl);
console.log('');

// ---------------- 1. Thieu index.wasm ----------------
console.log('--- 1. Thieu index.wasm ---');
let s = await openPage(baseUrl + '/missing-wasm/index.html?stallMs=8000', 20000);
let st = await probe(s);
console.log('  title        : ' + st.title);
console.log('  detail       : ' + (st.detail || '').slice(0, 120));
console.log('  error shown  : ' + st.errorShown);
console.log('  retry visible: ' + st.retryVisible);
log('Thieu WASM -> hien loi (khong spinner vo han)', st.statusHidden === false && st.errorShown === true);
log('Thieu WASM -> co nut Thu lai', st.retryVisible === true);

// ---------------- 2. Thieu index.js ----------------
console.log('');
console.log('--- 2. Thieu index.js (Engine undefined) ---');
s = await openPage(baseUrl + '/missing-js/index.html', 12000);
st = await probe(s);
console.log('  title        : ' + st.title);
console.log('  detail       : ' + (st.detail || '').slice(0, 140));
console.log('  hasEngine    : ' + st.hasEngine);
log('Thieu JS -> hien loi ro rang', st.statusHidden === false && st.errorShown === true);
log('Thieu JS -> thong bao nhac den loader', /index\.js|loader|tải/i.test(String(st.title) + String(st.detail)));

// ---------------- 3. WebGL2 bi tat ----------------
console.log('');
console.log('--- 3. WebGL2 khong kha dung ---');
s = await openPage(baseUrl + '/ok/index.html', 22000, { disableWebGL: true });
st = await probe(s);
console.log('  title        : ' + st.title);
console.log('  detail       : ' + (st.detail || '').slice(0, 200));
console.log('  error shown  : ' + st.errorShown);
log('Thieu WebGL2 -> hien loi', st.statusHidden === false && st.errorShown === true);
log('Thieu WebGL2 -> thong bao co huong dan WebGL2', /webgl2|webgl/i.test(String(st.title) + String(st.detail)));

// ---------------- 4. Doi chung: binh thuong ----------------
console.log('');
console.log('--- 4. Doi chung: ban binh thuong ---');
s = await openPage(baseUrl + '/ok/index.html', 25000);
st = await probe(s);
console.log('  statusHidden : ' + st.statusHidden);
console.log('  hasEngine    : ' + st.hasEngine);
log('Ban binh thuong -> boot duoc (overlay an)', st.statusHidden === true);

console.log('');
const failed = results.filter(r => !r.p);
console.log('tong: ' + results.length + ', that bai: ' + failed.length);
console.log(failed.length === 0 ? 'RESULT: PASS' : 'RESULT: FAIL');
process.exit(failed.length === 0 ? 0 : 1);