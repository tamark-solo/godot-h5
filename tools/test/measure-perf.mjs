// tools/test/measure-perf.mjs
// H01 — Do cold/warm load, frame time p50/p95/p99, memory trend.
//
// Dung CDP: Network + Performance + Runtime de lay so do THAT, khong uoc luong.
// Ghi JSON ra file de lam bang chung co build ID.
//
// usage: node measure-perf.mjs <url> <outJson> [cdpPort] [soakSeconds]

import { writeFileSync, mkdirSync } from 'node:fs';
import { dirname } from 'node:path';

const url = process.argv[2];
const outJson = process.argv[3];
const cdpPort = parseInt(process.argv[4] || '9222', 10);
const soakSeconds = parseInt(process.argv[5] || '60', 10);
if (!url || !outJson) { console.error('usage: node measure-perf.mjs <url> <outJson> [cdpPort] [soakSeconds]'); process.exit(2); }

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
      setTimeout(() => { if (this.pending.has(id)) { this.pending.delete(id); rej(new Error('CDP timeout ' + method)); } }, 120000);
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
await cdp.send('Network.enable', {}, sessionId);
await cdp.send('Performance.enable', {}, sessionId);

const evalJs = async (expr, awaitPromise = false) => {
  const r = await cdp.send('Runtime.evaluate', { expression: expr, returnByValue: true, awaitPromise }, sessionId);
  if (r.exceptionDetails) throw new Error(r.exceptionDetails.text);
  return r.result.value;
};

// ---------------- COLD LOAD ----------------
console.log('=== H01: PERFORMANCE MEASUREMENT ===');
console.log('url: ' + url);
console.log('');

// Xoa cache de do cold that su
await cdp.send('Network.clearBrowserCache', {}, sessionId);
await cdp.send('Network.setCacheDisabled', { cacheDisabled: true }, sessionId);

const t0 = Date.now();
await cdp.send('Page.navigate', { url }, sessionId);

// Cho boot xong (overlay an) hoac timeout
let bootMs = null;
for (let i = 0; i < 120; i++) {
  await sleep(500);
  try {
    const hidden = await evalJs("(function(){var s=document.getElementById('status');return s?s.classList.contains('hidden'):false;})()");
    if (hidden) { bootMs = Date.now() - t0; break; }
  } catch {}
}
console.log('cold boot (tới khi overlay ẩn): ' + (bootMs !== null ? bootMs + ' ms' : 'KHONG XAC DINH'));

// Bytes truyen qua mang
const resources = cdp.events.filter(e => e.method === 'Network.loadingFinished' && e.sessionId === sessionId);
const responses = cdp.events.filter(e => e.method === 'Network.responseReceived' && e.sessionId === sessionId);
const byType = {};
let totalEncoded = 0;
for (const r of resources) {
  const resp = responses.find(x => x.params.requestId === r.params.requestId);
  const u = resp ? resp.params.response.url : '?';
  const ext = (u.split('?')[0].split('.').pop() || 'other').toLowerCase();
  const key = ['.js','.wasm','.pck','.html','.png','.json'].includes('.' + ext) ? '.' + ext : 'other';
  byType[key] = (byType[key] || 0) + (r.params.encodedDataLength || 0);
  totalEncoded += (r.params.encodedDataLength || 0);
}
console.log('tổng bytes truyền (encoded): ' + totalEncoded);
for (const [k, v] of Object.entries(byType).sort((a,b) => b[1]-a[1])) {
  console.log('  ' + k.padEnd(8) + ' ' + v + ' bytes');
}

// ---------------- FRAME TIME ----------------
console.log('');
console.log('--- frame time (requestAnimationFrame, 5 giây) ---');
const frameStats = await evalJs(`(async function(){
  var times = [];
  var last = performance.now();
  await new Promise(function(resolve){
    var n = 0;
    function tick(now) {
      times.push(now - last);
      last = now;
      n++;
      if (n < 300) requestAnimationFrame(tick); else resolve();
    }
    requestAnimationFrame(tick);
  });
  times.shift();
  times.sort(function(a,b){ return a-b; });
  function pct(p) { var i = Math.min(times.length-1, Math.floor(times.length*p)); return times[i]; }
  return JSON.stringify({
    samples: times.length,
    p50: +pct(0.50).toFixed(2),
    p95: +pct(0.95).toFixed(2),
    p99: +pct(0.99).toFixed(2),
    min: +times[0].toFixed(2),
    max: +times[times.length-1].toFixed(2),
    avg: +(times.reduce(function(a,b){return a+b;},0)/times.length).toFixed(2)
  });
})()`, true);
const frames = JSON.parse(frameStats);
console.log('  samples: ' + frames.samples);
console.log('  p50: ' + frames.p50 + ' ms   p95: ' + frames.p95 + ' ms   p99: ' + frames.p99 + ' ms');
console.log('  avg: ' + frames.avg + ' ms   min: ' + frames.min + '   max: ' + frames.max);

// ---------------- MEMORY ----------------
const mem = async () => {
  const m = await cdp.send('Performance.getMetrics', {}, sessionId);
  const o = {};
  for (const x of m.metrics) o[x.name] = x.value;
  return o;
};
const m1 = await mem();
const heap1 = (m1.JSHeapUsedSize || 0) / 1048576;
console.log('');
console.log('--- memory ---');
console.log('  JS heap sau boot: ' + heap1.toFixed(1) + ' MB');

// ---------------- SOAK ----------------
console.log('');
console.log('--- soak ' + soakSeconds + ' giây ---');
const soakStart = Date.now();
let peak = heap1;
while ((Date.now() - soakStart) / 1000 < soakSeconds) {
  await sleep(5000);
  const m = await mem();
  const h = (m.JSHeapUsedSize || 0) / 1048576;
  if (h > peak) peak = h;
}
const m2 = await mem();
const heap2 = (m2.JSHeapUsedSize || 0) / 1048576;
console.log('  JS heap sau soak: ' + heap2.toFixed(1) + ' MB   (đỉnh ' + peak.toFixed(1) + ' MB)');
console.log('  tăng: ' + (heap2 - heap1).toFixed(1) + ' MB');

// ---------------- WARM LOAD ----------------
console.log('');
console.log('--- warm load (cache đã có) ---');
await cdp.send('Network.setCacheDisabled', { cacheDisabled: false }, sessionId);
const t1 = Date.now();
await cdp.send('Page.reload', {}, sessionId);
let warmMs = null;
for (let i = 0; i < 120; i++) {
  await sleep(500);
  try {
    const hidden = await evalJs("(function(){var s=document.getElementById('status');return s?s.classList.contains('hidden'):false;})()");
    if (hidden) { warmMs = Date.now() - t1; break; }
  } catch {}
}
console.log('  warm boot: ' + (warmMs !== null ? warmMs + ' ms' : 'KHONG XAC DINH'));

const result = {
  url,
  measuredAt: new Date().toISOString(),
  coldBootMs: bootMs,
  warmBootMs: warmMs,
  transfer: { totalEncodedBytes: totalEncoded, byType },
  frameTime: frames,
  memory: { jsHeapAfterBootMB: +heap1.toFixed(2), jsHeapAfterSoakMB: +heap2.toFixed(2), peakMB: +peak.toFixed(2), growthMB: +(heap2 - heap1).toFixed(2) },
  soakSeconds,
};

mkdirSync(dirname(outJson), { recursive: true });
writeFileSync(outJson, JSON.stringify(result, null, 2));
console.log('');
console.log('đã ghi: ' + outJson);
