// Pulls the maintained per-channel playlists from github.com/lupael/IPTV,
// extracts each fresh stream URL, and merges them into assets/playlist.m3u as a
// Bangladesh section — replacing the rotted BD-CDN entries (aynaott / bozztv /
// gpcdn / ncare / jagobd) that keep 404'ing.
//
//   node tool/import_lupael.mjs
//
// These URLs are mostly BD-geo-locked: they play in the native app from a BD
// connection but will fail a probe from elsewhere — so do NOT run the pruner
// after this.  Node 18+ (global fetch).

import { readFile, writeFile } from 'node:fs/promises';

const FILE = 'assets/playlist.m3u';
const API = 'https://api.github.com/repos/lupael/IPTV/contents/channels';
const RAW = 'https://raw.githubusercontent.com/lupael/IPTV/master/channels';

// slug -> { name, cat, flag }. Anything not listed falls back to a prettified
// name + Entertainment.
const MAP = {
  ananda: ['Ananda TV', 'Entertainment', '🇧🇩'],
  asian: ['Asian TV', 'Entertainment', '🇧🇩'],
  atnbangla: ['ATN Bangla', 'Entertainment', '🇧🇩'],
  atnnews: ['ATN News', 'News', '🇧🇩'],
  banglatv: ['Bangla TV', 'Entertainment', '🇧🇩'],
  banglavision: ['Bangla Vision', 'Entertainment', '🇧🇩'],
  bijoy: ['Bijoy TV', 'News', '🇧🇩'],
  boishakhi: ['Boishakhi TV', 'Entertainment', '🇧🇩'],
  btv: ['BTV National', 'Entertainment', '🇧🇩'],
  btvctg: ['BTV Chattogram', 'Entertainment', '🇧🇩'],
  btvworld: ['BTV World', 'News', '🇧🇩'],
  channel24: ['Channel 24', 'News', '🇧🇩'],
  channel9: ['Channel 9', 'Entertainment', '🇧🇩'],
  channeli: ['Channel i', 'Entertainment', '🇧🇩'],
  channels: ['Channel S', 'Entertainment', '🇧🇩'],
  channelsuk: ['Channel S UK', 'Entertainment', '🇧🇩'],
  cnews: ['Channel 9 News', 'News', '🇧🇩'],
  dbcnews: ['DBC News', 'News', '🇧🇩'],
  deepto: ['Deepto TV', 'Entertainment', '🇧🇩'],
  desh: ['Desh TV', 'News', '🇧🇩'],
  duronto: ['Duronto TV', 'Kids', '🇧🇩'],
  ekattor: ['Ekattor TV', 'News', '🇧🇩'],
  ekushey: ['Ekushey TV (ETV)', 'News', '🇧🇩'],
  enter10: ['Enter10 Bangla', 'Entertainment', '🇧🇩'],
  gtv: ['Gazi TV (GTV)', 'Sports', '🇧🇩'],
  hbo: ['HBO', 'Movies', ''],
  hbofamily: ['HBO Family', 'Movies', ''],
  hbohits: ['HBO Hits', 'Movies', ''],
  hbosig: ['HBO Signature', 'Movies', ''],
  hgtv: ['HGTV', 'Entertainment', ''],
  independent: ['Independent TV', 'News', '🇧🇩'],
  ipl: ['IPL Cricket', 'Sports', ''],
  jalsha: ['Zee Bangla / Jalsha', 'Entertainment', '🇮🇳'],
  jalsha2: ['Jalsha 2', 'Entertainment', '🇮🇳'],
  jalshahd: ['Jalsha HD', 'Entertainment', '🇮🇳'],
  jalshamovieshd: ['Jalsha Movies HD', 'Movies', '🇮🇳'],
  jamuna: ['Jamuna TV', 'News', '🇧🇩'],
  maasranga: ['Maasranga TV', 'Sports', '🇧🇩'],
  mohona: ['Mohona TV', 'Entertainment', '🇧🇩'],
  mytv: ['My TV', 'Entertainment', '🇧🇩'],
  nagorik: ['Nagorik TV', 'Entertainment', '🇧🇩'],
  news24: ['News24', 'News', '🇧🇩'],
  ngc: ['National Geographic', 'Entertainment', ''],
  nickbangla: ['Nickelodeon Bangla', 'Kids', '🇧🇩'],
  ntv: ['NTV', 'Entertainment', '🇧🇩'],
  ntvuk: ['NTV UK', 'Entertainment', '🇧🇩'],
  rtv: ['Rtv', 'Entertainment', '🇧🇩'],
  sangeetbang: ['Sangeet Bangla', 'Music', '🇮🇳'],
  satv: ['SA TV', 'Entertainment', '🇧🇩'],
  setmax: ['Sony SET MAX', 'Movies', '🇮🇳'],
  setmaxhd: ['Sony SET MAX HD', 'Movies', '🇮🇳'],
  somoy: ['Somoy News', 'News', '🇧🇩'],
  songsod: ['Sangsad TV', 'Entertainment', '🇧🇩'],
  sonypixhd: ['Sony PIX HD', 'Movies', ''],
  stargold1: ['Star Gold', 'Movies', '🇮🇳'],
  starplus: ['Star Plus', 'Entertainment', '🇮🇳'],
  sunbangla: ['Sun Bangla', 'Entertainment', '🇮🇳'],
  zbangla: ['Zee Bangla', 'Entertainment', '🇮🇳'],
  zbanglacinema: ['Zee Bangla Cinema', 'Movies', '🇮🇳'],
  '&flixhd': ['&Flix HD', 'Movies', '🇮🇳'],
  '&picture': ['&Pictures', 'Movies', '🇮🇳'],
  '&picturehd': ['&Pictures HD', 'Movies', '🇮🇳'],
  '&privehd': ['&Prive HD', 'Movies', '🇮🇳'],
};

// Existing entries on these hosts are stale — drop them; lupael replaces them.
const ROTTED_HOSTS = ['aynaott.com', 'bozztv.com', 'gpcdn.net', 'ncare.live', 'jagobd.com'];

function pretty(slug) {
  return slug.replace(/^&/, '').replace(/[-_]/g, ' ')
    .replace(/\b\w/g, (c) => c.toUpperCase());
}

// --- fetch the channel file list ---
const listing = await (await fetch(API, {
  headers: { 'User-Agent': 'drishto-import', Accept: 'application/vnd.github+json' },
})).json();
if (!Array.isArray(listing)) {
  throw new Error('GitHub API listing failed: ' + JSON.stringify(listing).slice(0, 200));
}
const slugs = listing
  .filter((f) => f.name.endsWith('.m3u8'))
  .map((f) => f.name.replace(/\.m3u8$/, ''));
console.log(`Found ${slugs.length} channel files.`);

// --- pull each + extract the stream URL (first non-# line) ---
async function urlFor(slug) {
  try {
    const txt = await (await fetch(`${RAW}/${encodeURIComponent(slug)}.m3u8`)).text();
    const line = txt.split(/\r?\n/).map((l) => l.trim())
      .find((l) => l && !l.startsWith('#'));
    return line || null;
  } catch {
    return null;
  }
}
const entries = [];
for (const slug of slugs) {
  const url = await urlFor(slug);
  if (!url) { console.log(`  ! no url: ${slug}`); continue; }
  const [name, cat, flag] = MAP[slug] || [pretty(slug), 'Entertainment', '🇧🇩'];
  entries.push({ name, cat, flag, url });
}
console.log(`Extracted ${entries.length} stream URLs.`);

// --- rebuild playlist: keep non-rotted existing lines, prepend lupael block ---
const lines = (await readFile(FILE, 'utf8')).split(/\r?\n/);
const kept = ['#EXTM3U'];
let dropped = 0;
for (let i = 0; i < lines.length; i++) {
  const t = lines[i].trim();
  if (t === '#EXTM3U' || t === '') continue;
  if (!t.startsWith('#')) {
    // URL line — already emitted with its directives below; handled via lookahead
  }
}
// Re-pair existing entries (EXTINF + optional #EXTVLCOPT + URL) and filter.
const existing = [];
let pend = [];
for (const raw of lines) {
  const t = raw.trim();
  if (t === '' || t === '#EXTM3U') continue;
  if (t.startsWith('#EXTINF')) pend = [raw];
  else if (t.startsWith('#')) { if (pend.length) pend.push(raw); }
  else { existing.push({ ext: pend, url: t }); pend = []; }
}
const existingKept = existing.filter((e) => {
  const host = (() => { try { return new URL(e.url).host.toLowerCase(); } catch { return ''; } })();
  const rotted = ROTTED_HOSTS.some((h) => host.includes(h));
  if (rotted) dropped++;
  return !rotted;
});

const out = ['#EXTM3U'];
out.push('# --- Bangladesh (maintained via github.com/lupael/IPTV) ---');
for (const e of entries) {
  out.push(`#EXTINF:-1 group-title="${e.cat}",${e.name}${e.flag ? ' ' + e.flag : ''}`);
  out.push(e.url);
}
for (const e of existingKept) out.push(...e.ext, e.url);

await writeFile(FILE, out.join('\n') + '\n', 'utf8');
console.log(`Added ${entries.length} lupael channels, dropped ${dropped} rotted, kept ${existingKept.length} others.`);