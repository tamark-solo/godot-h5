// tools/test/browser-boot-test.mjs
// C07 / G02 — Kiem tra artifact Web co BOOT THAT trong browser khong.
//
// Dung Chrome DevTools Protocol qua WebSocket co san trong Node >= 22 (khong can dependency).
// Thu thap: console log, exception, request that bai, trang thai overlay, kich thuoc canvas.
// Exit 0 = boot thanh cong (overlay an + khong co exception), 1 = that bai.
//
// Dung: node tools/test/browser-boot-test.mjs <url> [waitMs] [screenshotPath] [cdpPort]

import { writeFileSync, mkdirSync } from 'node:fs';
import { dirname } from 'node:path';

const url = process.argv[2];
const waitMs = parseInt(process.argv[3] || '25000', 10);
const shotPath = process.argv[4] && process.argv[4] !== '-' ? process.argv[4] : null;
const cdpPort = parseInt(process.argv[5] || '9222', 10);

if (!url) { console.error('usage: node browser-boot-test.mjs <url> [waitMs] [screenshotPath] [cdpPort]'); process.exit(2); }

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

async function browserWsUrl() {
  for (let i = 0; i < 40; i++) {
    try {
      const r = await fetch(`http://127.0.0.1:${cdpPort}/json/version`);
      const j = await r.json();
      if (j.webSocketDebuggerUrl) return j.webSocketDebuggerUrl;
    } catch { /* chua len */ }
    await sleep(500);
  }
  throw new Error('Khong ket noi duoc Chrome CDP tren port ' + cdpPort);
}

class CDP {
  constructor(ws) {
    this.ws = ws; this.seq = 0; this.pending = new Map(); this.events = [];
    ws.addEventListener('message', (ev) => {
      let msg; try { msg = JSON.parse(ev.data); } catch { return; }
      if (msg.id && this.pending.has(msg.id)) {
        const p = this.pending.get(msg.id); this.pending.delete(msg.id);
        msg.error ? p.reject(new Error(JSON.stringify(msg.error))) : p.resolve(msg.result);
      } else if (msg.method) {
        this.events.push(msg);
      }
    });
  }
  send(method, params = {}, sessionId) {
    const id = ++this.seq;
    const payload = { id, method, params };
    if (sessionId) payload.sessionId = sessionId;
    return new Promise((resolve, reject) => {
      this.pending.set(id, { resolve, reject });
      this.ws.send(JSON.stringify(payload));
      setTimeout(() => { if (this.pending.has(id)) { this.pending.delete(id); reject(new Error('CDP timeout: ' + method)); } }, 90000);
    });
  }
}

const wsUrl = await browserWsUrl();
const ws = new WebSocket(wsUrl);
await new Promise((res, rej) => { ws.addEventListener('open', res); ws.addEventListener('error', rej); });
const cdp = new CDP(ws);

const { targetId } = await cdp.send('Target.createTarget', { url: 'about:blank' });
const { sessionId } = await cdp.send('Target.attachToTarget', { targetId, flatten: true });

await cdp.send('Page.enable', {}, sessionId);
await cdp.send('Runtime.enable', {}, sessionId);
await cdp.send('Log.enable', {}, sessionId);
await cdp.send('Network.enable', {}, sessionId);

await cdp.send('Page.navigate', { url }, sessionId);

// Cho trang chay: load + WASM init + vai frame game.
await sleep(waitMs);

// --- Thu thap bang chung ---
const consoleMsgs = [];
const exceptions = [];
const failedRequests = [];
const badMime = [];

for (const e of cdp.events) {
  if (e.method === 'Runtime.consoleAPICalled' && e.sessionId === sessionId) {
    const text = (e.params.args || []).map((a) => a.value ?? a.description ?? a.type).join(' ');
    consoleMsgs.push({ level: e.params.type, text });
  } else if (e.method === 'Runtime.exceptionThrown' && e.sessionId === sessionId) {
    const d = e.params.exceptionDetails;
    exceptions.push(d.exception?.description || d.text);
  } else if (e.method === 'Log.entryAdded' && e.sessionId === sessionId) {
    const en = e.params.entry;
    if (en.level === 'error') consoleMsgs.push({ level: 'error(log)', text: en.text + (en.url ? ' @ ' + en.url : '') });
  } else if (e.method === 'Network.loadingFailed' && e.sessionId === sessionId) {
    failedRequests.push(e.params.errorText + ' (' + (e.params.type || '?') + ')');
  } else if (e.method === 'Network.responseReceived' && e.sessionId === sessionId) {
    const r = e.params.response;
    if (/\.wasm$/i.test(r.url) && !/application\/wasm/i.test(r.mimeType || '')) badMime.push(r.url + ' -> ' + r.mimeType);
    if (/\.pck$/i.test(r.url) && !/octet-stream|application\/wasm/i.test(r.mimeType || '')) badMime.push(r.url + ' -> ' + r.mimeType);
  }
}

// --- Trang thai runtime ---
const probe = await cdp.send('Runtime.evaluate', {
  expression: `(function(){
    var st = document.getElementById('status');
    var cv = document.getElementById('canvas');
    return JSON.stringify({
      title: document.title,
      hasEngine: typeof Engine !== 'undefined',
      hasBridge: typeof window.H5Bridge !== 'undefined',
      bridgeVersion: (window.H5Bridge && window.H5Bridge.version) || null,
      statusHidden: st ? st.classList.contains('hidden') : null,
      statusVisible: st ? !st.classList.contains('hidden') : null,
      statusTitle: (document.getElementById('status-title')||{}).textContent || null,
      statusDetail: (document.getElementById('status-detail')||{}).textContent || null,
      errorBoxShown: (function(){ var e=document.getElementById('error-box'); return e ? e.style.display !== 'none' && e.textContent.length>0 : null; })(),
      errorBoxText: (function(){ var e=document.getElementById('error-box'); return e ? e.textContent.slice(0,400) : null; })(),
      canvasW: cv ? cv.width : null,
      canvasH: cv ? cv.height : null,
      clientW: cv ? cv.clientWidth : null,
      clientH: cv ? cv.clientHeight : null,
      isSecureContext: window.isSecureContext,
      dpr: window.devicePixelRatio
    });
  })()`,
  returnByValue: true,
}, sessionId);

const state = JSON.parse(probe.result.value);

if (shotPath) {
  try {
    const shot = await cdp.send('Page.captureScreenshot', { format: 'png' }, sessionId);
    mkdirSync(dirname(shotPath), { recursive: true });
    writeFileSync(shotPath, Buffer.from(shot.data, 'base64'));
  } catch (e) { console.error('screenshot failed: ' + e.message); }
}

// --- Bao cao ---
console.log('=== BROWSER BOOT TEST ===');
console.log('url            : ' + url);
console.log('title          : ' + state.title);
console.log('isSecureContext: ' + state.isSecureContext);
console.log('Engine co mat  : ' + state.hasEngine);
console.log('H5Bridge       : ' + state.hasBridge + ' (v' + state.bridgeVersion + ')');
console.log('canvas backing : ' + state.canvasW + 'x' + state.canvasH + '  (CSS ' + state.clientW + 'x' + state.clientH + ', dpr ' + state.dpr + ')');
console.log('overlay an?    : ' + state.statusHidden);
console.log('overlay title  : ' + state.statusTitle);
console.log('overlay detail : ' + (state.statusDetail || '').slice(0, 200));
console.log('error box hien : ' + state.errorBoxShown);
if (state.errorBoxShown) console.log('error box text : ' + (state.errorBoxText || '').slice(0, 400));
console.log('');
console.log('--- console (' + consoleMsgs.length + ') ---');
for (const m of consoleMsgs.slice(0, 40)) console.log('  [' + m.level + '] ' + String(m.text).slice(0, 220));
console.log('');
console.log('--- exceptions (' + exceptions.length + ') ---');
for (const e of exceptions.slice(0, 15)) console.log('  ' + String(e).split('\n').slice(0, 4).join('\n  '));
console.log('');
console.log('--- request that bai (' + failedRequests.length + ') ---');
for (const f of failedRequests.slice(0, 15)) console.log('  ' + f);
console.log('');
console.log('--- MIME sai (' + badMime.length + ') ---');
for (const b of badMime.slice(0, 10)) console.log('  ' + b);
console.log('');

const fatal = exceptions.length > 0 || state.errorBoxShown === true || state.hasEngine === false;
const booted = state.statusHidden === true;

console.log('booted (overlay an) : ' + booted);
console.log('co exception        : ' + (exceptions.length > 0));
console.log('');
console.log(booted && !fatal ? 'RESULT: PASS' : 'RESULT: FAIL');
process.exit(booted && !fatal ? 0 : 1);
