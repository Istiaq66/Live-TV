// Probes every stream in assets/playlist.m3u and removes only the
// DEFINITIVELY dead ones — 404/410 (path gone) or DNS / connection-refused
// (server gone). Timeouts and 403s are KEPT, because they're often just
// geo-blocks (e.g. BD-only streams) that work fine for the real audience.
//
//   node tool/prune_playlist.mjs            # dry run, just reports
//   node tool/prune_playlist.mjs --write    # rewrite the playlist
//
// Requires Node 18+ (global fetch).

import { readFile, writeFile } from 'node:fs/promises';

const FILE = 'assets/playlist.m3u';
const WRITE = process.argv.includes('--write');
const CONCURRENCY = 20;
const TIMEOUT_MS = 9000;
const UA = 'VLC/3.0.20 LibVLC/3.0.20';

const raw = await readFile(FILE, 'utf8');
const lines = raw.split(/\r?\n/);

// Pair each #EXTINF (+ any #EXT directives) with its following URL line.
const entries = []; // { extLines: string[], url, index }
let pending = [];
for (const line of lines) {
  const t = line.trim();
  if (t.startsWith('#EXTINF')) {
    pending = [line];
  } else if (t.startsWith('#')) {
    if (pending.length) pending.push(line);
  } else if (t === '') {
    // blank — ignore
  } else {
    entries.push({ extLines: pending, url: t });
    pending = [];
  }
}

console.log(`Probing ${entries.length} channels (timeout ${TIMEOUT_MS}ms, ${CONCURRENCY} at a time)…`);

// Returns 'dead' (remove), 'alive', or 'keep' (uncertain — geo/timeout/403).
async function classify(url) {
  let u;
  try {
    u = new URL(url);
  } catch {
    return 'dead'; // unparseable
  }
  const ctrl = new AbortController();
  const timer = setTimeout(() => ctrl.abort(), TIMEOUT_MS);
  try {
    const resp = await fetch(url, {
      method: 'GET',
      headers: { 'User-Agent': UA, Range: 'bytes=0-1', Accept: '*/*' },
      redirect: 'follow',
      signal: ctrl.signal,
    });
    // Hard-dead: resource/path gone.
    if (resp.status === 404 || resp.status === 410) return 'dead';
    return 'alive';
  } catch (e) {
    const msg = String(e?.cause?.code || e?.message || e);
    // Server gone: DNS failure or refused connection → dead.
    if (/ENOTFOUND|EAI_AGAIN|ECONNREFUSED|ERR_INVALID_URL/i.test(msg)) return 'dead';
    // Timeout / reset / TLS / other → keep (could be geo-blocked but alive).
    return 'keep';
  } finally {
    clearTimeout(timer);
  }
}

const verdicts = new Array(entries.length);
let next = 0;
async function worker() {
  while (true) {
    const i = next++;
    if (i >= entries.length) return;
    verdicts[i] = await classify(entries[i].url);
  }
}
await Promise.all(Array.from({ length: CONCURRENCY }, worker));

const dead = entries.filter((_, i) => verdicts[i] === 'dead');
const kept = entries.filter((_, i) => verdicts[i] !== 'dead');

console.log(`\nDead (will remove): ${dead.length}`);
for (const d of dead) {
  const name = (d.extLines[0]?.split(',').pop() || d.url).trim();
  console.log(`  ✗ ${name}`);
}
console.log(`\nKept: ${kept.length} (alive + uncertain/geo)`);

if (!WRITE) {
  console.log('\nDry run. Re-run with --write to apply.');
} else {
  const out = ['#EXTM3U'];
  for (const e of kept) {
    out.push(...e.extLines, e.url);
  }
  await writeFile(FILE, out.join('\n') + '\n', 'utf8');
  console.log(`\nWrote ${FILE} — ${kept.length} channels kept, ${dead.length} removed.`);
}