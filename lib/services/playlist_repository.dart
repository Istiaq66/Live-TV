import 'package:flutter/services.dart' show rootBundle;

import '../config.dart';
import '../models/channel.dart';
import 'm3u_parser.dart';

/// Loads the bundled playlist asset and exposes parsed channels.
///
/// Swap [_assetPath] for a network fetch later without touching the UI.
class PlaylistRepository {
  const PlaylistRepository();

  static const String _assetPath = 'assets/playlist.m3u';

  Future<List<Channel>> loadChannels() async {
    final raw = await rootBundle.loadString(_assetPath);
    final channels = M3uParser.parse(raw);
    // Drop channels that can't play on the current platform (web hides
    // BD-geo-locked hosts; native keeps everything).
    return channels.where((c) => isPlayableHere(c.url)).toList();
  }
}