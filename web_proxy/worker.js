// Drishto CORS proxy — Cloudflare Worker.
//
// Makes third-party IPTV streams playable from the web build by adding CORS
// headers and rewriting HLS playlists so nested segment/variant URLs route
// back through this same proxy (otherwise the browser re-blocks them).
//
// Deploy (free):
//   1. https://dash.cloudflare.com → Workers & Pages → Create → Worker
//   2. Paste this file, Deploy. Note the URL, e.g.
//        https://drishto-proxy.<you>.workers.dev
//   3. Put that URL in lib/config.dart -> kStreamProxyBase
//   4. flutter run -d chrome  (or build web)
//
// Or with wrangler:  wrangler deploy web_proxy/worker.js
//
// Abuse protection (in order of strength):
//   - SSRF guard: target must be http/https and not a private/loopback/
//     link-local address (blocks cloud-metadata + internal-network probing).
//   - Optional shared token: set a `PROXY_TOKEN` Worker secret
//       wrangler secret put PROXY_TOKEN
//     and put the same value in lib/config.dart -> kStreamProxyToken.
//   - Referer/Origin allowlist (spoofable; keep as a soft filter only).

const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET,HEAD,OPTIONS',
  'Access-Control-Allow-Headers': '*',
};

// Only these hosts may use the proxy (checked against the request's Referer /
// Origin). Stops the open proxy from being abused by other sites. Add your
// production host here (e.g. 'drishto.app') when you move off *.pages.dev.
function isAllowedHost(host) {
  return (
    host === 'localhost' ||
    host === '127.0.0.1' ||
    host.endsWith('.pages.dev')
  );
}

// Returns true if the request comes from an allowed page. Falls back to Origin
// when Referer is absent; blocks when neither is present.
function isAllowed(request) {
  const src = request.headers.get('Referer') || request.headers.get('Origin');
  if (!src) return false;
  try {
    return isAllowedHost(new URL(src).hostname);
  } catch (_) {
    return false;
  }
}

// SSRF guard. The Referer check is spoofable (it's just a header), so the
// target host itself must be vetted: only http/https, never a private,
// loopback, link-local (cloud metadata = 169.254.169.254) or otherwise
// internal address. Hostnames that aren't IP literals are allowed through —
// public IPTV origins are what we expect.
function isBlockedTarget(u) {
  if (u.protocol !== 'http:' && u.protocol !== 'https:') return true;
  const host = u.hostname.toLowerCase();
  if (host === 'localhost' || host.endsWith('.localhost') ||
      host === 'metadata.google.internal') {
    return true;
  }
  // IPv6 literal — block loopback/link-local/unique-local; pass other globals.
  if (host.includes(':')) {
    return host === '::1' || host.startsWith('fe80:') ||
      host.startsWith('fc') || host.startsWith('fd');
  }
  // IPv4 literal — block RFC1918 / loopback / link-local / CGNAT / 0.0.0.0.
  const m = host.match(/^(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})$/);
  if (m) {
    const [a, b] = [Number(m[1]), Number(m[2])];
    if (a === 10 || a === 127 || a === 0) return true;
    if (a === 169 && b === 254) return true; // link-local + metadata
    if (a === 192 && b === 168) return true;
    if (a === 172 && b >= 16 && b <= 31) return true;
    if (a === 100 && b >= 64 && b <= 127) return true; // CGNAT
  }
  return false;
}

export default {
  async fetch(request, env) {
    if (request.method === 'OPTIONS') {
      return new Response(null, { headers: CORS });
    }

    const reqUrl = new URL(request.url);

    // Shared token (set `PROXY_TOKEN` as a Worker secret/var to enable). When
    // configured, every request must carry the matching ?t= — raises the bar
    // beyond the spoofable Referer check. Skipped when unset for back-compat.
    if (env && env.PROXY_TOKEN && reqUrl.searchParams.get('t') !== env.PROXY_TOKEN) {
      return new Response('Forbidden: bad token.', { status: 403, headers: CORS });
    }

    if (!isAllowed(request)) {
      return new Response('Forbidden: this proxy only serves the Drishto app.',
        { status: 403, headers: CORS });
    }

    const target = reqUrl.searchParams.get('url');
    if (!target) {
      return new Response('Missing ?url=', { status: 400, headers: CORS });
    }

    let upstream;
    try {
      upstream = new URL(target);
    } catch (_) {
      return new Response('Bad url', { status: 400, headers: CORS });
    }
    if (isBlockedTarget(upstream)) {
      return new Response('Forbidden: target not allowed.',
        { status: 403, headers: CORS });
    }

    // Per-stream Referer / User-Agent come from the app as query params
    // (browsers forbid setting those request headers from JS). Fall back to a
    // player UA and the origin's own host when not supplied.
    const refParam = reqUrl.searchParams.get('ref');
    const uaParam = reqUrl.searchParams.get('ua');

    const headers = new Headers();
    headers.set('User-Agent', uaParam || 'VLC/3.0.20 LibVLC/3.0.20');
    headers.set('Accept', '*/*');
    const range = request.headers.get('Range');
    if (range) headers.set('Range', range);
    headers.set('Referer', refParam || `${upstream.protocol}//${upstream.host}/`);

    let resp;
    try {
      resp = await fetch(upstream.toString(), { headers, redirect: 'follow' });
    } catch (e) {
      return new Response('Upstream fetch failed: ' + e, { status: 502, headers: CORS });
    }

    const ct = (resp.headers.get('Content-Type') || '').toLowerCase();
    const path = upstream.pathname.toLowerCase();
    const isPlaylist = ct.includes('mpegurl') || path.endsWith('.m3u8');

    const out = new Headers(resp.headers);
    for (const [k, v] of Object.entries(CORS)) out.set(k, v);
    out.delete('Content-Security-Policy');
    out.delete('X-Frame-Options');

    if (!isPlaylist) {
      // Segments (.ts/.m4s/keys) — stream straight through with CORS added.
      return new Response(resp.body, { status: resp.status, headers: out });
    }

    // Rewrite playlist: every URI (variant, segment, key) must point back at
    // this proxy. Relative URIs resolve against the playlist's FINAL url
    // (resp.url) — if the origin redirected to a CDN, the original `upstream`
    // would resolve segments to the wrong host.
    const text = await resp.text();
    const resolveBase = new URL(resp.url || upstream.toString());
    const base = `${reqUrl.origin}${reqUrl.pathname}`;
    const token = reqUrl.searchParams.get('t');
    const suffix =
      (refParam ? `&ref=${encodeURIComponent(refParam)}` : '') +
      (uaParam ? `&ua=${encodeURIComponent(uaParam)}` : '') +
      (token ? `&t=${encodeURIComponent(token)}` : '');
    const wrap = (abs) => `${base}?url=${encodeURIComponent(abs)}${suffix}`;

    const rewritten = text.split('\n').map((line) => {
      const t = line.trim();
      if (t === '') return line;
      // EXT-X-KEY / MAP carry URI="..."
      if (t.startsWith('#')) {
        return line.replace(/URI="([^"]+)"/g, (_, u) => {
          const abs = new URL(u, resolveBase).toString();
          return `URI="${wrap(abs)}"`;
        });
      }
      // Bare URI line (variant playlist or media segment).
      const abs = new URL(t, resolveBase).toString();
      return wrap(abs);
    }).join('\n');

    out.set('Content-Type', ct || 'application/vnd.apple.mpegurl');
    out.delete('Content-Length'); // body length changed
    return new Response(rewritten, { status: resp.status, headers: out });
  },
};