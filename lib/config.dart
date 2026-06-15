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
  return out;
}