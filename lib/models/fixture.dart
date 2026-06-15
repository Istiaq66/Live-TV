import 'package:flutter/foundation.dart';

/// One football match scheduled today, from a fixtures provider.
@immutable
class Fixture {
  const Fixture({
    required this.id,
    required this.league,
    required this.home,
    required this.away,
    this.kickoff,
    this.status,
  });

  final String id;
  final String league;
  final String home;
  final String away;

  /// Kick-off time in the device's local zone, if the provider supplied one.
  final DateTime? kickoff;

  /// Free-form status string ("Not Started", "FT", "Live", ...), if any.
  final String? status;

  String get title => '$home vs $away';

  /// `HH:mm` local kick-off, or a status fallback, for the list subtitle.
  String get whenLabel {
    final k = kickoff;
    if (k != null) {
      final h = k.hour.toString().padLeft(2, '0');
      final m = k.minute.toString().padLeft(2, '0');
      return '$h:$m';
    }
    return status ?? 'TBD';
  }

  /// Parses one TheSportsDB `eventsday` record. Returns null if it lacks the
  /// minimum fields to be useful.
  static Fixture? fromSportsDb(Map<String, dynamic> j) {
    final home = (j['strHomeTeam'] as String?)?.trim();
    final away = (j['strAwayTeam'] as String?)?.trim();
    final id = (j['idEvent'] as String?)?.trim();
    if (id == null || home == null || away == null || home.isEmpty || away.isEmpty) {
      return null;
    }
    // strTimestamp is UTC ISO ("2026-06-15T18:30:00+00:00" / "...Z"); fall back
    // to dateEvent + strTime if absent.
    DateTime? ko;
    final ts = (j['strTimestamp'] as String?)?.trim();
    if (ts != null && ts.isNotEmpty) {
      ko = DateTime.tryParse(ts)?.toLocal();
    }
    if (ko == null) {
      final d = (j['dateEvent'] as String?)?.trim();
      final t = (j['strTime'] as String?)?.trim();
      if (d != null && d.isNotEmpty) {
        final iso = t != null && t.isNotEmpty ? '${d}T$t' : d;
        ko = DateTime.tryParse('${iso}Z')?.toLocal() ?? DateTime.tryParse(iso);
      }
    }
    return Fixture(
      id: id,
      league: (j['strLeague'] as String?)?.trim().isNotEmpty == true
          ? (j['strLeague'] as String).trim()
          : 'Football',
      home: home,
      away: away,
      kickoff: ko,
      status: (j['strStatus'] as String?)?.trim(),
    );
  }
}