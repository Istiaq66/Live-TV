import 'dart:async';

import 'package:http/http.dart' as http;

/// Liveness state of a stream URL.
enum StreamStatus { unknown, checking, online, offline }

/// Probes IPTV stream URLs for reachability without downloading the whole feed.
///
/// Strategy: a ranged `GET` (first 2 bytes) with a spoofed player User-Agent —
/// most IPTV/HLS origins answer this fast. `HEAD` is avoided because many of
/// these servers don't implement it. A 2xx/3xx response (and, for `.m3u8`,
/// playlist-looking content) counts as online.
class StreamHealthChecker {
  StreamHealthChecker({this.timeout = const Duration(seconds: 7)});

  final Duration timeout;

  Future<bool> isAlive(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme) return false;

    final client = http.Client();
    try {
      final req = http.Request('GET', uri)
        ..followRedirects = true
        ..headers['Range'] = 'bytes=0-1'
        ..headers['User-Agent'] = 'VLC/3.0.20 LibVLC/3.0.20'
        ..headers['Accept'] = '*/*';

      final resp = await client.send(req).timeout(timeout);
      final ok = resp.statusCode >= 200 && resp.statusCode < 400;
      if (!ok) {
        unawaited(resp.stream.drain<void>().catchError((_) {}));
        return false;
      }

      // For HLS, confirm we actually got a playlist (not an HTML error page).
      final isHls = uri.path.toLowerCase().endsWith('.m3u8');
      if (isHls) {
        final head = await _firstBytes(resp.stream, 64)
            .timeout(timeout, onTimeout: () => '');
        // #EXTM3U may sit just past the 2-byte range on some servers; accept a
        // playlist signature OR a generic 200 when the body is unreadable.
        return head.isEmpty || head.contains('#EXT') || head.contains('m3u');
      }

      unawaited(resp.stream.drain<void>().catchError((_) {}));
      return true;
    } catch (_) {
      return false;
    } finally {
      client.close();
    }
  }

  Future<String> _firstBytes(Stream<List<int>> stream, int max) async {
    final bytes = <int>[];
    await for (final chunk in stream) {
      bytes.addAll(chunk);
      if (bytes.length >= max) break;
    }
    return String.fromCharCodes(bytes.take(max));
  }

  /// Checks many URLs with bounded concurrency, reporting each result as it
  /// lands. Returns when every url has been probed.
  Future<void> checkAll(
    Iterable<String> urls, {
    required void Function(String url, bool alive) onResult,
    int concurrency = 8,
  }) async {
    final queue = urls.toList();
    var index = 0;

    Future<void> worker() async {
      while (true) {
        final i = index++;
        if (i >= queue.length) return;
        final url = queue[i];
        final alive = await isAlive(url);
        onResult(url, alive);
      }
    }

    await Future.wait([
      for (var w = 0; w < concurrency; w++) worker(),
    ]);
  }
}