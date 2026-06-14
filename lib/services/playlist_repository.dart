import 'package:flutter/services.dart' show rootBundle;

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
    return M3uParser.parse(raw);
  }
}