import 'package:flutter/foundation.dart';

/// One playable channel parsed from an M3U `#EXTINF` entry.
@immutable
class Channel {
  const Channel({
    required this.name,
    required this.url,
    required this.category,
    required this.group,
    this.flag,
  });

  /// Display name (flag emoji stripped out into [flag]).
  final String name;

  /// Stream URL — may be HLS (`.m3u8`) or raw mpegts/TS.
  final String url;

  /// Top-level genre: `Sports`, `News`, `Movies`, `Kids`, `Music`,
  /// `Entertainment`, ...
  final String category;

  /// Broadcaster sub-group, e.g. `ESPN`, `beIN`, `DAZN`, `Match`, `Other`.
  final String group;

  /// Country flag emoji if present in the original title, else null.
  final String? flag;

  /// Stable id for keys / favourites (url is unique per stream).
  String get id => url;

  @override
  bool operator ==(Object other) => other is Channel && other.url == url;

  @override
  int get hashCode => url.hashCode;
}