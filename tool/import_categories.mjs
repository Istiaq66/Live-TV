// Pulls an "all genres" channel set from the iptv-org public API and merges it
// into assets/playlist.m3u — so the app isn't sports-only. Scoped to English +
// India/Bangladesh and capped per category to keep the list fast and usable.
//
//   node tool/import_categories.mjs            # dry run, prints what it'd add
//   node tool/import_categories.mjs --write    # rewrite assets/playlist.m3u
//
// Then prune the dead ones:
//   node tool/prune_playlist.mjs --write
//
// Node 18+ (global fetch).

import { readFile, writeFile } from 'node:fs/promises';

const FILE = 'assets/playlist.m3u';
const WRITE = process.argv.includes('--write');
const PER_CATEGORY = 25; // cap kept per app-category

const CHANNELS = 'https://iptv-org.github.io/api/channels.json';
const STREAMS = 'https://iptv-org.github.io/api/streams.json';

// English + India/BD. India/BD ranked first so they fill the cap before others.
const COUNTRY_RANK = { IN: 0, BD: 0, GB: 1, US: 1, CA: 2, AU: 2, IE: 3, NZ: 3 };
const FLAG = {
  IN: '🇮🇳', BD: '🇧🇩', GB: '🇬🇧', US: '🇺🇸',
  CA: '🇨🇦', AU: '🇦🇺', IE: '🇮🇪', NZ: '🇳🇿',
};

// iptv-org category -> the app's top-level category. Anything not listed (or a
// channel whose categories never match) is skipped — we only want clear genres.
// NB: the app re-folds group-title, so Documentary/Business collapse to
// Entertainment in-app anyway; map them straight to Entertainment here.
const CAT_MAP = {
  news: 'News',
  movies: 'Movies',
  kids: 'Kids',
  music: 'Music',
  sports: 'Sports',
  religious: 'Religious',
  entertainment: 'Entertainment',
  general: 'Entertainment',
  series: 'Entertainment',
  comedy: 'Entertainment',
  lifestyle: 'Entertainment',
  documentary: 'Entertainment',
  culture: 'Entertainment',
  business: 'Entertainment',
  family: 'Entertainment',
  cooking: 'Entertainment',
  travel: 'Entertainment',
};

// Sports is already heavily represented; don't pad it from here.
const SKIP_CATEGORIES = new Set(['Sports']);

const json = async (u) => (await fetch(u, {
  headers: { 'User-Agent': 'drishto-import' },
})).json();

console.log('Fetching iptv-org metadata…');
const [channels, streams] = await Promise.all([json(CHANNELS), json(STREAMS)]);
console.log(`  ${channels.length} channels, ${streams.length} streams.`);

const chById = new Map(channels.map((c) => [c.id, c]));

// First app-category a channel's iptv-org categories map to.
function appCategory(ch) {
  for (const c of ch.categories || []) {
    const mapped = CAT_MAP[c];
    if (mapped) return mapped;
  }
  return null;
}

// streams.json preserves the channel's listed order roughly; iterate and pick
// the first working-looking stream per channel.
const seenChannel = new Set();
const existing = (await readFile(FILE, 'utf8')).toLowerCase();
const byCat = new Map(); // appCat -> [{ name, flag, url, ua, ref, rank }]

for (const s of streams) {
  if (!s.channel || !s.url) continue;
  if (seenChannel.has(s.channel)) continue;
  const ch = chById.get(s.channel);
  if (!ch) continue;
  if (ch.is_nsfw || ch.closed) continue;
  const rank = COUNTRY_RANK[ch.country];
  if (rank === undefined) continue; // outside English + India/BD scope
  const cat = appCategory(ch);
  if (!cat || SKIP_CATEGORIES.has(cat)) continue;
  // Skip channels already in the playlist (cheap substring check on name).
  if (existing.includes(ch.name.toLowerCase())) continue;

  seenChannel.add(s.channel);
  if (!byCat.has(cat)) byCat.set(cat, []);
  byCat.get(cat).push({
    name: ch.name,
    flag: FLAG[ch.country] || '',
    url: s.url,
    ua: s.user_agent || null,
    ref: s.referrer || null,
    rank,
  });
}

// Rank-sort (India/BD first) then cap each category.
const out = ['', '# --- All genres (iptv-org, English + India/BD) ---'];
let total = 0;
for (const [cat, list] of byCat) {
  list.sort((a, b) => a.rank - b.rank);
  const kept = list.slice(0, PER_CATEGORY);
  console.log(`  ${cat}: ${kept.length} (of ${list.length} candidates)`);
  for (const e of kept) {
    out.push(`#EXTINF:-1 group-title="${cat}",${e.name}${e.flag ? ' ' + e.flag : ''}`);
    if (e.ua) out.push(`#EXTVLCOPT:http-user-agent=${e.ua}`);
    if (e.ref) out.push(`#EXTVLCOPT:http-referrer=${e.ref}`);
    out.push(e.url);
    total++;
  }
}
console.log(`\nTotal new channels: ${total}`);

if (!WRITE) {
  console.log('\nDry run. Re-run with --write to append to the playlist.');
} else {
  const current = (await readFile(FILE, 'utf8')).replace(/\s+$/, '');
  await writeFile(FILE, current + '\n' + out.join('\n') + '\n', 'utf8');
  console.log(`\nAppended ${total} channels to ${FILE}.`);
}