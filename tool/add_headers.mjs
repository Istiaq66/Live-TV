// Inserts #EXTVLCOPT Referer / User-Agent lines above stream URLs whose host
// needs them (aynaott, bozztv reject header-less requests with 403). The M3U
// parser turns these into Channel.headers, which mpv sends on native builds.
//
//   node tool/add_headers.mjs
//
// Idempotent: skips a URL that already has an #EXTVLCOPT directly above it.

import { readFile, writeFile } from 'node:fs/promises';

const FILE = 'assets/playlist.m3u';

// host substring -> { referer, ua }
const RULES = [
  { match: 'aynaott.com', referer: 'https://aynaott.com/', ua: 'Mozilla/5.0' },
  { match: 'bozztv.com', referer: 'https://bozztv.com/', ua: 'Mozilla/5.0' },
];

const lines = (await readFile(FILE, 'utf8')).split(/\r?\n/);
const out = [];
let added = 0;

for (let i = 0; i < lines.length; i++) {
  const line = lines[i];
  const t = line.trim();
  const isUrl = t !== '' && !t.startsWith('#');
  const rule = isUrl ? RULES.find((r) => t.includes(r.match)) : null;

  if (rule) {
    // Already patched? (previous non-empty line is an EXTVLCOPT)
    const prev = out.length ? out[out.length - 1].trim() : '';
    if (!prev.startsWith('#EXTVLCOPT')) {
      out.push(`#EXTVLCOPT:http-referrer=${rule.referer}`);
      out.push(`#EXTVLCOPT:http-user-agent=${rule.ua}`);
      added++;
    }
  }
  out.push(line);
}

await writeFile(FILE, out.join('\n'), 'utf8');
console.log(`Added headers to ${added} stream(s) (aynaott + bozztv).`);