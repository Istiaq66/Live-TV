import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/fixture.dart';

/// Fetches today's football (soccer) fixtures from TheSportsDB's free API.
///
/// Free tier uses the public test key `3`, no signup required:
///   https://www.thesportsdb.com/api/v1/json/3/eventsday.php?d=YYYY-MM-DD&s=Soccer
/// Results are best-effort — the free key is rate-limited and not exhaustive.
class FixturesService {
  FixturesService({this.timeout = const Duration(seconds: 10)});

  final Duration timeout;

  static const String _base = 'https://www.thesportsdb.com/api/v1/json/3';

  /// Today's football matches, sorted by kick-off (timed first, then TBD).
  /// Queries by the device's local date.
  Future<List<Fixture>> todayFootball() async {
    final now = DateTime.now();
    final d = '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
    final uri = Uri.parse('$_base/eventsday.php?d=$d&s=Soccer');

    final resp = await http.get(uri).timeout(timeout);
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw Exception('Fixtures request failed (${resp.statusCode})');
    }

    final body = jsonDecode(resp.body);
    final events = (body is Map<String, dynamic>) ? body['events'] : null;
    if (events is! List) return const []; // API returns null when nothing today.

    final fixtures = <Fixture>[];
    for (final e in events) {
      if (e is Map<String, dynamic>) {
        final f = Fixture.fromSportsDb(e);
        if (f != null) fixtures.add(f);
      }
    }

    fixtures.sort((a, b) {
      final ka = a.kickoff, kb = b.kickoff;
      if (ka == null && kb == null) return a.title.compareTo(b.title);
      if (ka == null) return 1; // TBD sinks to the bottom
      if (kb == null) return -1;
      return ka.compareTo(kb);
    });
    return fixtures;
  }
}