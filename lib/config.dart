/// App-wide configuration.
library;

import 'package:flutter/foundation.dart' show kIsWeb;

/// Base URL of a CORS proxy used **on web only** to fetch IPTV streams that
/// don't send `Access-Control-Allow-Origin`. Leave empty to disable (native
/// builds never use it — mpv ignores CORS).
///
/// The proxy must accept `?url=<encoded stream url>`, return the resource with
/// `Access-Control-Allow-Origin: *`, and rewrite `.m3u8` playlist entries so
/// nested segment/variant URLs also route back through the proxy. A ready-made
/// Cloudflare Worker is in `web_proxy/worker.js`.
///
/// Example after deploying the worker:
///   const kStreamProxyBase = 'https://drishto-proxy.yourname.workers.dev';
const String kStreamProxyBase = 'https://drishto-proxy.ahmedboby66.workers.dev';

/// Shared secret sent to the proxy as `?t=` to gate abuse. Must match the
/// worker's `PROXY_TOKEN` secret. Leave empty to disable the token check (the
/// worker only enforces it when its own `PROXY_TOKEN` is set). Note: in a web
/// build this value ships in client JS, so it deters casual abuse rather than
/// being truly secret — the worker's SSRF guard is the real protection.
const String kStreamProxyToken = '';

/// Stream hosts that cannot work on the web build: they geo-restrict to
/// Bangladesh (the proxy egresses from Cloudflare's non-BD edge → 403/522) or
/// serve expired-token URLs that 404. Channels on these hosts are hidden on web
/// only — native builds (run from BD) still play them fine.
const List<String> _webBlockedHosts = [
  'aynaott.com',
  'bozztv.com',
  'ncare.live',
  'jagobd.com',
  'gpcdn.net',
  'raytahost.com',
];

/// Whether [url] is worth showing on the current platform. Always true on
/// native; on web, false for hosts known to be unplayable there.
bool isPlayableHere(String url) {
  if (!kIsWeb) return true;
  final host = Uri.tryParse(url)?.host.toLowerCase() ?? '';
  return !_webBlockedHosts.any(host.contains);
}

/// Routes [url] through the CORS proxy when running on web and a proxy is
/// configured; returns [url] unchanged on native or when no proxy is set.
///
/// Any per-stream [headers] (Referer / User-Agent) are passed as query params
/// because browsers forbid setting those request headers from JS — the worker
/// re-applies them when fetching the origin.
String proxiedUrl(String url, [Map<String, String> headers = const {}]) {
  if (!kIsWeb || kStreamProxyBase.isEmpty) return url;
  var out = '$kStreamProxyBase?url=${Uri.encodeComponent(url)}';
  final ref = headers['Referer'];
  final ua = headers['User-Agent'];
  if (ref != null && ref.isNotEmpty) out += '&ref=${Uri.encodeComponent(ref)}';
  if (ua != null && ua.isNotEmpty) out += '&ua=${Uri.encodeComponent(ua)}';
  if (kStreamProxyToken.isNotEmpty) {
    out += '&t=${Uri.encodeComponent(kStreamProxyToken)}';
  }
  return out;
}