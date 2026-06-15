// Merges tool/xfireflix.json channels into assets/playlist.m3u.
// Dedups by URL (skips ones already present), categorises by name keywords,
// and REMOVES NOTHING. Run after edits to re-add the xfireflix set.
//
//   node tool/merge_json.mjs

import { readFile, writeFile } from 'node:fs/promises';

const FILE = 'assets/playlist.m3u';
const JSON_FILE = 'tool/xfireflix.json';

// Ordered category rules — first hit wins.
const RULES = [
  ['Kids', ['CARTOON', 'CBEEBIES', 'DORAEMON', 'TOM & JER', 'MOTU', 'GOPAL', 'PBS KIDS', 'ZB CARTOON', 'NICK']],
  ['Religious', ['QURAN', 'SUNNAH', 'MADANI', 'ISTIQAMA', 'PEACE TV', 'QAMAR', 'ARABICA', 'ISLAM']],
  ['Movies', ['MOVIE', 'BOLLYWOOD', 'GOLDMINES', 'FLIX', ' PIX', 'CINEMA', 'SHEMAROO', 'ZEE ACTION',
    'MARDAANI', 'SURONGO', 'ANTARJAL', 'GREENLAND', 'JANA NAYAGAN', 'TEST (2025)', 'FREELANCER',
    'SONY MAX', 'B4U', 'JALSHA MOVIE']],
  ['Music', ['MUSIC', '9XM', 'DHOOM', 'FM RADIO', 'BALLE', 'YRF', 'SANGEET']],
  ['Sports', ['SPORT', 'BEIN', 'T SPORTS', 'PTV SPORT', 'STAR SPORTS', 'SHAMSHAD', 'WIN SPORTS', 'A SPOR']],
  ['News', ['NEWS', 'CNN', ' DW ', 'DW ', 'FRANCE 24', 'NDTV', 'TRT', 'RT NEWS', 'PRESS TV',
    'IRAN INTERNATIONAL', 'GLOBAL NEWS', 'T GLOBAL', 'KOLKATA', 'TIMES OF INDIA', 'EKHBARIA', 'MUBASHER']],
];

function categorise(name) {
  const n = ` ${name.toUpperCase()} `;
  for (const [cat, kws] of RULES) {
    if (kws.some((k) => n.includes(k))) return cat;
  }
  return 'Entertainment';
}

const { channels } = JSON.parse(await readFile(JSON_FILE, 'utf8'));

const lines = (await readFile(FILE, 'utf8')).split(/\r?\n/);
const present = new Set(
  lines.map((l) => l.trim()).filter((l) => l && !l.startsWith('#')),
);

const out = lines.join('\n').replace(/\n+$/, '').split('\n'); // trim trailing blanks
let added = 0, skipped = 0;
for (const ch of channels) {
  const url = ch.url.trim();
  const name = (ch.name || '').trim();
  if (!url || !name) { skipped++; continue; }
  if (present.has(url)) { skipped++; continue; }
  out.push(`#EXTINF:-1 group-title="${categorise(name)}",${name}`);
  out.push(url);
  present.add(url);
  added++;
}

await writeFile(FILE, out.join('\n') + '\n', 'utf8');
console.log(`Merged xfireflix: added ${added}, skipped ${skipped} (dup/empty).`);